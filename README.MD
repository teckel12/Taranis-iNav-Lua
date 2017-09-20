# Taranis iNav Lua Script

Flight status screen for Taranis transmitter when running iNav

![sample](http://www.leethost.com/link_pics/iNav.png "iNav Lua Script")

## Requirements

* OpenTX v2.2.0 running on Taranis Q X7/X9D/X9D+/X9E
* A FrSky receiver that supports telemetry, such as X4R(SB), X8R, XSR
* [iNav v1.7.3+](https://github.com/iNavFlight/inav/releases) running on your flight controller
* Designed to work on a Taranis Q X7. Should work on other Taranis transmitters, but untested

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
3. In model setup, page to the `DISPLAY` page, set desired screen to `Script`, and select `iNav`

## Release History

### v1.0 - 09/19/2017
* Initial release

## Todo

* Automatically switch between metric and imperial (currently fixed to imperial)
* Possible option to display value of timer 1 instead of automatic flight timer
* If model doesn't have a amperage meter don't show graph
* If `battery_capacity` or `smartport_fuel_percent = ON` not set, don't show fuel meter
