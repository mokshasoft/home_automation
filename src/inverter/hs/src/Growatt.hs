{-# LANGUAGE ScopedTypeVariables #-}

module Growatt (
    InverterStatus (..),
    Client,
    getClient,
    readInverter,
    printStatus,
) where

import Control.Exception (try)
import qualified Data.Vector.Storable as V
import Data.Word (Word16)
import GHC.IO.Exception (IOError)
import System.Modbus

-- | Inverter status readings
data InverterStatus = InverterStatus
    { pvVoltage :: Double
    , pvWatts :: Double
    , batteryVoltage :: Double
    , batteryPercentage :: Int
    , outputWatts :: Double
    , utilityWatts :: Double
    }
    deriving (Show, Eq)

-- | Modbus client handle
type Client = Context

-- | Get a Modbus client for the specified port
getClient :: String -> IO Client
getClient port = do
    ctx <- new_rtu port (Baud 9600) ParityNone (DataBits 8) (StopBits 1)
    set_slave ctx (DeviceAddress 0)
    connect ctx
    return ctx

-- | Read double register (high/low word)
readDouble :: [Word16] -> Int -> Double -> Double
readDouble regs idx scale =
    let high = fromIntegral (regs !! idx)
        low = fromIntegral (regs !! (idx + 1))
     in ((high * 65536) + low) * scale

-- | Read single register
readSingle :: [Word16] -> Int -> Double -> Double
readSingle regs idx scale = fromIntegral (regs !! idx) * scale

-- | Read inverter status from client
readInverter :: Client -> IO (Maybe InverterStatus)
readInverter client = do
    result <- try $ do
        buffer <- mkRegisterVector 125
        vec <- read_input_registers client (Addr 0) buffer :: IO (V.Vector Word16)
        return $ V.toList vec
    case result of
        Left (err :: IOError) -> do
            putStrLn $ "Modbus error: " ++ show err
            return Nothing
        Right regs ->
            return $
                Just
                    InverterStatus
                        { pvVoltage = readSingle regs 1 0.1
                        , pvWatts = readDouble regs 3 0.1 -- ?
                        , batteryVoltage = readSingle regs 17 0.01
                        , batteryPercentage = fromIntegral (regs !! 18)
                        , outputWatts = readSingle regs 70 0.1
                        , utilityWatts = readDouble regs 21 0.1 -- ?
                        }

-- | Print inverter status
printStatus :: InverterStatus -> IO ()
printStatus s = do
    putStrLn $ "PV voltage     : " ++ show (pvVoltage s) ++ " V"
    putStrLn $ "PV watts       : " ++ show (pvWatts s) ++ " W"
    putStrLn $ "Battery voltage: " ++ show (batteryVoltage s) ++ " V"
    putStrLn $ "Battery percent: " ++ show (batteryPercentage s) ++ "%"
    putStrLn $ "Output watts   : " ++ show (outputWatts s) ++ " W"
    putStrLn $ "Utility watts  : " ++ show (utilityWatts s) ++ " W"
