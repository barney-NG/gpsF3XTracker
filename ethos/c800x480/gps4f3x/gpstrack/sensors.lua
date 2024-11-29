--[[#############################################################################
SENSOR Library:

functions: ---------------------------------------------------------------------

################################################################################]]

-- Widget Definition
local sensor = {data = nil, name = 'none', err=''}
local data = {}
-- GPS-Logger3 from SM Modelbau with factory defaults
data.logger3 = {
    -- baroAlt  = {name = "Alt", source = 0, factor = 1.0},
    gpsAlt   = {name = "GPS alt", source = 0, factor = 1.0},
    gpsCoord = {name = "GPS", source = 0},
    gpsSpeed = {name = "GPS speed", source = 0, factor = 1.0/3.6}, -- sensor data is in km/h
    gpsDate = {name = "GPS clock", source = 0},
    -- gpsDist = {name = "0860", source = 0, factor = 1.0},
    gpsSats = {name = "SATS", source = 0, factor = 1.0},
    -- gpsClimb = {name = "0880", source = 0, factor = 1.0},
    gpsDir = {name = "GPS course", source = 0},
    -- gpsRelDir = {name = "08A0", source = 0},
    -- VClimb = {name = "08B0", source = 0, factor = 1.0},
    -- Distance = {name = "Fpat", source = 0, factor = 1.0},
    ax = {name = "AccX", source = 0, factor = 1.0},
    ay = {name = "AccY", source = 0, factor = 1.0},
    az = {name = "AccZ", source = 0, factor = 1.0}
}
-- Any GPS Sensor with internal gyro
data.gps_with_gyro = {
    gpsAlt   = {name = "GPS alt", source = 0, factor = 1.0},
    gpsCoord = {name = "GPS", source = 0},
    gpsSpeed = {name = "GPS speed", source = 0, factor = 1.0/3.6}, -- sensor data is in km/h
    gpsDate = {name = "GPS clock", source = 0},
    ax = {name = "AccX", source = 0, factor = 1.0},
    ay = {name = "AccY", source = 0, factor = 1.0},
    az = {name = "AccZ", source = 0, factor = 1.0}
}
-- GPS V2 from FRSky
data.gpsV2 = {
    gpsAlt   = {name = "GPS alt", source = 0, factor = 1.0},
    gpsCoord = {name = "GPS", source = 0},
    gpsSpeed = {name = "GPS speed", source = 0, factor = 1.0},
    gpsDate = {name = "GPS clock", source = 0},
    addEle = {name = "ele", source = 0}
}
-- debugging
data.testUnit = {
    rssi   = {name = "RSSI", source = 0},
    rxbat = {name = "RxBt", source = 0}
}
-- debug value getter
function sensor.rssi()
    return sensor.data.rssi.source:value()
end
function sensor.rxbat()
    return sensor.data.rxbat.source:value()
end
-- value getter
function sensor.gpsAlt()
    return sensor.data.gpsAlt.source:value()
end    
function sensor.gpsCoord()
    return sensor.data.gpsCoord.source:value()
end
function sensor.gpsSpeed()
    return sensor.data.gpsSpeed.source:value() * sensor.data.gpsSpeed.factor
end
function sensor.gpsDate()
    return sensor.data.gpsDate.source:value()
end
function sensor.gpsSats()
    if sensor.data.gpsSats.source then
        return sensor.data.gpsSats.source:value()
    end
    return 99 
end
function sensor.ax()
    return sensor.data.ax.source:value()
end
function sensor.ay()
    return sensor.data.ay.source:value()
end
function sensor.az()
    return sensor.data.az.source:value()
end
-- simulate az with elevator for FrSky V2

local old_speed
function sensor.az_sim()
    -- poor mans acceleratometer
    local speed = sensor.data.old_speed
    local elev = sensor.data.addEle.source:value()
    local az = 0
    if math.abs(elev) < 103 then
        -- take groundspeed only if the elevator is used less than 10%
        speed = sensor.gpsSpeed() 
        old_speed = speed 
    end
    -- I still follow up the idea that we fly on a radius r ~= |v| -> az ~= v
    -- Then az shall be proportional to elevator-deflection * groundspeed
    az = elev * speed / 5120.0
    -- we can limit az to 16 here, because the logger3 limit seems to be 16
    --if az > 16.0 then
    --    az = 16.0
    --end
    return az
end

-- read the field infos for all sensors of the telemetry unit 
function sensor.initializeSensor(data_table)
    sensor.data = data_table
    for name in pairs(sensor.data) do
        local sensorName = sensor.data[name].name
        local sens = system.getSource(sensorName)
        print("<<"..sensorName..">>") 
        if type(sens) ~= 'table' then
            sensor.err = string.format("ERR: sensor <%s> not found", sensorName)
            print(sensor.err)
            return false
        end
        sensor.data[name].source = sens
    end
    return true
end
-- setup the telemetry unit
function sensor.init(name)
    -- system.registerSource({key="_GALT", name="GPSAltitude", init=sensor.sourceInit, wakeup=sensor.sourceWakeup})
    -- sensor.data.rssi.source = system.getSource("RSSI")
    print("<<<logger3>>>")
    if sensor.initializeSensor(data.logger3) then
        return true
    end
    print("<<<gps with AccZ>>>")
    if sensor.initializeSensor(data.gps_with_gyro) then
        return true
    end
    print("<<<gps only>>>")
    if sensor.initializeSensor(data.gpsV2) then
        return true
    end
    return false
end

return sensor
