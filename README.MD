# Taranis iNav Lua Script

Flight status screen for Taranis transmitter when running iNav

![sample](http://www.leethost.com/link_pics/iNav1.png "Showing launch-based orientation and location")
![sample](http://www.leethost.com/link_pics/iNav2.png "Showing compass-based direction")

## Requirements

* OpenTX v2.2.0 running on Taranis Q X7/X9D/X9D+/X9E
* A FrSky receiver that supports telemetry, such as X4R(SB), X8R, XSR
* [iNav v1.7.3+](https://github.com/iNavFlight/inav/releases) running on your flight controller
* GPS, altimeter, and compass sensors
* Amperage sensor currently needed for fuel gauge (future version should make this optional)

## Notes

* Designed to work on a Taranis Q X7 (should work on other Taranis transmitters but untested)
* Designed for a multirotor copter

## Setup

### In iNav Configurator

* Setup telemetry to send to your transmitter - [iNav telemetry docs](https://github.com/iNavFlight/inav/blob/master/docs/Telemetry.md)
* Configure `battery_capacity` and set `smartport_fuel_percent = ON` in CLI settings

### From Transmitter

* Telemetry distance sensor name must be changed from `0420` to `Dist`
* Sensors must be changed to US measurements (m to ft, km/h to mph, etc)

### iNav Lua Script Setup

1. Copy `iNav.lua` file to Taranis SD card's `\SCRIPTS\TELEMETRY\` folder
2. Copy `iNav` folder to Taranis SD card's `\SCRIPTS\TELEMETRY\` folder
3. In model setup, page to the `DISPLAY`, set desired screen to `Script`, and select `iNav`

## Usage

From the Taranis main screen, hold the `Page` button to show custom screens, then page to the screen you set to show iNav.
Flashing values are either because there's no telemetry or a warning.
To flip between max/min values and current, use the dial or enter key.
To flip between model direction and orientation based on launch direction, use the dial or enter key.
If craft is 25 feet or further away, the launch direction view will show the direction of the model based upon launch position and orientation.
This can be used to locate a lost model, using the directional indicator and distance.
The orientation view is useful if model orientation is lost.
The script gives audio feedback for flight modes, battery levels, and warnings (no need to manually set this up for each model).
Audio feedback will play in background even if iNav Lua Script screen is not displayed.

## Release History

### v1.0 - 09/19/2017
* Initial release

## Todo

* Automatically switch between metric and imperial (currently fixed to imperial)
* Possible option to display value of timer 1 instead of automatic flight timer
* If model doesn't have a amperage sensor don't show graph
* If `battery_capacity` or `smartport_fuel_percent = ON` not set, don't show fuel meter
* Options for when sound files play
