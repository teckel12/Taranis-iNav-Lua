-- Taranis Q X7 iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!
-- QX7 LCD_W = 128 / LCD_H = 64
-- X9D/X9D+/X9E LCD_W = 212 / LCD_H = 64
-- X10/X12S LCD_W = 480 / LCD_H = 272

local armed = false
local modeIdPrev = false
local armedPrev = false
local headingHoldPrev = false
local altHoldPrev = false
local headingRef = 0
local noTelemWarn = true
local altitudeNextPlay = 0
local batteryNextPlay = 0
local telemFlags = -1
local maxValues = false
local batlow = false
local batcrt = false

-- modes
--  t = text
--  f = flags for text
--  a = show alititude hold
--  w = wave file
local modes = {
  { t="NO TELEM",  f=BLINK + INVERS, a=false, w=false },
  { t="HORIZON",   f=0,              a=true,  w="hrznmd.wav" },
  { t="ANGLE",     f=0,              a=true,  w="anglmd.wav" },
  { t="ACRO",      f=0,              a=true,  w="acromd.wav" },
  { t=" NOT OK ",  f=BLINK + INVERS, a=false, w=false },
  { t="READY",     f=0,              a=false, w=false },
  { t="POS HOLD",  f=0,              a=true,  w="poshld.wav" },
  { t="3D HOLD",   f=0,              a=true,  w="3dhold.wav" },
  { t="WAYPOINT",  f=0,              a=false, w="waypt.wav" },
  { t="   RTL   ", f=BLINK + INVERS, a=false, w="rtl.wav" },
  { t="FAILSAFE",  f=BLINK + INVERS, a=false, w="fson.wav" },
}

local data = {}

local function getTelemetryId(name)
    field = getFieldInfo(name)
    if field then
      return field.id
    else
      return -1
    end
end

local function flightModes()
  armed = false
  headFree = false
  headingHold = false
  altHold = false
  modeId = 1
  ok2arm = false
  posHold = false
  if (data.telemetry) then
    local modeTmp = data.mode
    modeA = math.floor(modeTmp / 10000)
    modeTmp = modeTmp - (modeA * 10000)
    modeB = math.floor(modeTmp / 1000)
    modeTmp = modeTmp - (modeB * 1000)
    modeC = math.floor(modeTmp / 100)
    modeTmp = modeTmp - (modeC * 100)
    modeD = math.floor(modeTmp / 10)
    modeE = modeTmp - (modeD * 10)
    if (modeE >= 4) then
      armed = true
      modeE = modeE - 4
      if (modeD >= 4) then
        modeD = modeD - 4
      end
      if (modeD == 2) then
        modeId = 2
      elseif (modeD == 1) then
        modeId = 3
      else
        modeId = 4
      end
    end
    if (modeE >= 2 or modeE == 0) then
      modeId = 5
    else
      ok2arm = true
      if (armed == false) then
        modeId = 6
      end
    end
    if (modeB >= 4) then
      modeB = modeB - 4
      headFree = true
    end
    if (modeC >= 4) then
      modeC = modeC - 4
      if (armed == true) then
        modeId = 7
        posHold = true
      end
    end
    if (modeC >= 2) then
      modeC = modeC - 2
      altHold = true
      if (posHold) then
        modeId = 8
      end
    end
    if (modeC == 1) then
      headingHold = true
    end  
    if (modeB >= 2) then
      modeB = modeB - 2
      modeId = 9
    end
    if (modeB == 1) then
      modeId = 10
    end
    if (modeA >= 4) then
      modeId = 11
    end
  end

  -- *** Audio feedback on flight modes ***
  vibrate = false
  beep = false
  if (armed ~= armedPrev) then
    if (armed) then
      data.timerStart = getTime()
      data.distLastPositive = 0
      headingRef = data.heading
      data.gpsHome = false
      maxValues = true
      batlow = false
      batcrt = false
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/engarm.wav")
    else
      if (data.distLastPositive < 5) then
        data.distLastPositive = 0
      end
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/engdrm.wav")
    end
  end
  if (modeIdPrev and modeIdPrev ~= modeId) then
    if (armed == false and modeId == 6 and modeIdPrev == 5) then
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/ready.wav")
    end
    if (armed) then
      if (modes[modeId].w) then
        playFile("/SCRIPTS/TELEMETRY/SOUNDS/" .. modes[modeId].w)
      end
      if (modes[modeId].f > 0) then
        vibrate = true
      end
    end
  end
  if (armed) then
    if (altHold and modes[modeId].a and altHoldPrev ~= altHold) then
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/althld.wav")
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/active.wav")
    elseif (altHold == false and modes[modeId].a and altHoldPrev ~= altHold) then
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/althld.wav")
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/off.wav")
    end
    if (headingHold and headingHoldPrev ~= headingHold) then
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/hedhlda.wav")
    elseif (headingHold == false and headingHoldPrev ~= headingHold) then
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/hedhld.wav")
      playFile("/SCRIPTS/TELEMETRY/SOUNDS/off.wav")
    end
    if (data.altitude > 400) then
      if (getTime() > altitudeNextPlay) then
        playNumber(data.altitude, 10)
        altitudeNextPlay = getTime() + 1000
      else
        beep = true
      end
    end
    if (data.fuel <= 20 or data.cell < 3.40) then
      if (getTime() > batteryNextPlay) then
        if (data.fuel <= 20) then
          playNumber(data.fuel, 13)
        else
          playFile("/SCRIPTS/TELEMETRY/SOUNDS/batcrt.wav")
        end
        batteryNextPlay = getTime() + 500
      else
        vibrate = true
        beep = true
      end
      batlow = true
    else
      batteryNextPlay = 0
    end
    if (data.fuel <= 30 or data.cell < 3.55) then
      if (batlow == false) then
        if (data.fuel <= 30) then
          playNumber(data.fuel, 13)
        else
          playFile("/SCRIPTS/TELEMETRY/SOUNDS/batlow.wav")
        end
        batlow = true
      end
    end
    if (headFree or modes[modeId].f > 0) then
      beep = true
    end
  end
  if (vibrate) then
    playHaptic(50, 3000)
  end
  if (beep) then
    playTone(2000, 100, 3000)
  end    
  modeIdPrev = modeId
  headingHoldPrev = headingHold
  altHoldPrev = altHold
  armedPrev = armed
end

local function init()
  local rssi, low, crit = getRSSI()
  local ver, radio, maj, minor, rev = getVersion()
  local general = getGeneralSettings()
  data.rssiLow = low
  data.rssiCrit = crit
  data.version = maj + minor / 10 -- Make sure OpenTX 2.2+
  data.txBattMin = general["battMin"]
  data.txBattMax = general["battMax"]
  data.units = general["imperial"] -- 0 = metric / 1 = imperial
  data.modelName = model.getInfo()["name"]
  data.mode_id = getTelemetryId("Tmp1")
  data.rxBatt_id = getTelemetryId("RxBt")
  data.satellites_id = getTelemetryId("Tmp2")
  data.gpsAlt_id = getTelemetryId("GAlt")
  data.gpsLatLon_id = getTelemetryId("GPS")
  data.heading_id = getTelemetryId("Hdg")
  data.altitude_id = getTelemetryId("Alt")
  data.distance_id = getTelemetryId("Dist")
  data.speed_id = getTelemetryId("GSpd")
  data.current_id = getTelemetryId("Curr")
  data.altitudeMax_id = getTelemetryId("Alt+")
  data.distanceMax_id = getTelemetryId("Dist+")
  data.speedMax_id = getTelemetryId("GSpd+")
  data.currentMax_id = getTelemetryId("Curr+")
  data.batt_id = getTelemetryId("VFAS")
  data.battMin_id = getTelemetryId("VFAS-")
  data.cell_id = getTelemetryId("A4")
  data.cellMin_id = getTelemetryId("A4-")
  data.fuel_id = getTelemetryId("Fuel")
  data.rssi_id = getTelemetryId("RSSI")
  data.rssiMin_id = getTelemetryId("RSSI-")
  data.txBatt_id = getTelemetryId("tx-voltage")
  data.ras_id = getTelemetryId("RAS")
  data.timerStart = 0
  data.timer = 0
  data.distLastPositive = 0
  data.gpsHome = false
  maxValues = false
  altitudeNextPlay = 0
  batteryNextPlay = 0
  noTelemWarn = true
end

local function background()
  data.rssi = getValue(data.rssi_id)
  if (data.rssi > 0 or telemFlags < 0) then
    data.telemetry = true
    data.mode = getValue(data.mode_id)
    data.rxBatt = getValue(data.rxBatt_id)
    data.satellites = getValue(data.satellites_id)
    data.gpsAlt = getValue(data.gpsAlt_id)
    data.gpsLatLon = getValue(data.gpsLatLon_id)
    data.heading = getValue(data.heading_id)
    data.altitude = getValue(data.altitude_id)
    data.distance = math.floor(getValue(data.distance_id) * 3.28084 + 0.5)
    data.speed = getValue(data.speed_id)
    data.current = getValue(data.current_id)
    data.altitudeMax = getValue(data.altitudeMax_id)
    data.distanceMax = getValue(data.distanceMax_id)
    data.speedMax = getValue(data.speedMax_id)
    data.currentMax = getValue(data.currentMax_id)
    data.batt = getValue(data.batt_id)
    data.battMin = getValue(data.battMin_id)
    data.cell = getValue(data.cell_id)
    data.cellMin = getValue(data.cellMin_id)
    data.fuel = getValue(data.fuel_id)
    data.rssiMin = getValue(data.rssiMin_id)
    data.txBatt = getValue(data.txBatt_id)
    data.rssiLast = data.rssi
    telemFlags = 0
    if (data.distance > 0) then
      data.distLastPositive = data.distance
    end
  else
    data.telemetry = false
    telemFlags = INVERS + BLINK
  end

  flightModes()

  data.gpsGood = false
  if (type(data.gpsLatLon) == "table") then
    data.gpsGood = true

    -- *** Detect simulator ***
    --if (data.gpsLatLon["lat"] < 1) then
    --  data.gpsLatLon["lat"] = math.deg(data.gpsLatLon["lat"])
    --  data.gpsLatLon["lon"] = math.deg(data.gpsLatLon["lon"]) * 2.1064
    --  if (type(data.gpsHome) == "table") then
    --    factor = math.cos(math.rad(data.gpsHome["lat"]))
    --    y = math.abs(data.gpsHome["lat"] - data.gpsLatLon["lat"]) * 365228.2
    --    x = math.abs(data.gpsHome["lon"] - data.gpsLatLon["lon"]) * 364610.4 * factor
    --    data.distLastPositive = math.floor(math.sqrt(x ^ 2 + y ^ 2) + 0.5)
    --  end
    --end

    if (armed and type(data.gpsHome) ~= "table") then
      data.gpsHome = data.gpsLatLon
    end
  end
end

local function run(event)
  lcd.clear()
  background()

  -- *** Title ***
  if (armed) then
    --data.timer = model.getTimer(0)["value"] -- Show timer1 instead of custom timer
    data.timer = (getTime() - data.timerStart) / 100
  end
  lcd.drawFilledRectangle(0, 0, LCD_W, 8)
  lcd.drawText(0 , 0, data.modelName, INVERS)
  lcd.drawTimer(60, 1, data.timer, SMLSIZE + TIMEHOUR + INVERS)

  -- Shows Tx battery voltage as number
  --lcd.drawNumber(88, 1, data.txBatt * 10.05, SMLSIZE + PREC1 + INVERS)
  --lcd.drawText(lcd.getLastPos(), 1, "V", SMLSIZE + INVERS)

  -- Show Tx battery voltage as graphic
  lcd.drawFilledRectangle(86, 1, 19, 6, ERASE)
  lcd.drawLine(105, 2, 105, 5, SOLID, ERASE)
  local battGauge = math.max(math.min((data.txBatt - data.txBattMin) / (data.txBattMax - data.txBattMin) * 17, 17), 0) + 86
  for i = 87, battGauge, 2 do
    lcd.drawLine(i, 2, i, 5, SOLID, FORCE)
  end

  if (data.rxBatt > 0 and data.telemetry) then
    lcd.drawNumber(111, 1, data.rxBatt * 10.05, SMLSIZE + PREC1 + INVERS)
    lcd.drawText(lcd.getLastPos(), 1, "V", SMLSIZE + INVERS)
  end

  -- *** Initial warning if there's no telemetry ***
  if (noTelemWarn and data.telemetry == false) then
    result = popupWarning("No Telemetry!", event)
    if (result == "CANCEL") then
      noTelemWarn = false
    end
  else
    noTelemWarn = false
    local toggle = math.floor(getTime() / 300) % 2 == 0 and true or false

    -- *** GPS Coords ***
    if (data.gpsGood) then
      value = math.floor(data.gpsAlt + 0.5) .. "ft"
      lcd.drawText(85, 9, value, SMLSIZE)
      pos = 85 + (129 - lcd.getLastPos())
      lcd.drawText(pos, 17, value, SMLSIZE + telemFlags)

      value = string.format("%.4f", data.gpsLatLon["lat"])
      lcd.drawText(85, 9, value, SMLSIZE)
      pos = 85 + (129 - lcd.getLastPos())
      lcd.drawText(pos, 25, value, SMLSIZE + telemFlags)

      value = string.format("%.4f", data.gpsLatLon["lon"])
      lcd.drawText(85, 9, value, SMLSIZE)
      pos = 85 + (129 - lcd.getLastPos())
      lcd.drawText(pos, 33, value, SMLSIZE + telemFlags)
    else
      lcd.drawFilledRectangle(88, 17, 40, 23, INVERS)
      lcd.drawText(92, 20, "No GPS", INVERS)
      lcd.drawText(101, 30, "Fix", INVERS)
    end

    -- *** Satellites ***
    value = "Sats " .. tonumber(string.sub(data.satellites, -2))
    lcd.drawText(85, 9, value, SMLSIZE)
    pos = 85 + (129 - lcd.getLastPos())
    lcd.drawText(85, 9, "         ", SMLSIZE)
    lcd.drawText(pos, 9, value, SMLSIZE + telemFlags)

    -- *** Directional indicator ***
    center = 19
    if (data.telemetry) then
      if (armed) then
        headingDisplay = data.heading - headingRef
        size = 10
        width = 145
      elseif (type(data.gpsHome) ~= "table" or data.distLastPositive <= 15) then
        headingDisplay = data.heading
        lcd.drawText(65, 9, "N", SMLSIZE)
        lcd.drawText(77, 21, "E", SMLSIZE)
        lcd.drawText(53, 21, "W", SMLSIZE)
        size = 6
        width = 135
        center = 23
      end
      local rad1 = math.rad(headingDisplay)
      local rad2 = math.rad(headingDisplay + width)
      local rad3 = math.rad(headingDisplay - width)
      local x1 = math.floor(math.sin(rad1) * size + 0.5) + 67
      local y1 = center - math.floor(math.cos(rad1) * size + 0.5)
      local x2 = math.floor(math.sin(rad2) * size + 0.5) + 67
      local y2 = center - math.floor(math.cos(rad2) * size + 0.5)
      local x3 = math.floor(math.sin(rad3) * size + 0.5) + 67
      local y3 = center - math.floor(math.cos(rad3) * size + 0.5)
      lcd.drawLine(x1, y1, x2, y2, SOLID, FORCE)
      lcd.drawLine(x1, y1, x3, y3, SOLID, FORCE)
      if (headingHold and armed) then
        lcd.drawFilledRectangle((x2 + x3) / 2 - 1.5, (y2 + y3) / 2 - 1.5, 4, 4, SOLID)
      else
        lcd.drawLine(x2, y2, x3, y3, DOTTED, FORCE)
      end
    end
    if (type(data.gpsHome) == "table" and data.gpsGood and data.distLastPositive > 15) then
      --http://www.movable-type.co.uk/scripts/latlong.html
      --var y = Math.sin(λ2-λ1) * Math.cos(φ2);
      --var x = Math.cos(φ1)*Math.sin(φ2) - Math.sin(φ1)*Math.cos(φ2)*Math.cos(λ2-λ1);
      --var brng = Math.atan2(y, x).toDegrees();
      o1 = math.rad(data.gpsHome["lat"])
      a1 = math.rad(data.gpsHome["lon"])
      o2 = math.rad(data.gpsLatLon["lat"])
      a2 = math.rad(data.gpsLatLon["lon"])
      y = math.sin(a2 - a1) * math.cos(o2)
      x = (math.cos(o1) * math.sin(o2)) - (math.sin(o1) * math.cos(o2) * math.cos(a2 - a1))
      bearing = math.deg(math.atan2(y, x)) - headingRef
      size = 10
      --size = math.max(data.distLastPositive / (data.distanceMax * 3.28084 + 0.5) * 10, 5)
      local rad1 = math.rad(bearing)
      local x1 = math.floor(math.sin(rad1) * size + 0.5) + 67
      local y1 = center - math.floor(math.cos(rad1) * size + 0.5)
      lcd.drawLine(67, center, x1, y1, DOTTED, FORCE)
      lcd.drawFilledRectangle(x1 - 1, y1 - 1, 3, 3, ERASE)
      lcd.drawFilledRectangle(x1 - 1, y1 - 1, 3, 3, SOLID)
    end

    -- *** Head free warning ***
    if (armed and headFree) then
      lcd.drawText(85, 9, "HF", SMLSIZE + INVERS + BLINK)
    end

    -- *** Display flight mode (centered) ***
    lcd.drawText(48, 34, modes[modeId].t, SMLSIZE + modes[modeId].f)
    pos = 48 + (87 - lcd.getLastPos()) / 2
    lcd.drawFilledRectangle(46, 33, 40, 10, ERASE)
    lcd.drawText(pos, 33, modes[modeId].t, SMLSIZE + modes[modeId].f)

    -- *** Data ***
    if (armed or toggle or maxValues == false) then
      altd = data.altitude
      dist = data.distLastPositive
      sped = data.speed
      curr = data.current
      lcd.drawText(0,  9, "Altd ", SMLSIZE)
      lcd.drawText(0, 17, "Dist", SMLSIZE)
      lcd.drawText(0, 25, "Sped", SMLSIZE)
      lcd.drawText(0, 33, "Curr", SMLSIZE)
    else
      altd = data.altitudeMax
      dist = math.floor(data.distanceMax * 3.28084 + 0.5)
      sped = data.speedMax
      curr = data.currentMax
      lcd.drawText(0,  9, "Alt", SMLSIZE)
      lcd.drawText(15, 9, "\192", SMLSIZE)
      lcd.drawText(0, 17, "Dst\192", SMLSIZE)
      lcd.drawText(0, 25, "Spd\192", SMLSIZE)
      lcd.drawText(0, 33, "Cur\192", SMLSIZE)
    end
    lcd.drawText(22, 9, math.floor(altd + 0.5), SMLSIZE + telemFlags)
    if (altd < 1000) then
      lcd.drawText(lcd.getLastPos(), 9, "ft", SMLSIZE + telemFlags)
    end
    if (armed and altHold and modes[modeId].a) then
      lcd.drawText(lcd.getLastPos() + 1, 9, "\192", SMLSIZE + INVERS) -- Altitude hold notification
    end
    lcd.drawText(22, 17, dist, SMLSIZE + telemFlags)
    if (dist < 1000) then
      lcd.drawText(lcd.getLastPos(), 17, "ft", SMLSIZE + telemFlags)
    end
    lcd.drawText(22, 25, math.floor(sped + 0.5), SMLSIZE + telemFlags)
    if (sped < 100) then
      lcd.drawText(lcd.getLastPos(), 25, "mph", SMLSIZE + telemFlags)
    end
    lcd.drawNumber(22, 33, curr * 10.05, SMLSIZE + PREC1 + telemFlags)
    if (curr < 100) then
      lcd.drawText(lcd.getLastPos(), 33, "A", SMLSIZE + telemFlags)
    end

    -- *** Bar graphs ***
    if (data.cell_id == -1 or data.cell == 3) then
      data.cells = math.floor(data.batt / 4.3) + 1
      data.cell = data.batt / data.cells
      data.cellMin = data.battMin / data.cells
    end
    local battFlags = 0
    if (telemFlags > 0 or batteryNextPlay > 0) then
      battFlags = INVERS + BLINK
    end
    lcd.drawText(0, 41, "Fuel", SMLSIZE)
    lcd.drawText(22, 41, data.fuel .. "%", SMLSIZE + battFlags)
    lcd.drawGauge(46, 41, 82, 7, math.min(data.fuel, 98), 100)
    if (armed or toggle or maxValues == false) then
      lcd.drawText(0, 49, "Batt", SMLSIZE)
      lcd.drawNumber(22, 49, data.batt * 10.05, SMLSIZE + PREC1 + battFlags)
      lcd.drawText(lcd.getLastPos(), 49, "V", SMLSIZE + battFlags)
      lcd.drawText(0, 57, "RSSI", SMLSIZE)
      lcd.drawText(22, 57, data.rssiLast .. "dB", SMLSIZE + telemFlags)
    else
      lcd.drawText(0, 49, "Bat\193", SMLSIZE)
      lcd.drawNumber(22, 49, data.battMin * 10.05, SMLSIZE + PREC1 + telemFlags)
      lcd.drawText(lcd.getLastPos(), 49, "V", SMLSIZE + telemFlags)
      lcd.drawText(0, 57, "RSI", SMLSIZE)
      lcd.drawText(15, 57, "\193", SMLSIZE)
      lcd.drawText(22, 57, data.rssiMin .. "dB", SMLSIZE + telemFlags)
    end
    if (data.fuel == 0) then
      lcd.drawLine(47, 42, 47, 46, SOLID, ERASE)
    end
    lcd.drawGauge(46, 49, 82, 7, math.min(math.max(data.cell - 3.3, 0) * 111.1, 98), 100)
    min = 80 * (math.min(math.max(data.cellMin - 3.3, 0) * 111.1, 99) / 100) + 47
    lcd.drawLine(min, 50, min, 54, SOLID, ERASE)
    lcd.drawGauge(46, 57, 82, 7, math.min(data.rssiLast, 98), 100)
    min = 80 * (math.min(data.rssiMin, 99) / 100) + 47
    lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

    -- *** Altitude bar graph (maybe use for larger screens?) ***
    --lcd.drawRectangle(124, 9, 4, 55, SOLID)
    --height = math.max(math.min(math.ceil(data.altitude / 400 * 53), 53), 1)
    --lcd.drawRectangle(125, 63 - height, 2, height, SOLID)

  end

  return 1
end

return {init=init, run=run, background=background}