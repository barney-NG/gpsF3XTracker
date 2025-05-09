--[[#############################################################################
SCREEN Library:

functions: ---------------------------------------------------------------------

################################################################################]]

-- Widget Definition
local sensor = {data = {}, name = 'none', err=''}
local data = {}

-- generic GPS sensor
data.genericGPS = {
    gpsAlt   = {name = "GAlt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},
    gpsSpeed = {name = "GSpd", id = 0, factor = 1.0},
}
-- generic AZ sensor
data.genericAccel = {
    az = {name = "AccZ", id = 0, factor = 1.0}
}
-- GPS-Logger3 from SM Modelbau with factory defaults
data.isLogger3 = {
    gpsSats = {name = "0870", id = 0}
}
data.isLogger3_1 = {
    gpsSats = {name = "0871", id = 0}
}
-- RCGPS from Steve Chang
data.isRCGPS = {
    gpsSats = {name = "5111", id = 0}
}
-- some useful sensors
data.addUnit = {
    addEle = {name = "ele", id = 0}
}
-- value getter
function sensor.gpsAlt()
    return getValue(sensor.data.gpsAlt.id) * sensor.data.gpsAlt.factor
end    
function sensor.gpsCoord()
    return getValue(sensor.data.gpsCoord.id)
end
function sensor.gpsSpeed()
    return getValue(sensor.data.gpsSpeed.id) * sensor.data.gpsSpeed.factor
end
function sensor.gpsSats()
    if sensor.data.gpsSats then
        return getValue(sensor.data.gpsSats.id)
    end
    return -99 
end
function sensor.az()
    return getValue(sensor.data.az.id)
end
-- simulate az with elevator for az less systems
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
    local data = data_table
    for name in pairs(data) do
        local sensorName = data[name].name
        local fieldInfo = getFieldInfo(sensorName)
        
        if type(fieldInfo) ~= 'table' then
            print("<<"..sensorName..">> missing") 
            sensor.err = string.format("Sensor <%s> not found", sensorName)
            return false
        end
        if fieldInfo.id then
            print("<<"..sensorName..">> found") 
            -- create a new sensor if needed
            if not sensor.data[name] then
                sensor.data[name] = {}
            end
            -- initialize all fields
            sensor.data[name].name = sensorName
            if data[name].factor then
                sensor.data[name].factor = data[name].factor
            end
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
    -- new approach:
    -- 1. initialize a generic GPS sensor.
    -- 2. determine sensor type and setup correction factors
    -- 3. look for satelite sensor and determine sensor type
    -- 4. look if we have an accelerometer on board
    
    local result
    sensor.name = 'Generic GPS'
    result = sensor.initializeSensor(data.genericGPS)
    if result then
        if sensor.initializeSensor(data.isLogger3) then
            sensor.name = "Logger3"
            sensor.data.gpsSpeed.factor = 1.0/3.6
        elseif sensor.initializeSensor(data.isLogger3_1) then
            -- I had to move the address because of conflict with integrated vario in receiver 
            sensor.name = "Logger3"
            sensor.data.gpsSpeed.factor = 1.0/3.6
        elseif sensor.initializeSensor(data.isRCGPS) then
            sensor.name = "RCGPS"
        end
        if not sensor.initializeSensor(data.genericAccel) then
            sensor.initializeSensor(data.addUnit)
            sensor.az = sensor.az_sim
            sensor.data.old_speed = 0
        end
    end
    return result
end

return sensor
