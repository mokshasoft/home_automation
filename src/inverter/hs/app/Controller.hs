module Main where

import Control.Exception (bracket)

import qualified Growatt
import qualified Switch
import qualified Controller

-- | Default ports for the three inverters
defaultPorts :: [String]
defaultPorts = ["/dev/ttyUSB0", "/dev/ttyUSB1", "/dev/ttyUSB2"]

main :: IO ()
main = do
  putStrLn "Starting inverter controller..."

  -- Initialize clients
  clients <- mapM Growatt.getClient defaultPorts

  -- Initialize switches with cleanup on exit
  bracket
    (Switch.initSwitches Switch.defaultPins)
    Switch.cleanupSwitches
    (Controller.runController Controller.defaultConfig clients)
