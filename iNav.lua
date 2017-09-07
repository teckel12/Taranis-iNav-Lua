-- Taranis Q X7 iNav Flight Status Panel - v1.0
-- Author: teckel12
-- https://github.com/teckel12/Taranis-iNav-Lua
-- Telemetry distance sensor name must be changed from '0420' to 'Dist'
-- Sensors must be changed to US measurements (all values displayed in US measurements)
-- Use at your own risk!
-- QX7 LCD_W = 128 / LCD_H = 64
-- X9D LCD_W = 212 / LCD_H = 64

local modeIdPrev = false
local armedPrev = false
local headingHoldPrev = false
local altHoldPrev = false
local headingRef = 0
local noTelemWarn = false
local altitudeNextPlay = 0
local telemFlags = -1

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

local function init()
  modelName = model.getInfo()["name"]

  if (getValue("Tmp1") <= 0) then
    noTelemWarn = true
  end
end

local function background()
  mode = getValue("Tmp1")
  if (mode > 0 or telemFlags < 0) then
    rxBatt = getValue("RxBt")
    satellites = getValue("Tmp2")
    gpsAlt = getValue("GAlt")
    gpsLatLon = getValue("GPS")
    heading = getValue("Hdg")
    altitude = getValue("Alt")
    distance = getValue("Dist")
    speed = getValue("GSpd")
    current = getValue("Curr")
    altitudeMax = getValue("Alt+")
    distanceMax = getValue("Dist+")
    speedMax = getValue("GSpd+")
    currentMax = getValue("Curr+")
    batt = getValue("VFAS")
    battMin = getValue("VFAS-")
    cell = getValue("A4")
    cellMin = getValue("A4-")
    fuel = getValue("Fuel")
    rssi = getValue("RSSI")
    rssiMin = getValue("RSSI-")
    telemFlags = 0
  else
    telemFlags = INVERS + BLINK
  end
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
  background()

  -- *** Title ***
  lcd.drawFilledRectangle(0, 0, LCD_W, 8)
  lcd.drawText(0 , 0, modelName, INVERS)
  lcd.drawNumber(84, 0, getValue("tx-voltage") * 10, PREC1 + INVERS)
  lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)
  if (rxBatt > 0) then
    lcd.drawNumber(111, 0, rxBatt * 10, PREC1 + INVERS)
    lcd.drawText(lcd.getLastPos(), 0, "V", INVERS)
  end

  -- *** Initial warning if there's no telemetry ***
  if (noTelemWarn and mode <= 0) then
    result = popupWarning("No Telemetry!", event)
    if (result == "CANCEL") then
      noTelemWarn = false
    end
  else
    noTelemWarn = false

    -- *** Satellites ***
    sats = tonumber(string.sub(satellites, -2))
    lcd.drawText(93, 9, "Sats " .. string.format("%2d", sats), SMLSIZE + telemFlags)

    -- *** GPS Coords ***
    if (type(gpsLatLon) == "table") then
      lcd.drawText(96, 17, string.format("%5d", gpsAlt) .. "ft", SMLSIZE + telemFlags)
      lcd.drawText(82, 25, displayLat(gpsLatLon["lat"]), SMLSIZE)
      pos = 82 + (129 - lcd.getLastPos())
      lcd.drawText(82, 33, "      ", SMLSIZE)
      lcd.drawText(pos, 25, displayLat(gpsLatLon["lat"]), SMLSIZE + telemFlags)
      lcd.drawText(82, 33, displayLon(gpsLatLon["lon"]), SMLSIZE)
      pos = 82 + (129 - lcd.getLastPos())
      lcd.drawText(82, 33, "      ", SMLSIZE)
      lcd.drawText(pos, 33, displayLon(gpsLatLon["lon"]), SMLSIZE + telemFlags)
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
    modeId = 1
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
          modeId = 2
        elseif (modeD == 1) then
          modeId = 3
        else
          modeId = 4
        end
      else
        armed = false
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

    -- *** Directional indicator ***
    if (mode > 0) then
      if (armed) then
        if (armedPrev == false) then
          headingRef = heading
        end
        heading = heading - headingRef
        size = 10
        width = 145
        center = 19
      else
        lcd.drawText(65, 8, "N", SMLSIZE)
        lcd.drawText(77, 20, "E", SMLSIZE)
        lcd.drawText(53, 20, "W", SMLSIZE)
        size = 6
        width = 135
        center = 22
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
    if (armed and headFree) then
      lcd.drawText(48, 9, "HEADFREE", SMLSIZE + INVERS + BLINK)
    end

    -- *** Display flight mode (centered) ***
    lcd.drawText(48, 34, modes[modeId].t, SMLSIZE + modes[modeId].f)
    pos = 48 + (87 - lcd.getLastPos()) / 2
    lcd.drawFilledRectangle(46, 33, 40, 10, ERASE)
    lcd.drawText(pos, 33, modes[modeId].t, SMLSIZE + modes[modeId].f)

    -- *** Data ***
    if (armed) then
      altd = altitude
      dist = distance
      sped = speed
      curr = current
      tags = SMLSIZE
    else
      altd = altitudeMax
      dist = distanceMax
      sped = speedMax
      curr = currentMax
      lcd.drawFilledRectangle(0, 8, 20, 32, INVERS)
      tags = SMLSIZE + INVERS
    end
    if (altHold and modes[modeId].a) then
      lcd.drawText(0, 9, "Altd ", SMLSIZE + INVERS)
      altitudeFlags = SMLSIZE + INVERS
    else
      lcd.drawText(0, 9, "Altd", tags)
      altitudeFlags = SMLSIZE
    end
    lcd.drawText(0, 17, "Dist", tags)
    lcd.drawText(0, 25, "Sped", tags)
    lcd.drawText(0, 33, "Curr", tags)
    lcd.drawText(22, 9, math.floor(altd), altitudeFlags + telemFlags)
    if (altd < 1000) then
      lcd.drawText(lcd.getLastPos(), 9, "ft", altitudeFlags + telemFlags)
    end
    lcd.drawText(22, 17, math.floor(dist * 3.28084), SMLSIZE + telemFlags)
    if (dist < 1000) then
      lcd.drawText(lcd.getLastPos(), 17, "ft", SMLSIZE + telemFlags)
    end
    lcd.drawText(22, 25, math.floor(sped), SMLSIZE + telemFlags)
    if (sped < 100) then
      lcd.drawText(lcd.getLastPos(), 25, "mph", SMLSIZE + telemFlags)
    end
    lcd.drawNumber(22, 33, curr * 10, SMLSIZE + PREC1 + telemFlags)
    if (curr < 100) then
      lcd.drawText(lcd.getLastPos(), 33, "A", SMLSIZE + telemFlags)
    end

    -- *** Bar graphs ***
    if (cell == 0 or cell == 3) then
      cells = math.floor(batt / 4.3) + 1
      cell = batt / cells
      cellMin = battMin / cells
    end
    lcd.drawText(0, 42, "Batt", SMLSIZE)
    lcd.drawNumber(22, 42, batt * 10, SMLSIZE + PREC1 + telemFlags)
    lcd.drawText(lcd.getLastPos(), 42, "V", SMLSIZE + telemFlags)
    lcd.drawGauge(46, 41, 82, 7, math.min(math.max(cell - 3.3, 0) * 111.1, 98), 100)
    min = 79 * (math.min(math.max(cellMin - 3.3, 0) * 111.1, 98) / 100) + 47
    lcd.drawLine(min, 42, min, 46, SOLID, ERASE)

    lcd.drawText(0, 50, "Fuel", SMLSIZE)
    lcd.drawText(22, 50, fuel .. "%", SMLSIZE + telemFlags)
    lcd.drawGauge(46, 49, 82, 7, math.min(fuel, 98), 100)

    lcd.drawText(0, 58, "RSSI", SMLSIZE)
    lcd.drawText(22, 58, rssi .. "dB", SMLSIZE + telemFlags)
    lcd.drawGauge(46, 57, 82, 7, math.min(rssi, 98), 100)
    min = 79 * (math.min(rssiMin, 98) / 98) + 47
    lcd.drawLine(min, 58, min, 62, SOLID, ERASE)

    -- *** Altitude bar graph (maybe use for larger screens?) ***
    --lcd.drawRectangle(124, 9, 4, 55, SOLID)
    --height = math.max(math.min(math.ceil(altitude / 400 * 53), 53), 1)
    --lcd.drawRectangle(125, 63 - height, 2, height, SOLID)

    -- *** Audio feedback on flight modes ***
    if (modeIdPrev and modeIdPrev ~= modeId) then
      if (armed and modeID ~=5 and modeIdPrev == 6) then
        playFile("/SCRIPTS/TELEMETRY/SOUNDS/engarm.wav")
      elseif (armed == false and modeId == 6 and modeIdPrev ~= 5 and modeIdPrev ~= 1) then
        playFile("/SCRIPTS/TELEMETRY/SOUNDS/engdrm.wav")
      elseif (armed == false and modeId == 6 and modeIdPrev == 5) then
        playFile("/SCRIPTS/TELEMETRY/SOUNDS/gps.wav")
        playFile("/SCRIPTS/TELEMETRY/SOUNDS/good.wav")
      end
      if (armed) then
        if (modes[modeId].w) then
          playFile("/SCRIPTS/TELEMETRY/SOUNDS/" .. modes[modeId].w)
        end
        if (modes[modeId].f) then
          playHaptic(100, 1000, PLAY_NOW)
        end
      end
    elseif (armed) then
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
      if (altitude > 400 and getTime() > altitudeNextPlay) then
        playNumber(altitude, 10)
        --playFile("/SCRIPTS/TELEMETRY/SOUNDS/toohgh.wav")
        altitudeNextPlay = getTime() + 1000
      end
      if (headFree or modes[modeId].f > 0) then
        playTone(2000, 100, 3000, PLAY_NOW)
      end
    end
    --playNumber(value, unit [, attributes]) --PREC1 PREC2
    --playDuration(duration [, hourFormat])
    modeIdPrev = modeId
    headingHoldPrev = headingHold
    altHoldPrev = altHold
  
  end

  return 1
end

return {init=init, run=run, background=background}