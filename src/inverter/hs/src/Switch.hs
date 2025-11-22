module Switch
  ( SwitchState(..)
  , Pin
  , defaultPins
  , initSwitch
  , initSwitches
  , closeSwitch
  , openSwitch
  , setSwitch
  , cleanupSwitches
  , printSwitches
  ) where

import Control.Monad (forM, forM_)
import System.Directory (doesPathExist)
import System.IO

-- | GPIO pin number
type Pin = Int

-- | Switch state
data SwitchState = SwitchState
  { pin      :: Pin
  , isClosed :: Bool
  } deriving (Show, Eq)

-- | GPIO sysfs paths
gpioExport :: FilePath
gpioExport = "/sys/class/gpio/export"

gpioUnexport :: FilePath
gpioUnexport = "/sys/class/gpio/unexport"

gpioBase :: FilePath
gpioBase = "/sys/class/gpio"

-- | Default GPIO pins (P8_7 through P8_10 on BBB)
defaultPins :: [Pin]
defaultPins = [66, 67, 68, 69]

-- | Export a GPIO pin
exportPin :: Pin -> IO ()
exportPin p = do
  let path = gpioBase ++ "/gpio" ++ show p
  exists <- doesPathExist path
  if not exists
    then writeFile gpioExport (show p)
    else return ()

-- | Unexport a GPIO pin
unexportPin :: Pin -> IO ()
unexportPin p = do
  let path = gpioBase ++ "/gpio" ++ show p
  exists <- doesPathExist path
  if exists
    then writeFile gpioUnexport (show p)
    else return ()

-- | Set GPIO direction
setDirection :: Pin -> String -> IO ()
setDirection p dir = do
  let path = gpioBase ++ "/gpio" ++ show p ++ "/direction"
  writeFile path dir

-- | Set GPIO value
setValue :: Pin -> Int -> IO ()
setValue p val = do
  let path = gpioBase ++ "/gpio" ++ show p ++ "/value"
  writeFile path (show val)

-- | Initialize a single switch
initSwitch :: Pin -> IO SwitchState
initSwitch p = do
  exportPin p
  setDirection p "out"
  setValue p 0
  return $ SwitchState p False

-- | Initialize multiple switches
initSwitches :: [Pin] -> IO [SwitchState]
initSwitches = mapM initSwitch

-- | Close the switch (short the wires)
closeSwitch :: SwitchState -> IO SwitchState
closeSwitch s = do
  setValue (pin s) 1
  return $ s { isClosed = True }

-- | Open the switch (disconnect the wires)
openSwitch :: SwitchState -> IO SwitchState
openSwitch s = do
  setValue (pin s) 0
  return $ s { isClosed = False }

-- | Set switch state
setSwitch :: SwitchState -> Bool -> IO SwitchState
setSwitch s closed
  | closed    = closeSwitch s
  | otherwise = openSwitch s

-- | Cleanup all switches
cleanupSwitches :: [SwitchState] -> IO ()
cleanupSwitches switches = forM_ switches $ \s -> do
  setValue (pin s) 0
  unexportPin (pin s)

-- | Print switch states
printSwitches :: [SwitchState] -> IO ()
printSwitches switches = forM_ (zip [0..] switches) $ \(i, s) -> do
  let state = if isClosed s then "CLOSED" else "OPEN"
  putStrLn $ "Switch " ++ show i ++ " (GPIO " ++ show (pin s) ++ "): " ++ state
