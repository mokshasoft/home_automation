module Main where

import Control.Concurrent (threadDelay)
import Control.Monad (forever)

import qualified Growatt

-- | Default port for single inverter testing
defaultPort :: String
defaultPort = "/dev/ttyUSB0"

-- | Polling interval in microseconds (5 seconds)
interval :: Int
interval = 5000000

main :: IO ()
main = do
  putStrLn "Starting inverter status monitor..."
  client <- Growatt.getClient defaultPort

  forever $ do
    maybeStatus <- Growatt.readInverter client
    case maybeStatus of
      Just status -> Growatt.printStatus status
      Nothing     -> putStrLn "Failed to read inverter"
    putStrLn ""
    threadDelay interval
