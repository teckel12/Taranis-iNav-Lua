-- Taranis iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!
-- QX7 LCD_W = 128 / LCD_H = 64
-- X9D/X9D+/X9E LCD_W = 212 / LCD_H = 64
-- X10/X12S LCD_W = 480 / LCD_H = 272

local wavPath = "/SCRIPTS/TELEMETRY/iNav/"

--local test = true
local modeIdPrev = false
local armedPrev = false
local headingHoldPrev = false
local altHoldPrev = false
local headingRef = -1
local altNextPlay = 0
local battNextPlay = 0
local battPercentPlayed = 100
local telemFlags = -1
local battlow = false
local showMax = false
local showDir = true

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
  { t="   RTH   ", f=BLINK + INVERS, a=false, w="rtl.wav" },
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
  ok2arm = false
  posHold = false
  if (data.telemetry) then
    local modeA = math.floor(data.mode / 10000)
    local modeB = math.floor(data.mode / 1000 ) % 10
    local modeC = math.floor(data.mode / 100) % 10
    local modeD = math.floor(data.mode / 10) % 10
    local modeE = data.mode % 10
    if (bit32.band(modeE, 4) > 0) then
      armed = true
      if (bit32.band(modeD, 2) > 0) then
        modeId = 2 -- Horizon mode
      elseif (bit32.band(modeD, 1) > 0) then
        modeId = 3 -- Angle mode
      else
        modeId = 4 -- Acro mode
      end
    end
    if (bit32.band(modeE, 2) > 0 or modeE == 0) then
      modeId = 5 -- Not OK to fly
    else
      ok2arm = true
      if (not armed) then
        modeId = 6 -- Ready to fly
      end
    end
    if (bit32.band(modeB, 4) > 0) then
      headFree = true
    end
    if (bit32.band(modeC, 4) > 0) then
      if (armed) then
        modeId = 7 -- Position hold
        posHold = true
      end
    end
    if (bit32.band(modeC, 2) > 0) then
      altHold = true
      if (posHold) then
        modeId = 8 -- 3D potition hold
      end
    end
    if (bit32.band(modeC, 1) > 0) then
      headingHold = true
    end  
    if (bit32.band(modeB, 2) > 0) then
      modeId = 9 -- Waypoint
    end
    if (bit32.band(modeB, 4) > 0) then
      modeId = 10 -- Return to home
    end
    if (bit32.band(modeA, 4) > 0) then
      modeId = 11 -- Failsafe
    end
  else
    modeId = 1 -- No telemetry
  end

  -- *** Audio feedback on flight modes ***
  local vibrate = false
  local beep = false
  if (armed ~= armedPrev) then
    if (armed) then
      data.timerStart = getTime()
      data.distLastPositive = 0
      headingRef = data.heading
      data.gpsHome = false
      battPercentPlayed = 100
      battlow = false
      showMax = false
      showDir = false
      playFile(wavPath .. "engarm.wav")
    else
      if (data.distLastPositive < 15) then
        headingRef = -1
        showDir = true
      end
      playFile(wavPath .. "engdrm.wav")
    end
  end
  if (modeIdPrev and modeIdPrev ~= modeId) then
    if (not armed and modeId == 6 and modeIdPrev == 5) then
      playFile(wavPath .. "ready.wav")
    end
    if (armed) then
      if (modes[modeId].w) then
        playFile(wavPath .. modes[modeId].w)
      end
      if (modes[modeId].f > 0) then
        vibrate = true
      end
    end
  end
  if (armed) then
    if (altHold and modes[modeId].a and altHoldPrev ~= altHold) then
      playFile(wavPath .. "althld.wav")
      playFile(wavPath .. "active.wav")
    elseif (not altHold and modes[modeId].a and altHoldPrev ~= altHold) then
      playFile(wavPath .. "althld.wav")
      playFile(wavPath .. "off.wav")
    end
    if (headingHold and headingHoldPrev ~= headingHold) then
      playFile(wavPath .. "hedhlda.wav")
    elseif (not headingHold and headingHoldPrev ~= headingHold) then
      playFile(wavPath .. "hedhld.wav")
      playFile(wavPath .. "off.wav")
    end
    if (data.altitude > 400) then
      if (getTime() > altNextPlay) then
        playNumber(data.altitude, 10)
        altNextPlay = getTime() + 1000
      else
        beep = true
      end
    end
    if (battPercentPlayed > data.fuel) then
      if (data.fuel == 30 or data.fuel == 25) then
        playFile(wavPath .. "batlow.wav")
        playNumber(data.fuel, 13)
        battPercentPlayed = data.fuel
      elseif (data.fuel % 10 == 0 and data.fuel < 100 and data.fuel >= 40) then
        playFile(wavPath .. "battry.wav")
        playNumber(data.fuel, 13)
        battPercentPlayed = data.fuel
      end
    end
    if (data.fuel <= 20 or data.cell < 3.40) then
      if (getTime() > battNextPlay) then
        playFile(wavPath .. "batcrt.wav")
        if (data.fuel <= 20 and battPercentPlayed > data.fuel) then
          playNumber(data.fuel, 13)
          battPercentPlayed = data.fuel
        end
        battNextPlay = getTime() + 500
      else
        vibrate = true
        beep = true
      end
      battlow = true
    else
      battNextPlay = 0
    end
    if (data.cell < 3.50) then
      if (not battlow) then
        playFile(wavPath .. "batlow.wav")
        battlow = true
      end
    end
    if (headFree or modes[modeId].f > 0) then
      beep = true
    end
    if (data.rssi < data.rssiLow) then
      if (data.rssi < data.rssiCrit) then
        vibrate = true
      end
      beep = true
    end
    if (vibrate) then
      playHaptic(25, 3000)
    end
    if (beep) then
      playTone(2000, 100, 3000, PLAY_NOW)
    end    
  end
  if (data.fuel > 20) then
    battlow = false
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
  data.fuel_id = getTelemetryId("Fuel")
  data.rssi_id = getTelemetryId("RSSI")
  data.rssiMin_id = getTelemetryId("RSSI-")
  data.txBatt_id = getTelemetryId("tx-voltage")
  data.ras_id = getTelemetryId("RAS")
  data.timerStart = 0
  data.timer = 0
  data.distLastPositive = 0
  data.gpsHome = false
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
    data.cells = math.floor(data.batt / 4.3) + 1
    data.cell = data.batt / data.cells
    data.cellMin = data.battMin / data.cells
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

  -- Fix GPS coords and distance
  --if (test and type(data.gpsLatLon) == "table") then
  --  data.gpsLatLon["lat"] = math.deg(data.gpsLatLon["lat"])
  --  data.gpsLatLon["lon"] = math.deg(data.gpsLatLon["lon"]) * 2.1064
  --  if (type(data.gpsHome) == "table") then
  --    factor = math.cos(math.rad(data.gpsHome["lat"]))
  --    y = math.abs(data.gpsHome["lat"] - data.gpsLatLon["lat"]) * 365228.2
  --    x = math.abs(data.gpsHome["lon"] - data.gpsLatLon["lon"]) * 364610.4 * factor
  --    data.distLastPositive = math.floor(math.sqrt(x ^ 2 + y ^ 2) + 0.5)
  --  end
  --end

  if (armed and type(data.gpsLatLon) == "table" and type(data.gpsHome) ~= "table") then
    data.gpsHome = data.gpsLatLon
  end
end

local function run(event)
  lcd.clear()
  background()

  -- *** Minimum OpenTX version ***
  if (data.version < 2.2) then
    lcd.drawText(5, 27, "OpenTX v2.2.0+ Required")
    return
  end

  -- *** Title ***
  if (armed) then
    --data.timer = model.getTimer(0)["value"] -- Show timer1 instead of custom timer
    data.timer = (getTime() - data.timerStart) / 100
  end
  lcd.drawFilledRectangle(0, 0, LCD_W, 8)
  lcd.drawText(0 , 0, data.modelName, INVERS)
  lcd.drawTimer(60, 1, data.timer, SMLSIZE + TIMEHOUR + INVERS)
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

  -- *** GPS Coords ***
  if (type(data.gpsLatLon) == "table") then
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
  if (event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT or event == EVT_ENTER_BREAK) then
    showDir = not showDir
  end
  center = 19
  if (data.telemetry) then
    if (showDir or headingRef < 0) then
      headingDisplay = data.heading
      lcd.drawText(65, 9, "N " .. math.floor(data.heading + 0.5) .. "\64", SMLSIZE)
      lcd.drawText(77, 21, "E", SMLSIZE)
      lcd.drawText(53, 21, "W", SMLSIZE)
      size = 7
      width = 135
      center = 23
    elseif (headingRef >= 0) then
      headingDisplay = data.heading - headingRef
      size = 10
      width = 145
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
  if (not showDir and type(data.gpsHome) == "table" and type(data.gpsLatLon) == "table" and data.distLastPositive >= 25) then
    o1 = math.rad(data.gpsHome["lat"])
    a1 = math.rad(data.gpsHome["lon"])
    o2 = math.rad(data.gpsLatLon["lat"])
    a2 = math.rad(data.gpsLatLon["lon"])
    y = math.sin(a2 - a1) * math.cos(o2)
    x = (math.cos(o1) * math.sin(o2)) - (math.sin(o1) * math.cos(o2) * math.cos(a2 - a1))
    bearing = math.deg(math.atan2(y, x)) - headingRef
    size = 10
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
  if (not armed) then
    if (event == EVT_ROT_LEFT or event == EVT_ROT_RIGHT or event == EVT_ENTER_BREAK) then
      showMax = not showMax
    end
  end
  if (showMax) then
    altd = data.altitudeMax
    dist = math.floor(data.distanceMax * 3.28084 + 0.5)
    sped = data.speedMax
    curr = data.currentMax
    batt = data.battMin
    rssi = data.rssiMin
    lcd.drawText(0,  9, "Alt", SMLSIZE)
    lcd.drawText(15, 9, "\192", SMLSIZE)
    lcd.drawText(0, 17, "Dst\192", SMLSIZE)
    lcd.drawText(0, 25, "Spd\192", SMLSIZE)
    lcd.drawText(0, 33, "Cur\192", SMLSIZE)
    lcd.drawText(0, 49, "Bat\193", SMLSIZE)
    lcd.drawText(0, 57, "RSI", SMLSIZE)
    lcd.drawText(15, 57, "\193", SMLSIZE)
  else
    altd = data.altitude
    dist = data.distLastPositive
    sped = data.speed
    curr = data.current
    batt = data.batt
    rssi = data.rssiLast
    lcd.drawText(0,  9, "Altd ", SMLSIZE)
    lcd.drawText(0, 17, "Dist", SMLSIZE)
    lcd.drawText(0, 25, "Sped", SMLSIZE)
    lcd.drawText(0, 33, "Curr", SMLSIZE)
    lcd.drawText(0, 49, "Batt", SMLSIZE)
    lcd.drawText(0, 57, "RSSI", SMLSIZE)
  end
  lcd.drawText(0, 41, "Fuel", SMLSIZE)
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
  local battFlags = 0
  if (telemFlags > 0 or battlow) then
    battFlags = INVERS + BLINK
  end
  lcd.drawText(22, 41, data.fuel .. "%", SMLSIZE + battFlags)
  lcd.drawNumber(22, 49, batt * 10.05, SMLSIZE + PREC1 + battFlags)
  lcd.drawText(lcd.getLastPos(), 49, "V", SMLSIZE + battFlags)
  local rssiFlags = 0
  if (telemFlags > 0 or data.rssi < data.rssiLow) then
    rssiFlags = INVERS + BLINK
  end
  lcd.drawText(22, 57, rssi .. "dB", SMLSIZE + rssiFlags)

  -- *** Bar graphs ***
  lcd.drawGauge(46, 41, 82, 7, math.min(data.fuel, 98), 100)
  if (data.fuel == 0) then
    lcd.drawLine(47, 42, 47, 46, SOLID, ERASE)
  end
  lcd.drawGauge(46, 49, 82, 7, math.min(math.max(data.cell - 3.3, 0) * 111.1, 98), 100)
  min = 80 * (math.min(math.max(data.cellMin - 3.3, 0) * 111.1, 99) / 100) + 47
  lcd.drawLine(min, 50, min, 54, SOLID, ERASE)
  local rssiGauge = math.max(math.min((data.rssiLast - data.rssiCrit) / (100 - data.rssiCrit) * 100, 98), 0)
  lcd.drawGauge(46, 57, 82, 7, rssiGauge, 100)
  min = 80 * (math.max(math.min((data.rssiMin - data.rssiCrit) / (100 - data.rssiCrit) * 100, 99), 0) / 100) + 47
  lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

  -- *** Altitude graph for wide screens ***
  if (LCD_W >= 212) then
    lcd.drawRectangle(135, 9, LCD_W - 135, 55, SOLID)
    height = math.max(math.min(math.ceil(data.altitude / 400 * 53), 53), 1)
    lcd.drawFilledRectangle(136, 63 - height, LCD_W - 137, height, INVERS)
  end

  return 1
end

return {init=init, run=run, background=background}