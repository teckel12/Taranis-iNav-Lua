-- Taranis Q X7 iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!

--0 or not specified normal font
--XXLSIZE jumbo sized font
--DBLSIZE double size font
--MIDSIZE mid sized font
--SMLSIZE small font
--INVERS inverted display
--BLINK blinking text
--LCD_W = 128 Q X7 / 212 X9D
--LCD_H = 64

local flightMode = ""
local modePrev = ""
local armedPrev = false
local headingRef = 0
local noTelemWarn = false

local function init()
  -- init is called once when model is loaded
  modelName = model.getInfo()["name"]

  if (getValue("Tmp1") <= 0) then
    noTelemWarn = true
  end
end

local function background()
  -- background is called periodically when screen is not visible
end

local function displayLat(coord)
  local ext = "N"
  if (coord > 1) then
    ext = "S"
  end
  return string.format("%10.4f", math.abs(coord)) .. ext
end

local function displayLon(coord)
  local ext = "W"
  if (coord > 1) then
    ext = "E"
  end
  return string.format("%10.4f", math.abs(coord)) .. ext
end

local function run(event)
  lcd.clear()

  -- *** Title ***
  lcd.drawFilledRectangle(0, 0, LCD_W, 8)
  lcd.drawText(0 , 0, modelName, INVERS)
  lcd.drawNumber(84, 0, getValue("tx-voltage") * 10, PREC1 + INVERS)
  lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)
  rxBatt = getValue("RxBt")
  if (rxBatt) then
    lcd.drawNumber(111, 0, rxBatt * 10, PREC1 + INVERS)
    lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)
  end

  -- *** Initial warning if there's no telemetry ***
  mode = getValue("Tmp1")
  if (noTelemWarn and mode <= 0) then
    result = popupWarning("No Telemetry!", event)
    if (result == "CANCEL") then
      noTelemWarn = false
    end
  else
    noTelemWarn = false

    -- *** Satellites ***
    sats = tonumber(string.sub(getValue("Tmp2"), -2))
    lcd.drawText(93, 9, "Sats " .. string.format("%2d", sats), SMLSIZE)

    -- *** GPS Coords ***
    gpsLatLon = getValue("GPS")
    if (type(gpsLatLon) == "table") then
      lcd.drawText(96, 17, string.format("%5d", getValue("GAlt")) .. "ft", SMLSIZE)
      lcd.drawText(82, 25, displayLat(gpsLatLon["lat"]), SMLSIZE)
      lcd.drawText(82, 33, displayLon(gpsLatLon["lon"]), SMLSIZE)
    else
      lcd.drawFilledRectangle(88, 17, 40, 23, INVERS)
      lcd.drawText(92, 20, "No GPS", INVERS)
      lcd.drawText(101, 30, "Fix", INVERS)
    end

    -- *** Decode flight mode ***
    holdMode = ""
    headFree = false
    headingHold = false
    altHold = false
    showHold = true
    extra = 0
    armed = false
    ok2arm = false
    posHold = false
    if (mode > 0) then
      modeA = math.floor(mode / 10000)
      mode = mode - (modeA * 10000)
      modeB = math.floor(mode / 1000)
      mode = mode - (modeB * 1000)
      modeC = math.floor(mode / 100)
      mode = mode - (modeC * 100)
      modeD = math.floor(mode / 10)
      modeE = mode - (modeD * 10)
      if (modeE >= 4) then
        armed = true
        modeE = modeE - 4
        extra = 0
        if (modeD >= 4) then
          modeD = modeD - 4
        end
        if (modeD == 2) then
          flightMode = "HORIZON"
        elseif (modeD == 1) then
          flightMode = "ANGLE"
        else
          flightMode = "ACRO"
        end
      else
        armed = false
      end
      if (modeE >= 2 or modeE == 0) then
        flightMode = "NOT OK"
        extra = BLINK + INVERS
        showHold = false
      else
        ok2arm = true
        extra = 0
        showHold = true
        if (armed == false) then
          flightMode = "READY"
          showHold = false
        end
      end
      if (modeB >= 4) then
        modeB = modeB - 4
        headFree = true
      end
      if (modeC >= 4) then
        modeC = modeC - 4
        if (armed == true) then
          flightMode = "POS HOLD"
          posHold = true
        end
      end
      if (modeC >= 2) then
        modeC = modeC - 2
        altHold = true
        if (posHold) then
          flightMode = "3D HOLD"
        end
      end
      if (modeC == 1) then
        headingHold = true
      end  
      if (modeB >= 2) then
        modeB = modeB - 2
        flightMode = "WAYPOINT"
        extra = BLINK + INVERS
        showHold = false
      end
      if (modeB == 1) then
        flightMode = "RTH"
        extra = BLINK + INVERS
        showHold = false
      end
      if (modeA >= 4) then
        flightMode = "FAILSAFE"
        extra = BLINK + INVERS
        showHold = false
      end
    else
      flightMode = "NO TELEM"
      extra = BLINK + INVERS
      showHold = false
    end
    if (modePrev ~= flightMode and modePrev ~= "") then
      playTone(1000, 50, 0, PLAY_NOW)
    end
    modePrev = flightMode

    -- *** Directional indicator ***
    if (mode > 0) then
      if (armed) then
        if (armedPrev == false) then
          headingRef = getValue("Hdg")
        end
        heading = getValue("Hdg") - headingRef
        size = 10
        width = 145
        center = 19
      else
        heading = getValue("Hdg")
        lcd.drawText(65, 8, "N", SMLSIZE)
        --lcd.drawText(65, 26, "S", SMLSIZE)
        lcd.drawFilledRectangle(66, 29, 3, 3, SOLID)
        lcd.drawText(77, 17, "E", SMLSIZE)
        lcd.drawText(53, 17, "W", SMLSIZE)
        size = 6
        width = 135
        center = 21
      end
      armedPrev = armed
      local rad1 = math.rad(heading)
      local rad2 = math.rad(heading + width)
      local rad3 = math.rad(heading - width)
      local x1 = math.floor(math.sin(rad1) * size + 0.5) + 67
      local y1 = center - math.floor(math.cos(rad1) * size + 0.5)
      local x2 = math.floor(math.sin(rad2) * size + 0.5) + 67
      local y2 = center - math.floor(math.cos(rad2) * size + 0.5)
      local x3 = math.floor(math.sin(rad3) * size + 0.5) + 67
      local y3 = center - math.floor(math.cos(rad3) * size + 0.5)
      lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
      lcd.drawLine(x1, y1, x3, y3, SOLID, FORCE)
      if (headingHold and armed) then
        lcd.drawFilledRectangle((x2 + x3) / 2 - 2, (y2 + y3) / 2 - 2, 5, 5, SOLID)
      else
        lcd.drawLine(x2, y2, x3, y3, DOTTED, FORCE)
      end
    end

    -- *** Head free warning ***
    if (headFree) then
      lcd.drawText(48, 9, "HEADFREE", SMLSIZE + INVERS + BLINK)
    end

    -- *** Display flight mode (centered) ***
    lcd.drawText(47, 34, flightMode, SMLSIZE + extra)
    pos = 47 + (87 - lcd.getLastPos()) / 2
    lcd.drawFilledRectangle(46, 33, 40, 10, ERASE)
    lcd.drawText(pos, 33, flightMode, SMLSIZE + extra)

    -- *** Data ***
    if (armed) then
      altitude = getValue("Alt")
      distance = getValue("Dist")
      speed = getValue("GSpd")
      current = getValue("Curr")
      tags = SMLSIZE
    else
      altitude = getValue("Alt+")
      distance = getValue("Dist+")
      speed = getValue("GSpd+")
      current = getValue("Curr+")
      lcd.drawFilledRectangle(0, 8, 20, 32, INVERS)
      tags = SMLSIZE + INVERS
    end
    if (altHold and showHold) then
      lcd.drawText(0, 9, "Altd ", SMLSIZE + INVERS)
    else
      lcd.drawText(0, 9, "Altd", tags)
    end
    lcd.drawText(0, 17, "Dist", tags)
    lcd.drawText(0, 25, "Sped", tags)
    lcd.drawText(0, 33, "Curr", tags)
    altitudeTags = SMLSIZE
    if (altHold and showHold) then
      altitudeTags = SMLSIZE + INVERS
    end
    lcd.drawText(22, 9, math.floor(altitude), altitudeTags)
    if (altitude < 1000) then
      lcd.drawText(lcd.getLastPos(), 9, "ft", altitudeTags)
    end
    lcd.drawText(22, 17, math.floor(distance * 3.28084), SMLSIZE)
    if (distance < 1000) then
      lcd.drawText(lcd.getLastPos(), 17, "ft", SMLSIZE)
    end
    lcd.drawText(22, 25, math.floor(speed), SMLSIZE)
    if (speed < 100) then
      lcd.drawText(lcd.getLastPos(), 25, "mph", SMLSIZE)
    end
    lcd.drawNumber(22, 33, current * 10, SMLSIZE + PREC1)
    if (current < 100) then
      lcd.drawText(lcd.getLastPos(), 33, "A", SMLSIZE)
    end

    -- *** Bar graphs ***
    batt = getValue("VFAS")
    cell = getValue("A4")
    if (cell == 0 or cell == 3) then
      cells = math.floor(batt / 4.3) + 1
      cell = batt / cells
    end
    lcd.drawText(0, 42, "Batt", SMLSIZE)
    lcd.drawNumber(22, 42, batt * 10, SMLSIZE + PREC1)
    lcd.drawText(lcd.getLastPos(), 42, "V", SMLSIZE)
    lcd.drawGauge(46, 41, 82, 7, math.min(math.max(cell - 3.3, 0) * 111.1, 98), 100)

    fuel = getValue("Fuel")
    lcd.drawText(0, 50, "Fuel", SMLSIZE)
    lcd.drawText(22, 50, fuel .. "%", SMLSIZE)
    lcd.drawGauge(46, 49, 82, 7, math.min(fuel, 98), 100)

    rssi = getValue("RSSI")
    lcd.drawText(0, 58, "RSSI", SMLSIZE)
    lcd.drawText(22, 58, rssi .. "dB", SMLSIZE)
    lcd.drawGauge(46, 57, 82, 7, math.min(rssi, 98), 100)
    min = 79 * (math.min(getValue("RSSI-"), 98) / 98) + 47
    lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

    -- *** Altitude bar graph (maybe use for larger screens?) ***
    --lcd.drawRectangle(124, 9, 4, 55, SOLID)
    --height = math.max(math.min(math.ceil(getValue("Alt") / 400 * 53), 53), 1)
    --lcd.drawRectangle(125, 63 - height, 2, height, SOLID)
  
  end

  return 1
end

return {init=init, run=run, background=background}