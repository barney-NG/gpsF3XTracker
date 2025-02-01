--[[#############################################################################
SENSOR Library: GPS F3X Tracker for Ethos v1.0

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

functions: ---------------------------------------------------------------------

################################################################################]]

local sensor = {data = nil, name = 'none', err=''}
local data = {}
-- GPS-Logger3 from SM Modelbau with factory defaults
data.logger3 = {
--    baroAlt  = {name = "Alt", id = 0, factor = 1.0},
    gpsAlt   = {name = "GAlt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},  
    gpsSpeed = {name = "GSpd", id = 0, factor = 1.0/3.6},   -- SM modellbau gives km/h by default, we need m/s
    gpsDate = {name = "Date", id = 0},
--    gpsDist = {name = "0860", id = 0, factor = 1.0},
--    gpsSats = {name = "0870", id = 0, factor = 1.0},
    gpsSats = {name = "GSats", id = 0, factor = 1.0},
--    gpsClimb = {name = "0880", id = 0, factor = 1.0},
--    gpsDir = {name = "0890", id = 0},
--    gpsRelDir = {name = "08A0", id = 0},
--    VClimb = {name = "08B0", id = 0, factor = 1.0},
--    Distance = {name = "Fpat", id = 0, factor = 1.0},
    ax = {name = "AccX", id = 0, factor = 1.0},
    ay = {name = "AccY", id = 0, factor = 1.0},
    az = {name = "AccZ", id = 0, factor = 1.0}
}
-- Any GPS Sensor with internal gyro
data.gps_with_gyro = {
    gpsAlt   = {name = "GAlt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},
    gpsSpeed = {name = "GSpd", id = 0, factor = 1.0/3.6},   -- if sensor gives km/h
    gpsDate = {name = "Date", id = 0},
    ax = {name = "AccX", id = 0, factor = 1.0},
    ay = {name = "AccY", id = 0, factor = 1.0},
    az = {name = "AccZ", id = 0, factor = 1.0}
}
-- GPS V2 from FRSky
data.gpsV2 = {
    gpsAlt   = {name = "GPS Alt", id = 0, factor = 1.0},
    gpsCoord = {name = "GPS", id = 0},
    gpsSpeed = {name = "GPS Speed", id = 0, factor = 1.0},    -- not sure about unit, but as per print it seems to be knots????
    gpsDate = {name = "GPS Clock", id = 0},
--    addEle = {name = "ele", id = 0}                         -- deflection of elevator - used for speed calculation in fuction sensor.az_simm replaced by configurable elevator channel
}
-- debugging
data.testUnit = {
    rssi   = {name = "RSSI", id = 0},
    rxbat = {name = "RxBatt", id = 0}
}
-- debug value getter
function sensor.rssi()
  print ("sensor - sensor.data.rssi.id:value()", sensor.data.rssi.id:value())
  return sensor.data.rssi.id:value()
end
function sensor.rxbat()
  print ("sensor - sensor.data.rxbat.id:value()", sensor.data.rxbat.id:value())
  return sensor.data.rxbat.id:value()
end
-- value getter
function sensor.gpsAlt()
  return sensor.data.gpsAlt.id:value()
end    
function sensor.gpsCoord()
--  print ("sensor - sensor.data.gpsCoord.id:value({options=OPTION_LATITUDE})", sensor.data.gpsCoord.id:value({options=OPTION_LATITUDE}))
--  print ("sensor - sensor.data.gpsCoord.id:value({options=OPTION_LONGITUDE})", sensor.data.gpsCoord.id:value({options=OPTION_LONGITUDE}))
  return {lat=sensor.data.gpsCoord.id:value({options=OPTION_LATITUDE}), lon=sensor.data.gpsCoord.id:value({options=OPTION_LONGITUDE})}
end
function sensor.gpsSpeed()
--  print ("sensor - sensor.data.gpsSpeed.id:value()", sensor.data.gpsSpeed.id:value())
  local speed = sensor.data.gpsSpeed.id:value()
  if speed then 
    return sensor.data.gpsSpeed.id:value() * sensor.data.gpsSpeed.factor
  end  
end
function sensor.gpsDate()
  print ("sensor - sensor.data.gpsDate.id:value()", sensor.data.gpsDate.id:value())  
  return sensor.data.gpsDate.id:value()
end
function sensor.gpsSats()
  if sensor.data.gpsSats then
      print ("sensor - sensor.data.gpsSats.id:value()", sensor.data.gpsSats.id:value())  
      return sensor.data.gpsSats.id:value()
  end
  return 0
end
function sensor.ax()
  print ("sensor - sensor.data.ax.id:value()", sensor.data.ax.id:value())  
  return sensor.data.ax.id:value()
end
function sensor.ay()
  print ("sensor - sensor.data.ay.id:value()", sensor.data.ay.id:value())  
  return sensor.data.ay.id:value()
end
function sensor.az()
  print ("sensor - sensor.data.az.id:value()", sensor.data.az.id:value())  
  return sensor.data.az.id:value()
end

local old_speed = 0
function sensor.az_sim()                                    -- poor mans accelerometer, needed only when FRSky GPS is used
--  local speed = sensor.data.old_speed                       -- not clear what is sensor.data.old_speed?, moreover when abs(ELEV) >= 103 --> speed == nil! -> REVISION: 1) old_speed = 0, 2) speed = old_speed
  local speed = old_speed                       
  local elev = global_Ele_channel:value()
  local az = 0
  if math.abs(elev) < 103 then                              -- take groundspeed only if the elevator is used less than 10%
    if sensor.gpsSpeed() then speed = sensor.gpsSpeed() end -- wait till gpsSpeed sensor is ready
    old_speed = speed
  end
                                                            -- I still follow up the idea that we fly on a radius r ~= |v| -> az ~= v
  az = elev * speed / 5120.0                                -- Then az shall be proportional to elevator-deflection * groundspeed
--  if az > 16.0 then                                         -- we can limit az to 16 here, because the logger3 limit seems to be 16
--    az = 16.0
--  end
  return az
end

function sensor.initializeSensor(data_table)                -- read the field infos for all sensors of the telemetry unit
  sensor.data = data_table
  for name in pairs(sensor.data) do
    local sensorName = sensor.data[name].name
    fieldInfo = system.getSource({category = CATEGORY_TELEMETRY_SENSOR, name = sensorName})
    print("<<"..name.." - "..sensorName..">> ", fieldInfo)
    if not fieldInfo then
      sensor.err = string.format("Sensor '%s' not found", sensorName)
      print(sensor.err)
      return false
    else
      sensor.data[name].id = fieldInfo                      -- store Source IDs of sensors into sensor.data table
    end
  end
  return true
end

function sensor.init(name)                                  -- setup the telemetry unit
  local result = false
  sensor.name = name
  if sensor.name == 'SM Modelbau Logger3' then
    result = sensor.initializeSensor(data.logger3)
  elseif sensor.name == 'FrSky GPS V2' then
    sensor.az = sensor.az_sim
    result = sensor.initializeSensor(data.gpsV2)
  elseif sensor.name == 'Any other GPS with Gyro' then
    result = sensor.initializeSensor(data.gps_with_gyro)
  end
--    sensor.name = 'test'                                    -- if nothing fits
--    result = sensor.initializeSensor(data.testUnit)
  return result
end

return sensor
