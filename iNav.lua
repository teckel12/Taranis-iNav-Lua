-- Taranis Q X7 iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!

local flightMode = ""
local holdMode = ""

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
  lcd.drawText(95, 9, "Sats " .. sats, SMLSIZE)

  -- *** GPS Coords ***
  gpsLatLon = getValue("GPS")
  if (type(gpsLatLon) == "table") then
    --lcd.drawChannel(95, 17, "GAlt", SMLSIZE)
    lcd.drawText(96, 17, string.format("%5d", getValue("GAlt")) .. "ft", SMLSIZE)
    lcd.drawText(82, 25, displayLat(gpsLatLon["lat"]), SMLSIZE)
    lcd.drawText(82, 33, displayLon(gpsLatLon["lon"]), SMLSIZE)
  else
    lcd.drawFilledRectangle(88, 17, 40, 23, INVERS)
    lcd.drawText(93, 20, "No GPS", INVERS)
    lcd.drawText(101, 30, "Fix", INVERS)
  end

  -- *** Decode flight mode ***
  mode = getValue("Tmp1")
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
      holdMode = "HF"
      extra = BLINK + INVERS
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
      if (posHold) then
        holdMode = "3D"
      else
        holdMode = "AH"
      end
    end
    if (modeC == 1) then
      holdMode = holdMode .. "HH"
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
    lcd.drawRectangle(46, 8, 42, 25, INVERS)
  else
    lcd.drawChannel(50, 17, "Hdg", SMLSIZE)
  end

  -- *** Display flight mode ***
  displayMode = flightMode
  if (showHold and holdMode ~= "") then
    displayMode = flightMode .. " " .. holdMode
  end
  pos = 48
  if (string.len(displayMode) < 4) then
    pos = 67
  elseif (string.len(displayMode) < 5) then
    pos = 62
  elseif (string.len(displayMode) < 6) then
    pos = 57
  elseif (string.len(displayMode) < 7) then
    pos = 52
  end
  lcd.drawText(pos, 33, displayMode, SMLSIZE + extra)

  -- *** Data ***
  lcd.drawText(0, 9, "Altd", SMLSIZE)
  lcd.drawText(0, 17, "Dist", SMLSIZE)
  lcd.drawText(0, 25, "Sped", SMLSIZE)
  lcd.drawText(0, 33, "Curr", SMLSIZE)
  if (armed == true) then
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
    tags = SMLSIZE + INVERS
    lcd.drawFilledRectangle(20, 8, 26, 32, INVERS)
  end
  lcd.drawText(21, 9, math.floor(altitude), tags)
  if (altitude < 1000) then
    lcd.drawText(lcd.getLastPos(), 9, "ft", tags)
  end
  lcd.drawText(21, 17, math.floor(distance * 3.28084), tags)
  if (distance < 1000) then
    lcd.drawText(lcd.getLastPos(), 17, "ft", tags)
  end
  lcd.drawText(21, 25, math.floor(speed), tags)
  if (speed < 100) then
    lcd.drawText(lcd.getLastPos(), 25, "mph", tags)
  end
  lcd.drawNumber(21, 33, current, tags + PREC1)
  if (current < 100) then
    lcd.drawText(lcd.getLastPos(), 33, "A", tags)
  end

  -- *** Bar graphs ***
  batt = getValue("VFAS")
  cell = getValue("A4")
  if (cell == 0 or cell == 3) then
    cells = math.floor(batt / 4.3) + 1
    cell = batt / cells
  end
  lcd.drawText(0, 42, "Batt", SMLSIZE)
  lcd.drawNumber(21, 42, batt, SMLSIZE + PREC1)
  lcd.drawText(lcd.getLastPos(), 42, "V", SMLSIZE)
  lcd.drawGauge(46, 41, 82, 7, math.min(math.max(cell - 3.3, 0) * 111.1, 98), 100)

  fuel = getValue("Fuel")
  lcd.drawText(0, 50, "Fuel", SMLSIZE)
  lcd.drawText(21, 50, fuel .. "%", SMLSIZE)
  lcd.drawGauge(46, 49, 82, 7, math.min(fuel, 98), 100)

  rssi = getValue("RSSI")
  lcd.drawText(0, 58, "RSSI", SMLSIZE)
  lcd.drawText(21, 58, rssi .. "dB", SMLSIZE)
  lcd.drawGauge(46, 57, 82, 7, math.min(rssi, 98), 100)
  min = 79 * (getValue("RSSI-") / 98) + 47
  lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

  return 1
end

return {init=init, run=run, background=background}