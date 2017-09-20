# Taranis Q X7 iNav Lua Script

Flight status panel for Taranis Q X7 transmitter when running iNav

![sample](http://www.leethost.com/link_pics/iNav.png "iNav Lua Script")

## Requirements

* A FrSky receiver that supports telemetry, such as X4R(SB), X8R, XSR.
* [iNav v1.7.3+](https://github.com/iNavFlight/inav/releases) running on your flight controller.
* Designed to work on a TaranisQ X7. Should work on other Taranis transmitters, but it (currently) won't fill the entire display.

## Setup

### In iNav Configurator

* Setup telemetry to send to your transmitter - [iNav telemetry docs](https://github.com/iNavFlight/inav/blob/master/docs/Telemetry.md)
* Configure `battery_capacity` and set `smartport_fuel_percent = ON` in CLI settings

### From Transmitter

* Telemetry distance sensor name must be changed from `0420` to `Dist`
* Sensors must be changed to US measurements (m to ft, km/h to mph, etc)

## Release History

### v1.0 - 09/19/2017
* Initial release

## Todo

* Automatically switch between metric and imperial (currently fixed to imperial)
* Possible option to display value of timer 1 instead of automatic flight timer
* If model doesn't have a amperage meter don't show graph
* If `battery_capacity` or `smartport_fuel_percent = ON` not set, don't show fuel meter
