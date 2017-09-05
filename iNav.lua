-- Taranis Q X7 iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!

local flightMode = ""
local armedPrev = false
local headingRef = 0

local function init()
  -- init is called once when model is loaded
  modelName = model.getInfo()["name"]
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

--0 or not specified normal font
--XXLSIZE jumbo sized font
--DBLSIZE double size font
--MIDSIZE mid sized font
--SMLSIZE small font
--INVERS inverted display
--BLINK blinking text

local function run(event)
  lcd.clear()

  -- *** Title ***
  lcd.drawFilledRectangle(0, 0, LCD_W, 8)
  lcd.drawText(0 , 0, modelName, INVERS)
  lcd.drawNumber(84, 0, getValue("tx-voltage") * 10, PREC1 + INVERS)
  lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)
  lcd.drawNumber(111, 0, getValue("RxBt") * 10, PREC1 + INVERS)
  lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)

  -- *** Satellites ***
  sats = tonumber(string.sub(getValue("Tmp2"), -2))
  lcd.drawText(90, 9, "Sats " .. sats, SMLSIZE)

  -- *** GPS Coords ***
  gpsLatLon = getValue("GPS")
  if (type(gpsLatLon) == "table") then
    lcd.drawText(91, 17, string.format("%5d", getValue("GAlt")) .. "ft", SMLSIZE)
    lcd.drawText(77, 25, displayLat(gpsLatLon["lat"]), SMLSIZE)
    lcd.drawText(77, 33, displayLon(gpsLatLon["lon"]), SMLSIZE)
  else
    lcd.drawFilledRectangle(83, 17, 40, 23, INVERS)
    lcd.drawText(88, 20, "No GPS", INVERS)
    lcd.drawText(96, 30, "Fix", INVERS)
  end

  -- *** Decode flight mode ***
  mode = getValue("Tmp1")
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
        flightMode = "HORI"
      elseif (modeD == 1) then
        flightMode = "ANGL"
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
        flightMode = "POS"
        posHold = true
      end
    end
    if (modeC >= 2) then
      modeC = modeC - 2
      altHold = true
      if (posHold) then
        flightMode = "3DHOLD"
      end
    end
    if (modeC == 1) then
      headingHold = true
    end  
    if (modeB >= 2) then
      modeB = modeB - 2
      flightMode = "WP"
      extra = BLINK + INVERS
      showHold = false
    end
    if (modeB == 1) then
      flightMode = "RTH"
      extra = BLINK + INVERS
      showHold = false
    end
    if (modeA >= 4) then
      flightMode = "FAIL"
      extra = BLINK + INVERS
      showHold = false
    end
  else
    flightMode = "NO TELEM"
    extra = BLINK + INVERS
    showHold = false
  end

  -- *** Direction ***
  if (armed) then
    if (armedPrev == false) then
      headingRef = getValue("Hdg")
    end
    --lcd.drawRectangle(55, 8, 24, 24)
    local heading = getValue("Hdg") - headingRef
    local rad1 = math.rad(heading)
    local rad2 = math.rad(heading + 155)
    local rad3 = math.rad(heading - 155)
    local x1 = math.sin(rad1) * 11 + 67
    local y1 = 20 - (math.cos(rad1) * 11)
    local x2 = math.ceil(math.sin(rad2) * 11) + 67
    local y2 = 20 - math.ceil(math.cos(rad2) * 11)
    local x3 = math.sin(rad3) * 11 + 67
    local y3 = 20 - (math.cos(rad3) * 11)
    lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
    lcd.drawLine(x1, y1, x3, y3, SOLID, FORCE)
    if (headingHold) then
      lcd.drawFilledRectangle((x2 + x3) / 2 - 2, (y2 + y3) / 2 - 2, 5, 5, SOLID)
    else
      lcd.drawLine(x2, y2, x3, y3, DOTTED, FORCE)
    end
  else
    lcd.drawChannel(52, 17, "Hdg", SMLSIZE)
  end
  if (headFree) then
    lcd.drawText(48, 9, "HEADFREE", SMLSIZE + INVERS + BLINK)
  end
  armedPrev = armed

  -- *** Display flight mode (centered) ***
  displayMode = flightMode
  lcd.drawText(47, 33, displayMode, SMLSIZE + extra)
  pos = 47 + (87 - lcd.getLastPos()) / 2
  lcd.drawFilledRectangle(46, 32, 40, 10, ERASE)
  lcd.drawText(pos, 33, displayMode, SMLSIZE + extra)

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
  lcd.drawNumber(22, 33, current, SMLSIZE + PREC1)
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
  lcd.drawNumber(22, 42, batt, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(), 42, "V", SMLSIZE)
  lcd.drawGauge(46, 41, 77, 7, math.min(math.max(cell - 3.3, 0) * 111.1, 98), 100)

  fuel = getValue("Fuel")
  lcd.drawText(0, 50, "Fuel", SMLSIZE)
  lcd.drawText(22, 50, fuel .. "%", SMLSIZE)
  lcd.drawGauge(46, 49, 77, 7, math.min(fuel, 98), 100)

  rssi = getValue("RSSI")
  lcd.drawText(0, 58, "RSSI", SMLSIZE)
  lcd.drawText(22, 58, rssi .. "dB", SMLSIZE)
  lcd.drawGauge(46, 57, 77, 7, math.min(rssi, 98), 100)
  min = 74 * (math.min(getValue("RSSI-"), 98) / 98) + 47
  lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

  -- Altitude
  lcd.drawRectangle(124, 9, 4, 55, SOLID)
  height = math.max(math.min(math.ceil(getValue("Alt") / 400 * 53), 53), 1)
  lcd.drawRectangle(125, 63 - height, 2, height, SOLID)
  return 1
end

return {init=init, run=run, background=background}