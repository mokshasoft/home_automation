module Controller
  ( -- * Types
    ControllerState(..)
  , SolarWindow(..)
  , PendingVerification(..)
  , Action(..)
  , Config(..)
    -- * Pure functions
  , defaultConfig
  , initialState
  , decideActions
  , applyAction
  , getInterval
    -- * IO functions
  , runController
  ) where

import Data.Time.Clock
import Data.Time.LocalTime
import Data.Time.Calendar
import Data.Maybe (catMaybes, isJust)
import Control.Concurrent (threadDelay)
import Control.Monad (forM_)

import qualified Growatt
import qualified Switch

-- | Configuration constants
data Config = Config
  { thresholdHigh       :: Int     -- ^ Enable when battery >= this
  , thresholdLow        :: Int     -- ^ Disable when battery < this
  , maxOutputWatts      :: Double  -- ^ Max watts per inverter
  , loadHeadroom        :: Double  -- ^ Headroom needed to enable switch
  , pvOnThreshold       :: Double  -- ^ Watts to consider PV as "on"
  , intervalEngaged     :: Int     -- ^ Microseconds when switches enabled
  , intervalIdle        :: Int     -- ^ Microseconds during solar window
  , intervalSleep       :: Int     -- ^ Microseconds at night
  , windowBufferMinutes :: Int     -- ^ Start polling X minutes before sunrise
  , pvIncreaseTolerance :: Double  -- ^ Tolerance for PV verification
  } deriving (Show, Eq)

-- | Default configuration
defaultConfig :: Config
defaultConfig = Config
  { thresholdHigh       = 95
  , thresholdLow        = 90
  , maxOutputWatts      = 5000
  , loadHeadroom        = 2000
  , pvOnThreshold       = 10
  , intervalEngaged     = 1000000    -- 1 second
  , intervalIdle        = 60000000   -- 60 seconds
  , intervalSleep       = 300000000  -- 300 seconds
  , windowBufferMinutes = 30
  , pvIncreaseTolerance = 500
  }

-- | Solar window times
data SolarWindow = SolarWindow
  { startTime :: Maybe TimeOfDay
  , endTime   :: Maybe TimeOfDay
  } deriving (Show, Eq)

-- | Pending verification state
data PendingVerification = PendingVerification
  { verifyIndex :: Int
  , pvBefore    :: Double
  } deriving (Show, Eq)

-- | Controller state
data ControllerState = ControllerState
  { switchesEnabled :: [Bool]
  , todayWindow     :: SolarWindow
  , yesterdayWindow :: SolarWindow
  , pvWasOn         :: Bool
  , lastDate        :: Day
  , pending         :: Maybe PendingVerification
  } deriving (Show, Eq)

-- | Actions that can be performed
data Action
  = EnableSwitch Int Double    -- ^ Enable switch i, record PV watts
  | DisableSwitch Int          -- ^ Disable switch i
  | VerifySuccess Int Double   -- ^ Verification passed
  | VerifyFailed Int Double    -- ^ Verification failed
  | UpdateSolarWindow SolarWindow Bool
  | DayRollover SolarWindow    -- ^ New day with new yesterday window
  | NoAction
  deriving (Show, Eq)

-- | Initial state
initialState :: Int -> IO ControllerState
initialState numSwitches = do
  today <- utctDay <$> getCurrentTime
  return $ ControllerState
    { switchesEnabled = replicate numSwitches False
    , todayWindow     = SolarWindow Nothing Nothing
    , yesterdayWindow = SolarWindow Nothing Nothing
    , pvWasOn         = False
    , lastDate        = today
    , pending         = Nothing
    }

-- | Add minutes to TimeOfDay
addMinutesToTime :: TimeOfDay -> Int -> TimeOfDay
addMinutesToTime t mins =
  let secs = timeOfDayToTime t + fromIntegral (mins * 60)
  in timeToTimeOfDay (secs `mod` 86400)

-- | Check if outside solar window
outsideSolarWindow :: Config -> SolarWindow -> TimeOfDay -> Bool
outsideSolarWindow _ (SolarWindow _ Nothing) _ = False
outsideSolarWindow _ (SolarWindow _ (Just end)) now = now > end

-- | Check if within active polling window
withinActiveWindow :: Config -> SolarWindow -> TimeOfDay -> Bool
withinActiveWindow cfg (SolarWindow Nothing _) _ = True
withinActiveWindow cfg (SolarWindow _ Nothing) _ = True
withinActiveWindow cfg (SolarWindow (Just start) (Just end)) now =
  let bufferedStart = addMinutesToTime start (-(windowBufferMinutes cfg))
      bufferedEnd   = addMinutesToTime end (windowBufferMinutes cfg)
  in now >= bufferedStart && now <= bufferedEnd

-- | Check if phase can be enabled (capacity check)
canEnablePhase :: Config -> Growatt.InverterStatus -> Bool
canEnablePhase cfg status =
  Growatt.outputWatts status + loadHeadroom cfg <= maxOutputWatts cfg

-- | Check if phase should be enabled
shouldEnablePhase :: Config -> Growatt.InverterStatus -> Bool -> SolarWindow -> TimeOfDay -> Bool
shouldEnablePhase cfg status currentlyEnabled window now
  | outsideSolarWindow cfg window now = False
  | Growatt.batteryPercentage status >= thresholdHigh cfg = canEnablePhase cfg status
  | Growatt.batteryPercentage status < thresholdLow cfg = False
  | currentlyEnabled && not (canEnablePhase cfg status) = False
  | otherwise = currentlyEnabled

-- | Verify PV increase
verifyPvIncrease :: Config -> Double -> Double -> Bool
verifyPvIncrease cfg before after =
  let increase = after - before
      expected = loadHeadroom cfg - pvIncreaseTolerance cfg
  in increase >= expected

-- | Update solar window based on PV state
updateSolarWindow :: Config -> SolarWindow -> Double -> Bool -> TimeOfDay -> (SolarWindow, Bool)
updateSolarWindow cfg window pvWatts wasOn now =
  let isOn = pvWatts > pvOnThreshold cfg
  in case (isOn, wasOn) of
       (True, False)  -> (window { startTime = Just now }, isOn)
       (False, True)  -> (window { endTime = Just now }, isOn)
       _              -> (window, isOn)

-- | Decide all actions based on current state and readings
decideActions :: Config -> ControllerState -> [Growatt.InverterStatus] -> TimeOfDay -> Day -> [Action]
decideActions cfg state statuses now today =
  let totalPv = sum $ map Growatt.pvWatts statuses
      enabled = switchesEnabled state
      window  = yesterdayWindow state

      -- Day rollover
      rolloverAction = if today /= lastDate state
        then [DayRollover (todayWindow state)]
        else []

      -- Solar window update
      (newWindow, newPvOn) = updateSolarWindow cfg (todayWindow state) totalPv (pvWasOn state) now
      windowAction = [UpdateSolarWindow newWindow newPvOn]

      -- Verification
      verifyActions = case pending state of
        Nothing -> []
        Just pv ->
          if verifyPvIncrease cfg (pvBefore pv) totalPv
            then [VerifySuccess (verifyIndex pv) totalPv]
            else [VerifyFailed (verifyIndex pv) totalPv]

      -- Find switches to disable
      disableActions =
        [ DisableSwitch i
        | (i, (status, en)) <- zip [0..] (zip statuses enabled)
        , en
        , not (shouldEnablePhase cfg status True window now)
        ]

      -- Find next switch to enable (only if no pending verification)
      enableAction = case pending state of
        Just _ -> []
        Nothing ->
          case [ i
               | (i, (status, en)) <- zip [0..] (zip statuses enabled)
               , not en
               , shouldEnablePhase cfg status False window now
               ] of
            (i:_) -> [EnableSwitch i totalPv]
            []    -> []

  in rolloverAction ++ windowAction ++ verifyActions ++ disableActions ++ enableAction

-- | Apply action to state (pure)
applyAction :: Action -> ControllerState -> ControllerState
applyAction action state = case action of
  EnableSwitch i pv ->
    state { switchesEnabled = setAt i True (switchesEnabled state)
          , pending = Just (PendingVerification i pv)
          }

  DisableSwitch i ->
    state { switchesEnabled = setAt i False (switchesEnabled state) }

  VerifySuccess _ _ ->
    state { pending = Nothing }

  VerifyFailed i _ ->
    state { switchesEnabled = setAt i False (switchesEnabled state)
          , pending = Nothing
          }

  UpdateSolarWindow window pvOn ->
    state { todayWindow = window, pvWasOn = pvOn }

  DayRollover newYesterday ->
    state { yesterdayWindow = newYesterday
          , todayWindow = SolarWindow Nothing Nothing
          , lastDate = lastDate state  -- Will be updated by caller
          }

  NoAction -> state

-- | Helper to set element at index
setAt :: Int -> a -> [a] -> [a]
setAt i x xs = take i xs ++ [x] ++ drop (i + 1) xs

-- | Get polling interval based on state
getInterval :: Config -> ControllerState -> TimeOfDay -> Int
getInterval cfg state now
  | any id (switchesEnabled state)             = intervalEngaged cfg
  | withinActiveWindow cfg (yesterdayWindow state) now = intervalIdle cfg
  | otherwise                                  = intervalSleep cfg

-- | Perform IO for an action
performAction :: Action -> [Switch.SwitchState] -> IO [Switch.SwitchState]
performAction action switches = case action of
  EnableSwitch i pv -> do
    putStrLn $ "Engaging phase " ++ show i ++ " for verification (PV: " ++ show pv ++ "W)"
    newSwitch <- Switch.setSwitch (switches !! i) True
    return $ setAt i newSwitch switches

  DisableSwitch i -> do
    putStrLn $ "Disabling phase " ++ show i
    newSwitch <- Switch.setSwitch (switches !! i) False
    return $ setAt i newSwitch switches

  VerifySuccess i pv ->
    putStrLn ("Phase " ++ show i ++ " verified (PV: " ++ show pv ++ "W)") >> return switches

  VerifyFailed i pv -> do
    putStrLn $ "Phase " ++ show i ++ " failed verification (PV: " ++ show pv ++ "W), disabling"
    newSwitch <- Switch.setSwitch (switches !! i) False
    return $ setAt i newSwitch switches

  DayRollover window ->
    putStrLn ("New day - yesterday's window: " ++ show window) >> return switches

  _ -> return switches

-- | Print controller status
printStatus :: [Growatt.InverterStatus] -> [Bool] -> IO ()
printStatus statuses enabled = do
  putStrLn "--- Controller Status ---"
  case statuses of
    (s:_) -> putStrLn $ "Battery: " ++ show (Growatt.batteryPercentage s) ++ "%"
    []    -> return ()
  forM_ (zip3 [0..] statuses enabled) $ \(i, status, en) -> do
    let state = if en then "ON" else "OFF"
    putStrLn $ "Phase " ++ show i ++ ": " ++ show (Growatt.outputWatts status) ++ "W [" ++ state ++ "]"
  putStrLn ""

-- | Main controller loop
runController :: Config -> [Growatt.Client] -> [Switch.SwitchState] -> IO ()
runController cfg clients switches = do
  state <- initialState (length switches)
  loop state switches
  where
    loop state switches = do
      -- Read all inverters
      maybeStatuses <- mapM Growatt.readInverter clients
      let statuses = catMaybes maybeStatuses

      if length statuses == length switches
        then do
          -- Get current time
          now <- localTimeOfDay . zonedTimeToLocalTime <$> getZonedTime
          today <- utctDay <$> getCurrentTime

          -- Decide actions (pure)
          let actions = decideActions cfg state statuses now today

          -- Apply actions to state (pure)
          let newState = foldl (flip applyAction) state actions
          let newState' = newState { lastDate = today }

          -- Perform IO for actions
          newSwitches <- foldM (flip performAction) switches actions

          -- Print status
          printStatus statuses (switchesEnabled newState')

          -- Sleep and loop
          let interval = getInterval cfg newState' now
          threadDelay interval
          loop newState' newSwitches
        else do
          putStrLn $ "Warning: got " ++ show (length statuses) ++
                     " statuses for " ++ show (length switches) ++ " switches"
          threadDelay (intervalIdle cfg)
          loop state switches

    foldM f z []     = return z
    foldM f z (x:xs) = f x z >>= \z' -> foldM f z' xs
