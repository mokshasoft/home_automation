# LED Blinking on BeagleBone Black

## Read Logs
```
journalctl -u led-blink.service -f
```

## Starting service
```
sudo systemctl start led-blink.service
```

## Stopping Service
```
sudo systemctl stop led-blink.service
```

## Disabling Service
Disable the service so that it doesn't start on boot.
```
sudo systemctl disable led-blink.service
```
