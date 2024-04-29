--[[#############################################################################
SCREEN Library:

functions: ---------------------------------------------------------------------

################################################################################]]

-- Widget Definition
local sensor = {data = nil, name = 'none', err=''}
local data = {}
-- GPS-Logger3 from SM Modelbau with factory defaults
data.logger3 = {
    baroAlt  = {name = "Alt", id = 0, factor = 1.0},
    gpsAlt   = {name = "GAlt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},
    gpsSpeed = {name = "GSpd", id = 0, factor = 1.0/3.6}, -- sensor data is in km/h
    gpsDate = {name = "Date", id = 0},
    gpsDist = {name = "0860", id = 0, factor = 1.0},
    gpsSats = {name = "0870", id = 0, factor = 1.0},
    gpsClimb = {name = "0880", id = 0, factor = 1.0},
    gpsDir = {name = "0890", id = 0},
    gpsRelDir = {name = "08A0", id = 0},
    VClimb = {name = "08B0", id = 0, factor = 1.0},
    Distance = {name = "Fpat", id = 0, factor = 1.0},
    ax = {name = "AccX", id = 0, factor = 1.0},
    ay = {name = "AccY", id = 0, factor = 1.0},
    az = {name = "AccZ", id = 0, factor = 1.0}
}
-- GPS V2 from FRSky
data.gpsV2 = {
    gpsAlt   = {name = "GAlt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},
    gpsSpeed = {name = "GSpd", id = 0, factor = 1.0},
    gpsDate = {name = "Date", id = 0},
    addEle = {name = "ele", id = 0}
}
-- debugging
data.testUnit = {
    rssi   = {name = "RSSI", id = 0},
    rxbat = {name = "RxBt", id = 0}
}
-- debug value getter
function sensor.rssi()
    return getValue(sensor.data.rssi.id)
end
function sensor.rxbat()
    return getValue(sensor.data.rxbat.id)
end
-- value getter
function sensor.gpsAlt()
    return getValue(sensor.data.gpsAlt.id)
end    
function sensor.gpsCoord()
    return getValue(sensor.data.gpsCoord.id)
end
function sensor.gpsSpeed()
    return getValue(sensor.data.gpsSpeed.id) * sensor.data.gpsSpeed.factor
end
function sensor.gpsDate()
    return getValue(sensor.data.gpsDate.id)
end
function sensor.gpsSats()
    if sensor.data.gpsSats then
        return getValue(sensor.data.gpsSats.id)
    end
    return 99 
end
function sensor.ax()
    return getValue(sensor.data.ax.id)
end
function sensor.ay()
    return getValue(sensor.data.ay.id)
end
function sensor.az()
    return getValue(sensor.data.az.id)
end
-- simulate az with elevator for FrSky V2

local old_speed
function sensor.az_sim()
    -- poor mans acceleratometer
    local speed = sensor.data.old_speed
    local elev = getValue(sensor.data.addEle.id)
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
        local fieldInfo = getFieldInfo(sensorName)
        print("<<"..sensorName..">>") 
        if type(fieldInfo) ~= 'table' then
            sensor.err = string.format("Sensor <%s> not found", sensorName)
            print(sensor.err)
            return false
        end
        if fieldInfo.id then
            sensor.data[name].id = fieldInfo.id
        else
            sensor.err = string.format("No ID for sensor name: <%s>", sensorName)
            return false
        end
    end
    return true
end
-- setup the telemetry unit
function sensor.init(name)
    if name == 'logger3' then
        sensor.name = name
        return sensor.initializeSensor(data.logger3)
    elseif name == 'gpsV2' then
        sensor.name = name
        sensor.az = sensor.az_sim
        return sensor.initializeSensor(data.gpsV2)
    else
        sensor.name = 'test'
        return sensor.initializeSensor(data.testUnit)
    end
    return false
end

return sensor
