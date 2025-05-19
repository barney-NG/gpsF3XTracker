--[[#############################################################################
MAIN: GPS F3X Tracker for Ethos v1.3

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License               

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Change log:
- v1.1: - the course length considers new global variable global_course_dif, its value is taken from locations[widget.event_place].dif. It keeps value which modifies default course length
        - new global variable global_gps_gpsSats, its value is taken from sensors module and provides for SM-Modelbau GPS-Logger 3 sensor number of visible GPS satellites
        - correction in calculation of timestamp, procedure getETime()
- v1.2: - improved management of fonts
- v1.3: - some optimizations
################################################################################]]

-- GLOBAL VARIABLES (don't change)
global_gps_pos = {lat=0.,lon=0.}
global_Ele_channel = nil
global_gps_gpsSats = 0
-- global_home_dir = ...    -- defined in setup.lua
-- global_home_pos = ...    -- defined in setup.lua
-- global_comp_type = ...   -- defined in setup.lua
-- global_comp_types = ...  -- defined in setup.lua
-- global_baseA_left = ...  -- defined in setup.lua, true base A is on left side
-- global_gps_type = ...    -- defined in setup.lua, gives type of GPS sensor
-- global_gps_changed = ... -- defined in setup.lua, true if type of GPS sensor has changed
-- global_has_changed = ... -- defined in setup.lua, true if any event parameter has changed
-- global_F3B_locked = ...  -- defined in setup.lua, true when lockGPSHomeSwitch is pressed for "Live" Position & Direction case
-- global_course_dif = ...  -- defined in setup.lua, default course length is taken from the global_comp_types table, dif item in the locations table gives +- difference

-- VARIABLES
local on_simulator = false
local basePath = '/SCRIPTS/gpstrack/gpstrack/' 
local gpsOK = false
local debug = false
local first_run = true
local rate = 0
local course = nil
local sensor = nil
local screen = nil
local comp = nil
local gps = nil
local length = 0

function getETime()                                         -- timestamp in milliseconds for Ethos
  return math.floor(os.clock()*1000)                        -- os.clock needs to multiply by 1000 
end

function mydofile (filename)                                -- module load function
--  print ("filename: " .. filename)
  local f = assert(loadfile(filename))
  return f()
end

local function straight(x, ymin, ymax, b)                   -- simple linear extrapolation
  local offs = b or 0
  local result = math.floor((ymax - ymin) * x / 2048 + offs)
  return result
end

local function getPosition()                                -- debug: fake input (we use this function to emulate GPS input)
  local direction = math.rad(straight(debug_lat:value(),-45,45))
  local position = straight(debug_lon:value(),-60,60)
  if string.find(global_comp_type,"f3b") then
    position = position * 1.5
  end
  global_gps_pos = {lat = direction + math.rad(45.0), lon = position + 60.0}
--  local az = sensor.az()
  return position,direction   
end
-------------------------------------------------------------------------
-- create function
-------------------------------------------------------------------------
local function create()
  return {startSwitchId=nil, debug_lat=nil, debug_lon=nil}
end
-------------------------------------------------------------------------------------------------
-- get one full entry from supported competition types {name, default_mode, course_length, file}
-------------------------------------------------------------------------------------------------
local function getCompEntry(name)
  if type(global_comp_types == 'table') then
    for key,entry in pairs(global_comp_types) do
      if entry.name == name then
        return entry
      end
    end
  end
  return nil
end
-------------------------------------------------------------------------
-- moveHome function - for F3B the home position is base A, course library needs the home in the middle between the bases -> move home in direction of base B by half of course length
-------------------------------------------------------------------------
local function moveHome(half_length)
  if string.find(global_comp_type,"f3b") and (global_home_pos.lat ~= 0) and (global_home_pos.lon ~= 0) then   
    local new_position = gps.getDestination(global_home_pos, half_length, global_home_dir)
    print(string.format("F3B: moved home by %d meter from: %9.6f, %9.6f to: %9.6f, %9.6f",half_length, global_home_pos.lat, global_home_pos.lon, new_position.lat, new_position.lon))
    global_home_pos = new_position
  end
end 
-------------------------------------------------------
-- reloadCompetition function - load a new competition accordingly to new parameters
-------------------------------------------------------
local function reloadCompetition()
  if type(global_comp_types) == 'table' and global_has_changed == true then
    print("<<<< Reload Competition >>>>")
    local save_gpsOK = gpsOK
    global_has_changed = false      
    gpsOK = false                                           -- inactivate background process 
    
    local file_name = 'f3f.luac'                            -- set some useful default values (just in case ...)
    local mode = 'training'
    length = 50
    local entry = getCompEntry(global_comp_type)            -- get competition infomation
    if entry then
      file_name = entry.file                                -- overwrite the defaults with obtained competition infomation
      mode = entry.default_mode  
      length = (entry.course_length + global_course_dif) / 2          -- length is half of course length corrected by course difference taken from locations table
    end
    if comp == nil or comp.name ~= file_name then           -- no competition or different competition required
      if comp ~= nil then
        print("unload: " .. comp.name)
      end
      print("load: " .. file_name)
      comp = nil                                            -- remove old competition class
      collectgarbage("collect")                             -- cleanup memory
      comp = mydofile(basePath..file_name)                  -- load new competition (will crash if file does not exist!)
    end

    screen.resetStack()                                     -- empty the stack if needed
    comp.init(mode, global_baseA_left)                      -- initialize event values

    if save_gpsOK then                                      -- set ground height
      comp.groundHeight = sensor.gpsAlt() or 0.
    end

    course.init(length, math.rad(global_home_dir), comp)    -- reset course and update competition hooks

    if string.find(global_comp_type,"debug") then           -- any competition type with debug in the name is debugged
      debug = true
    else
      debug = false
    end
    gpsOK = save_gpsOK                                      -- enable background process
  end
end
-------------------------------------------------------------------------
-- startPressed function - checks if switch is activated, triggers on the edge
-------------------------------------------------------------------------
local pressed = false
local function startPressed(switch)
  if switch > 50 and not pressed then
    pressed = true
    return true
  end
  if pressed and switch < -50 then
    pressed = false
  end
  return false
end

local runs = 0
local loops = 0
local last_timestamp = 0
local last_loop = 0
-------------------------------------------------------------------------
-- wakeup (periodically called)
-------------------------------------------------------------------------
local function wakeup(widget)
  if first_run then
    screen.init(true)                                       -- initialize widget screen parameters with extra subscreen with stack
    
    if type(global_comp_types) == 'table' then              -- global variable "global_comp_types" is available
      print("<<< INITIAL RELOAD COMPETITION >>>")
      global_has_changed = true
      reloadCompetition()  
    else
      print("<<< SETUP MISSED >>>")                         -- if global variable "global_comp_types" is not available for some reason, we need some defaults for competition and course
      global_comp_type = 'f3f_trai'
      global_baseA_left = true
      global_home_dir = 9.0
      global_home_pos = { lat=53.550707, lon=9.923472 }
      comp = mydofile(basePath..'f3f.luac')
      comp.init('training', global_baseA_left)              -- initialize event values  
      course.init(10, math.rad(global_home_dir), comp)      -- setup course (debug)
    end
    
    sensor = mydofile(basePath..'sensors.luac')             -- load sensor library, it must be placed here as sensors are not ready when init() is running!
    gpsOK = sensor.init(global_gps_type)                    -- initialize configured GPS sensor
    first_run = false
  end
  
  if global_has_changed then                                -- event parameter(s) has changed -> load a new competition
    reloadCompetition()
  end
  
  if global_gps_changed then                                -- change in GPS sensor -> initialize a new sensor
    global_gps_pos = {lat=0.,lon=0.}
    gpsOK = sensor.init(global_gps_type)
    global_gps_changed = false
  end
  
  if global_F3B_locked then
    moveHome(length)                                        -- move home position for F3B events in direction of base B by half of course length when lockGPSHomeSwitch is pressed for "Live" Position & Direction case
    global_F3B_locked = false
  end  
  
  if debug then                                             -- debug without GPS sensor
    local dist2home,dir2home = getPosition()
    local groundSpeed = 10
    local gpsHeight = 99
    local acclZ = 0.1
--    global_home_dir = 9.0                                   -- do not change, value is taken from locations table
    course.direction = math.rad(global_home_dir)            -- in rad!
    course.update(dist2home, dir2home, groundSpeed, acclZ)  -- update course
    comp.update(gpsHeight)                                  -- update competition
  elseif gpsOK then
    global_gps_pos = sensor.gpsCoord()                      -- read gps position from sensor
    if global_gps_pos.lat and global_gps_pos.lon then
      local dist2home = gps.getDistance(global_home_pos, global_gps_pos)
      local dir2home = gps.getBearing(global_home_pos, global_gps_pos)
      local groundSpeed = sensor.gpsSpeed() or 0.
      local gpsHeight = sensor.gpsAlt() or 0.
      local acclZ = sensor.az() or 0.
      course.update(dist2home, dir2home, groundSpeed, acclZ) -- update course
      comp.update(gpsHeight)                                -- update competition
    else
      print("Main - waiting for GPS lat & lon infomation...")
    end
  end
  loops = loops+1
  if gpsOK or debug then
    if global_gps_pos.lat and global_gps_pos.lon then
      if loops % 2 == 0 then                                -- update screen every 2nd wakeup run ODLADIT NA OPTIMUM, TESTY NA X20 BEZ GPS UKAZUJI RATE cca 22 cyklu/s
        local time_stamp = getETime()                   -- PO ODLADENI ZRUSIT
        local time_diff = time_stamp - last_timestamp   -- PO ODLADENI ZRUSIT
        rate = 1/time_diff * 1000 * 2                   -- PO ODLADENI ZRUSIT
        last_timestamp = time_stamp                     -- PO ODLADENI ZRUSIT
        
        local start = startPressed(widget.startSwitchId:value())                -- check for start event
        if comp and start then
          if global_comp_type == 'f3b_dist' then
            if comp.state ~= 1 and comp.runs > 0 and runs ~= comp.runs then     -- comp finished by hand
              runs = comp.runs                              -- lock update 
              screen.addLaps(comp.runs, comp.lap - 1)       -- add a new lap number to the stack
            end
          end
          comp.start()                                      -- reset all values and start the competition
        end
        lcd.invalidate()
        global_gps_gpsSats = sensor.gpsSats()               -- get number of seen GPS satellites (valid only for SM-Modelbau GPS-Logger 3)
      end
    end
  end
end
-------------------------------------------------------------------------
-- paint function
-------------------------------------------------------------------------
local function paint(widget)
  local text  
  lcd.font(screen.font)
  
  if global_comp_type == "f3b_dist" then                    -- set screen title
    text = "F3B: Distance"
  elseif global_comp_type == "f3b_spee" then
    text = "F3B: Speed"
  else
    text = string.format("F3F %s", comp.mode)
  end
  if debug then
    text = text .. " (debug)"
  end
  
  local base = "base A: left"
  if not global_baseA_left then base = "base A: right" end
  text = text .. ", " .. string.format("%s", base)
  screen.title(text)
  screen.title("Runs", true)
  
  text = "Comp: " .. comp.message                           -- status message from comp module (f3f.lua, ...)
  if comp.state == 1 and comp.runs > 0 and runs ~= comp.runs then     -- add results from previous runs
    runs = comp.runs                                        -- lock update
    if global_comp_type == 'f3b_dist' then
      screen.addLaps(runs, comp.lap - 1)                    -- add a new lap number to the stack
    else
      screen.addTime(runs, comp.runtime)                    -- add a new lap number with its time to the stack
      text = text .. ", run: " .. string.format("%2d", runs+1)
    end
  end
  screen.showStack()                                        -- print the contents of the whole stack

  screen.text(1, text)                                      -- status message from comp module (f3f.lua, ...)
  screen.text(2, string.format("Runtime: %5.2fs",comp.runtime/1000.0))          -- general Info
  screen.text(3, "Course: " .. course.message)              -- course state
  screen.text(4, string.format("V: %6.2f m/s Dst: %-7.2f m ",course.lastGroundSpeed, course.lastDistance))    -- course information
  screen.text(5, string.format("H: %5.2fm           %5.1f calls/s",comp.groundHeight, rate))                -- PO ODLADENI ZRUSIT vypis rate
  if not gpsOK and not debug then
    if string.len(sensor.err) > 0 then                      -- sensor not defined/connected
      screen.text(6, "GPS: " .. sensor.err)
    else
      screen.text(6, "GPS sensor not found: " .. sensor.name)
    end
  else
    if global_gps_pos.lat and global_gps_pos.lon then
        screen.text(6, string.format("GPS: %9.6f, %9.6f",global_gps_pos.lat,global_gps_pos.lon))
    else
        screen.text(6, "GPS: waiting for lat & lon infomation...")
    end    
  end
end
-------------------------------------------------------------------------
-- configure function
-------------------------------------------------------------------------
local function configure(widget)
  line = form.addLine ("")											            -- Help Button field
  form.addButton (line, nil,
    { text="Help",    
      press=function()      
        form.openDialog({
          title="Configuration items", message="1) Start race switch: any 2-position switch, mandatory\n2) Elevator output channel: used for simulation of accelerometer, mandatory only when FrSky GPS is used\n3) Input debug GPS latitude and longitude: analog sources - used to emulate GPS input in debug mode, not mandatory",
          options=TEXT_LEFT,
          buttons={{label="OK", action=function() return true end}} })
      end
    })
  
	line = form.addLine ("Start race switch")	                -- Start race Switch field
	form.addSourceField (line, nil, function() return widget.startSwitchId end, function(value) widget.startSwitchId = value end)

  line = form.addLine("Elevator channel")                   -- Elevator channel Source field - used in sensor.az_sim() function, mandatory only if GPS Logger3 from SM Modelbau is not used
  form.addSourceField(line, form.getFieldSlots(line)[0], function() return global_Ele_channel end, function(value) global_Ele_channel = value end)
  
  line = form.addLine("Input debug GPS latitude")           -- GPS LATITUDE analog Source field - used in getPosition() function to emulate GPS input in debug mode
  form.addSourceField(line, form.getFieldSlots(line)[0], function() return debug_lat end, function(value) debug_lat = value end) 
 
  line = form.addLine("Input debug GPS longitude")          -- GPS LONGITUDE analog Source field - used in getPosition() function to emulate GPS input in debug mode
  form.addSourceField(line, form.getFieldSlots(line)[0], function() return debug_lon end, function(value) debug_lon = value end)
end

local function read(widget)
  widget.startSwitchId = storage.read("startSwitchId")
  global_Ele_channel = storage.read("global_Ele_channel")
  debug_lat = storage.read("debug_lat")
  debug_lon = storage.read("debug_lon")
end

local function write(widget)
  storage.write("startSwitchId", widget.startSwitchId)
  storage.write("global_Ele_channel", global_Ele_channel)
  storage.write("debug_lat", debug_lat)
  storage.write("debug_lon", debug_lon)
end
-------------------------------------------------------------------------
-- init function
-------------------------------------------------------------------------
local function init()
  print("<<< INIT MAIN >>>")
  system.registerWidget({key="Gpstrck", name="GPS F3X Tracker", create=create, paint=paint, configure=configure, wakeup=wakeup, read=read, write=write})

  local System_ver = system.getVersion()                    -- are we on simulator?
  if System_ver.simulation then
--    print("Simulator detectded")
    on_simulator = true
    if io.open(basePath..'gpslib.lua', "r") ~= nil then     -- if source file(s) is available, compile all libraries, excluding locations.lua
      system.compile(basePath..'gpslib.lua')
      system.compile(basePath..'screen.lua')
      system.compile(basePath..'course.lua')
      system.compile(basePath..'sensors.lua')
      system.compile(basePath..'f3f.lua')
      system.compile(basePath..'f3bdist.lua')
      system.compile(basePath..'f3bsped.lua')
    end  
  end

  gps = mydofile(basePath..'gpslib.luac')                    -- load gps library
  screen = mydofile(basePath..'screen.luac')                 -- load screen library
  course = mydofile(basePath..'course.luac')                 -- load course library
end

return {init=init}