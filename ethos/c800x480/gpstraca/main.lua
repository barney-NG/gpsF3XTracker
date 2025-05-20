--[[#############################################################################
SETUP: GPS F3X Tracker for Ethos v1.3

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

PARAMETERS:
event location:    list is in the locations.locations table, extracted by function loc2cb into table "locations_choice"
course direction:  0 - 360 cardinal direction
competition type:  list is in the choice_table
base A:            left / right
gps sensor:        list is in the table "gps_sensors"

Change log:
- v1.1: - new global variable global_course_dif, its value is taken from locations[widget.event_place].dif when widget.event_place changes. It keeps value which modifies default course length
        - when widget.event_place changes to "Live Position & Direction" set the comptype to "f3f_training"
        - for SM-Modelbau GPS-Logger 3 sensor display number of visible GPS satellites
- v1.2: - improved management of fonts
- v1.3: - created function for editing location table in the locations.lua
        - paint() enhanced by line showing widget.coursedif
################################################################################]]

-- LOCAL VARIABLES
local basePath = '/SCRIPTS/gpstrack/gpstrack/'
local first_run = true
local levent_place = 0
local lat = 0.0
local lon = 0.0
local locations = {}
local screen = nil
local len = 0
local lname = ""
local lcoursedir = 0
local lcoursedif = 0
local lcomptype = 1
local latitude = 0.0
local longitude = 0.0
local locations_choice = {{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}}
local choice_table = {{"f3f_training", 1}, {"f3f_competition", 2}, {"f3b_distance", 3}, {"f3b_speed", 4}, {"f3f_debug", 5}}
local gps_sensors = {{"SM Modelbau Logger3", 1}, {"FrSky GPS V2", 2}, {"Any other GPS with Gyro", 3}}

-- GLOBAL VARIABLES
-- global_gps_pos = ...                                     -- defined in the main main.lua
-- global_gps_gpsSats = ...                                 -- defined in the main main.lua
global_home_dir = 0.0                                       -- placeholder
global_home_pos = {lat=0.,lon=0.}                           -- placeholder
global_baseA_left = true                                    -- default place of base A is on left side
global_has_changed = false                                  -- indicator of change in any event parameter
global_comp_type = 'f3f_trai'                               -- default
global_comp_types = {
    {name='f3f_trai', default_mode='training', course_length=100, file='f3f.luac' },
    {name='f3f', default_mode='competition', course_length=100, file='f3f.luac' },
    {name='f3b_dist', default_mode='competition', course_length=150, file='f3bdist.luac' },
    {name='f3b_sped', default_mode='competition', course_length=150, file='f3bsped.luac' },
    {name='f3f_debug', default_mode='training', course_length=30, file='f3f.luac' }
}
global_course_dif = 0                                       -- default course length is taken from the global_comp_types table, dif item in the locations table gives +- difference
global_gps_type = 'SM Modelbau Logger3'                     -- default type of GPS sensor
global_gps_changed = false                                  -- indicator of change in type of GPS sensor
global_F3B_locked = false                                   -- when lockGPSHomeSwitch is pressed for "Live" Position & Direction case

function mydofile (filename)                                -- module load function
--  print ("Setup filename: " .. filename)
  local f = assert(loadfile(filename))
  return f()
end

local function loc2cb(loc)                                  -- extracts information from loc table to locations_choice table
  len = 1
  for i,v in ipairs(loc) do
    if v['name'] ~= "Last Entry" then
      locations_choice[i][1] = v['name'] 
      locations_choice[i][2] = i
      len = len + 1 
    end  
  end
--  print ("Setup - loc2cb - len: ", len)
end
-------------------------------------------------------------------------
-- switchPressed function - checks if switch is activated
-------------------------------------------------------------------------
local pressed = false
local function switchPressed(switch)
  if switch > 50 then
    if not pressed then
      pressed = true; screen.cleaned = false
      if levent_place == 1 then
        global_F3B_locked = true                            -- force moving of home position when lockGPSHomeSwitch is pressed for "Live" Position & Direction case
      end  
    end  
    return true
  end
  if switch < -50 then
    if pressed then
      pressed = false; screen.cleaned = false
      global_F3B_locked = false
    end  
  end
  return false
end
-------------------------------------------------------------------------
-- create function
-------------------------------------------------------------------------
local function create()
  return {event_place=1, coursedir=0, comptype=1, coursedif=0, baseA_left=true, gps_type=1, gps_gpsSats = -1, lockGPSHomeSwitch=nil}
end
-------------------------------------------------------------------------
-- wakeup function
-------------------------------------------------------------------------
local function wakeup(widget)
  if first_run then                                         -- initialize widget screen parameters
    screen.init()

    global_home_dir = widget.coursedir/10                   -- make values global
    global_home_pos.lat = lat
    global_home_pos.lon = lon
    global_baseA_left = widget.baseA_left
    global_comp_type = global_comp_types[widget.comptype]['name']
    global_course_dif = widget.coursedif
    first_run = false
  end

  if widget.event_place == 1 then                           -- for "Live" Position & Direction case
    if not switchPressed(widget.lockGPSHomeSwitch:value()) then   -- update only when the lock GPS Home switch is not activated, otherwise keep last home coordinates                                  
      if global_gps_pos.lat and global_gps_pos.lon then     -- home position from actual GPS values
        local newLat = global_gps_pos.lat
        local newLon = global_gps_pos.lon
        if newLat ~= lat or newLon ~= lon then
          lat = newLat
          lon = newLon
        end
      else
        lat = 0.0; lon = 0.0
          print("GPS Position: waiting for signal...")
      end
    end  
  end
  
  if levent_place ~= widget.event_place then                                    -- competition place has changed
    print ("Setup - widget.event_place changed", levent_place, widget.event_place)
    levent_place = widget.event_place
    lname = locations[widget.event_place].name
    if levent_place == 1 and string.find(global_comp_type,"f3b") then           -- change is to the "Live" Position & Direction and current comp type is F3B
      global_home_pos = {lat=lat,lon=lon}
    end
    
    if widget.event_place ~= 1 then                         -- update values from locations.locations table
--      print("Setup - update values from locations.locations table")
      widget.comptype = locations[widget.event_place].comp
      lat = locations[widget.event_place].lat; global_home_pos.lat = lat
      lon = locations[widget.event_place].lon; global_home_pos.lon = lon
      if string.find(global_comp_type,"f3b") then
        global_F3B_locked = true                            -- force moving of home position for F3B preconfigured sites
      end  
    end
    print("Setup - update values from locations.locations table")
    widget.coursedif = locations[widget.event_place].dif    -- difference in course length, +: course is longer, -: course is shorter
    widget.coursedir = locations[widget.event_place].dir*10 -- widget.coursedir is stored in one decimal position format
    screen.cleaned = false; global_has_changed = true
  end
                                                                                -- check if configuration parameters have changed, make them global and redraw widget
  if global_home_dir ~= widget.coursedir/10 then                                -- competition course has changed 
    print ("Setup - widget.coursedir/10 changed", global_home_dir, widget.coursedir/10)
    global_home_dir = widget.coursedir/10
    screen.cleaned = false; global_has_changed = true
  end
  if global_course_dif ~= widget.coursedif then                                 -- competition course length has changed
    print ("Setup - widget.coursedif changed", global_course_dif, widget.coursedif)
    global_course_dif = widget.coursedif
    screen.cleaned = false; global_has_changed = true
  end
  if global_home_pos.lat ~= lat then                                            -- GPS latitude has changed
    if not string.find(global_comp_type,"f3b") or global_home_pos.lat == 0 then
      print ("Setup - lat changed", global_home_pos.lat, lat)
      global_home_pos.lat = lat
      screen.cleaned = false
    end  
  end
  if global_home_pos.lon ~= lon then                                            -- GPS longitude has changed
    if not string.find(global_comp_type,"f3b") or global_home_pos.lon == 0 then
      print ("Setup - lon changed", global_home_pos.lon, lon)
      global_home_pos.lon = lon
      screen.cleaned = false
    end        
  end    
  if global_baseA_left ~= widget.baseA_left then                                -- base A has moved
    if (widget.comptype == 3 or widget.comptype == 4) then                      -- for F3B events set to true = always on left
      widget.baseA_left = true
    end
    global_baseA_left = widget.baseA_left
    screen.cleaned = false; global_has_changed = true
  end    
  if global_comp_type ~= global_comp_types[widget.comptype]['name'] then        -- competition type has changed
    print ("Setup - widget.comptype changed", global_comp_type, global_comp_types[widget.comptype]['name'])
    global_comp_type = global_comp_types[widget.comptype]['name']
    if (widget.comptype == 3 or widget.comptype == 4) then                      -- for F3B events set to true = always on left
      widget.baseA_left = true
    end  
    screen.cleaned = false; global_has_changed = true
  end
  if global_gps_type ~= gps_sensors[widget.gps_type][1] then                    -- type of GPS sensor has changed
    print ("Setup - widget.gps_type changed", global_gps_type, gps_sensors[widget.gps_type][1])
    global_gps_type = gps_sensors[widget.gps_type][1]
    if widget.event_place == 1 then lat = 0.0; lon = 0.0 end
    global_gps_changed = true
    screen.cleaned = false
  end
  if global_gps_gpsSats ~= widget.gps_gpsSats then          -- number of visible GPS satellites has changed
    print ("Setup - global_gps_gpsSats changed", widget.gps_gpsSats, global_gps_gpsSats)
    widget.gps_gpsSats = global_gps_gpsSats
    screen.cleaned = false
  end  

  if not screen.cleaned then                                -- refresh widget
    screen.cleaned = true
    if widget.event_place ~= 1 then global_has_changed = true end     -- do not set "global_has_changed" for "Live" Position & Direction, otherwise it causes permanent reloadCompetition
    lcd.invalidate()       
  end
end
-------------------------------------------------------------------------
-- paint function
-------------------------------------------------------------------------
local function paint(widget)
  lcd.font(screen.font);
  screen.title("Parameter Setup")
  screen.text(1, string.format("Event place: %s", locations_choice[widget.event_place][1]))
  if lat == 0.0 and lon == 0.0 then
    screen.text(2, "GPS Home: waiting for signal...")
  else
    if widget.lockGPSHomeSwitch:value() > 50 and widget.event_place == 1 then   -- for "Live" Position & Direction show when GPS Home coordinates are locked by lockGPSHomeSwitch
      screen.text(2, string.format("GPS Home lck: %9.6f, %9.6f", lat,lon))
    else
      screen.text(2, string.format("GPS Home: %9.6f, %9.6f", lat,lon))
    end  
  end
  screen.text(3, string.format("Course Direction: %5.1f°", widget.coursedir/10)) -- widget.coursedir is stored in one decimal position format
  screen.text(4, string.format("Course Difference: %2dm", widget.coursedif))
  screen.text(5, string.format("Competition Type: %s", choice_table[widget.comptype][1]))
  if widget.baseA_left then
    screen.text(6, "Course Base: left")
  else
    screen.text(6, "Course Base: right")
  end
  screen.text(7, string.format("GPS sensor: %s", gps_sensors[widget.gps_type][1]))
  if widget.gps_type == 1 then                              -- display number of visible GPS satellites only for SM-Modelbau GPS-Logger 3
    screen.text(8, string.format("GPS satellites: %s", global_gps_gpsSats))
  end  
end
-------------------------------------------------------------------------
-- Edit function
-------------------------------------------------------------------------
local function Edit(widget)
  local NFieldE, DFieldE, LatFieldE, LonFieldE
  form.clear()
  lname = locations[widget.event_place].name
  latitude = math.floor(lat * 1000000)                      -- 6 decimal places is supported in configuration below
  longitude = math.floor(lon * 1000000)
  lcoursedir = widget.coursedir
  lcoursedif = widget.coursedif
  lcomptype = widget.comptype
  
  local line = form.addLine("Event place")                  -- Name of Event place
  form.addTextField(line, nil, function() return lname end, function(newValue) lname = newValue end)
  
  line = form.addLine("Latitude")                           -- Latitude
  LatFieldE = form.addNumberField(line, nil, -90000000, 90000000, function() return latitude end, function(value) latitude = value end)
  LatFieldE:decimals(6); LatFieldE:step(1); LatFieldE:suffix("°")
    
  line = form.addLine ("Longitude")                         -- Longitude
  LonFieldE = form.addNumberField(line, nil, -180000000, 180000000, function() return longitude end, function(value) longitude = value end)
  LonFieldE:decimals(6); LonFieldE:step(1); LonFieldE:suffix("°")

  line = form.addLine("Course direction")                   -- Course direction
  NFieldE = form.addNumberField(line, nil, 0, 3599, function() return lcoursedir end, function(value) lcoursedir = value end)
  NFieldE:suffix("°"); NFieldE:decimals(1); NFieldE:step(1)

  line = form.addLine("Course difference")                  -- Difference
  DFieldE= form.addNumberField(line, nil, -50, 50, function() return lcoursedif end, function(value) lcoursedif = value end)
  DFieldE:step(1); DFieldE:suffix("m")
    
  line = form.addLine ("Competition type")                  -- Competition type
  form.addChoiceField(line, nil, choice_table, function() return lcomptype end, function(value) lcomptype = value end)
    
  line = form.addLine ("")											            -- Save Button field
  form.addButton(line, nil, 
    { text="Save",    
      press=function()
        if not (widget.event_place == 1 and len == 16) then -- No new site can be created, the list is full
          local file_source = io.open (basePath..'locations.lua',"r")   -- open locations.lua file and temporary file
          local file_target = io.open (basePath..'locations_t.lua',"w")
          repeat                                            -- copy all rows till beginning of locations table
            local row = file_source:read("*l")
            file_target:write(row,"\n")
          until row == "local locations = {"
        
          if widget.event_place == 1 then                   -- we create a new site from "Live Position & Direction" site
            for i=1, len-1 do                               -- copy all sites till the placeholder
              row = file_source:read("*l")
              file_target:write(row,"\n")
            end
            file_target:write("    {name = ".."\""..lname.."\""..", lat = "..string.format("%9.6f",latitude/1000000)..", lon = "..string.format("%9.6f",longitude/1000000)..", dir = "..string.format("%5.1f",lcoursedir/10)..", dif = "..lcoursedif..", comp = "..lcomptype.."},\n")
          else                                              -- we modify some other site
            for i=1, widget.event_place-1 do                -- copy all sites till the one we are modifying
              row = file_source:read("*l")
              file_target:write(row,"\n")
            end
            row = file_source:read("*l")                    -- read the site we are modifying

            file_target:write("    {name = ".."\""..lname.."\""..", lat = "..string.format("%9.6f",latitude/1000000)..", lon = "..string.format("%9.6f",longitude/1000000)..", dir = "..string.format("%5.1f",lcoursedir/10)..", dif = "..lcoursedif..", comp = "..lcomptype.."},\n")
          end

          repeat                                            -- copy rest of file
            row = file_source:read("*l")
            if row then file_target:write(row,"\n") end
          until not row
          io.close(file_source); io.close(file_target)      -- close both files and replace the original locations.lua file with the new one
          os.remove(basePath..'locations.lua'); os.rename(basePath..'locations_t.lua', basePath..'locations.lua')
          locations = mydofile(basePath..'locations.lua')   -- reload locations table module
          loc2cb(locations)                                 -- refresh information from locations.locations table to locations_choice table
          levent_place = 0                                  -- force full update from locations table
          form.openDialog({buttons={{label="Saved", action=function() return true end}} })
        else
          form.openDialog({buttons={{label="List of sites is full!", action=function() return true end}} })
        end
      end
    })
end
-------------------------------------------------------------------------
-- configure function
-------------------------------------------------------------------------
local function configure(widget)
  local CField, BField, NField, DField
  local line = form.addLine ("")											      -- Help Button field
  form.addButton (line, nil,
    { text="Help",    
      press=function()      
        form.openDialog({
          title="Configuration items", message="1) Event place: any item from list of places in locations.lua\n2) Course direction: course bearing from base left to base right*\n3) Course difference: change of standard course length*\n4) Competition type: any type from supported types*\n5) Base A is on left: true if it is so**\n6) Lock GPS Home position switch: any 2-position switch, mandatory\n* available only for 'Live Position & Direction' event\n** available only for F3F events, for F3B is Base A always on left",
          options=TEXT_LEFT,
          buttons={{label="OK", action=function() return true end}} })
      end
    })
  
  line = form.addLine ("Event place")                       -- Event place
	form.addChoiceField(line, nil, locations_choice, function() return widget.event_place end, function(value) widget.event_place = value
  if value == 1 then widget.comptype = 1 end                -- when we go to "Live Position & Direction" set the comptype to "f3f_training"
  NField:enable(widget.event_place == 1)                    -- set availability of the configuration field NField when event is "Live Position & Direction"
  CField:enable(widget.event_place == 1)                    -- set availability of the configuration field CField when event is "Live Position & Direction"
  DField:enable(widget.event_place == 1)                    -- set availability of the configuration field DField when event is "Live Position & Direction"
  end)

  line = form.addLine("Course direction")                   -- Course direction
  NField = form.addNumberField(line, nil, 0, 3599, function() return widget.coursedir end, function(value) widget.coursedir = value end)
	NField:suffix("°"); NField:decimals(1); NField:step(1)
  NField:enable(widget.event_place == 1)                    -- set initial availability of the configuration field NField when event is "Live Position & Direction"
  
  line = form.addLine("Course difference")                  -- Difference
  DField= form.addNumberField(line, nil, -50, 50, function() return widget.coursedif end, function(value) widget.coursedif = value end)
  DField:step(1); DField:suffix("m")
  DField:enable(widget.event_place == 1)                    -- set initial availability of the configuration field DField when event is "Live Position & Direction"
  
	line = form.addLine ("Competition type")                  -- Competition type
	CField = form.addChoiceField(line, nil, choice_table, function() return widget.comptype end, function(value) widget.comptype = value end)
  CField:enable(widget.event_place == 1)                    -- set initial availability of the configuration field NField when event is "Live Position & Direction"

  line = form.addLine("Base A is on left")                  -- Base A is on left
  form.addBooleanField(line, nil, function() return widget.baseA_left end, function(value) widget.baseA_left = value end)
  
  line = form.addLine("GPS sensor")                         -- GPS sensor
  form.addChoiceField(line, nil, gps_sensors, function() return widget.gps_type end, function(value) widget.gps_type = value end)
  
	line = form.addLine ("Lock GPS Home position switch")     -- Lock GPS Home position Switch
	form.addSourceField (line, nil, function() return widget.lockGPSHomeSwitch end, function(value) widget.lockGPSHomeSwitch = value end)
  
  line = form.addLine ("")											            -- Edit Button field
  form.addButton(line, nil, 
    { text="Edit event place",    
      press=function() Edit(widget) end
    })
end

local function read(widget)
  widget.event_place = storage.read("event_place")
--[[  widget.coursedir = storage.read("coursedir")
  widget.coursedif = storage.read("coursedif")
  widget.comptype = storage.read("comptype") ]]
  widget.baseA_left = storage.read("baseA_left")
  widget.gps_type = storage.read("gps_type")
  widget.lockGPSHomeSwitch = storage.read("gps_lock")
end

local function write(widget)
  storage.write("event_place", widget.event_place)
--[[  storage.write("coursedir", widget.coursedir)
  storage.write("coursedif", widget.coursedif)
  storage.write("comptype", widget.comptype) ]]
  storage.write("baseA_left", widget.baseA_left)
  storage.write("gps_type", widget.gps_type)
  storage.write("gps_lock", widget.lockGPSHomeSwitch)  
end
-------------------------------------------------------------------------
-- init function
-------------------------------------------------------------------------
local function init()
    print("<<< INIT SETUP >>>")
    system.registerWidget({key="Gpstset", name="GPS F3X Tracker Setup", create=create, paint=paint, configure=configure, wakeup=wakeup, read=read, write=write})

    locations = mydofile(basePath..'locations.lua')         -- load locations table module 
    screen = mydofile(basePath..'screen.luac')              -- load screen module

    loc2cb(locations)                                       -- extract information from locations.locations table to locations_choice table
end

return {init=init}