# [Development Moved to iNav Repo](https://github.com/iNavFlight/LuaTelemetry)

# Taranis iNav Lua Script

Flight status screen for Taranis transmitter when running iNav

![sample](http://www.leethost.com/link_pics/iNav1.png "Showing launch-based orientation and location")
![sample](http://www.leethost.com/link_pics/iNav2.png "Showing compass-based direction")

## Requirements

* OpenTX v2.2.0 running on Taranis Q X7/X9D/X9D+/X9E
* A FrSky receiver that supports telemetry, such as X4R(SB), X8R, XSR
* [iNav v1.7.3+](https://github.com/iNavFlight/inav/releases) running on your flight controller
* GPS, altimeter, and compass sensors
* Optional amperage sensor needed for fuel and current displays

## Notes

* Designed to work on a Taranis Q X7 (should work on other Taranis transmitters but untested)
* Designed for a multirotor model, but should be valuable for fixed wing
* Uses Taranis settings for RSSI warning/critical levels for graph and warnings
* Uses Taranis settings for transmitter voltage min/max for battery graphic in screen title

## Setup

### In iNav Configurator

* Setup telemetry to send to your transmitter - [iNav telemetry docs](https://github.com/iNavFlight/inav/blob/master/docs/Telemetry.md)
* If you have an amperage sensor, configure `battery_capacity` and set `smartport_fuel_percent = ON` in CLI settings

### From Transmitter

* Discover telemetry sensors once GPS locked on model so all telemetry sensors are discovered
* Telemetry distance sensor name must be changed from `0420` to `Dist`
* Sensors must be changed to US measurements (m to ft, km/h to mph, etc)

### iNav Lua Script Setup

1. Copy `iNav.lua` file to Taranis SD card's `\SCRIPTS\TELEMETRY\` folder
2. Copy `iNav` folder to Taranis SD card's `\SCRIPTS\TELEMETRY\` folder
3. In model setup, page to `DISPLAY`, set desired screen to `Script`, and select `iNav`

## Usage

From the Taranis main screen, hold the `Page` button to show custom screens, then page to the screen you set to show iNav.
Flashing values are either because there's no telemetry or a warning.
To flip between max/min values and current values, use the dial or enter key.
To flip between compass-based direction and launch-based orientation and location, use the dial or enter key.
If model is further than 25 feet away, the launch direction view will show the direction of the model based upon launch position and orientation.
This can be used to locate a lost model, using the launch-based model location indicator and distance.
The launch-based orientation view is useful if model orientation is unknown.
The script gives audio feedback for flight modes, battery levels, and warnings (no need to manually set this up for each model).
Audio feedback will play in background even if iNav Lua Script screen is not displayed.

## Release History

### v1.0 - 09/19/2017
* Initial release

## Todo

* Automatically switch between metric and imperial (currently fixed to imperial)
* Possible option to display value of timer instead of automatic flight timer built into script
* Options for when sound files play
