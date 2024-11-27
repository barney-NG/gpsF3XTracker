--[[#############################################################################
Copyright (c) 2024 Axel Barnitzke                                     MIT License

MAIN:

functions: ---------------------------------------------------------------------

################################################################################]]
-- VARIABLES
local global = {
    comp_types = {
        {name='f3f_trai', default_mode='training', course_length=100, file='f3f.lua' },
        {name='f3f', default_mode='competition', course_length=100, file='f3f.lua' },
        {name='f3b_dist', default_mode='competition', course_length=150, file='f3bdist.lua' },
        {name='f3b_spee', default_mode='competition', course_length=150, file='f3bsped.lua' },
        {name='f3f_debug', default_mode='training', course_length=10, file='f3f.lua' },
    },
    active_location = 1,
    active_comp = 1,
    comp_type = 'f3f_trai',
    baseA_left = true,
    gps_pos = {lat=0.,lon=0.},
    home_dir = 0.0,
    home_pos = {lat=0.,lon=0.},
    has_changed = true,
}

-- VARIABLES (internal)
local basePath = '/scripts/gps4f3x/gpstrack/' 

-- WIDGETS
local course = nil
local sensor = nil
local screen = nil
local comp = nil
local gps = nil
local locations = nil

-----------------------------------------------------------------------
-- apply a useful default (from Alessandro Apostoli)
-----------------------------------------------------------------------
local function applyDefault(value, defaultValue, lookup)
    local v = value ~= nil and value or defaultValue
    if lookup ~= nil then
      return lookup[v]
    end
    return v
  end
-----------------------------------------------------------------------
-- read configuration (from Alessandro Apostoli)
-----------------------------------------------------------------------  
  local function storageToConfig(name, defaultValue, lookup)
    local storageValue = storage.read(name)
    local value = applyDefault(storageValue, defaultValue, lookup)
    return value
  end
-----------------------------------------------------------------------
-- simple linear extrapolation
-----------------------------------------------------------------------
local function straight(x, ymin, ymax, b)
    local offs = b or 0
    local result = math.floor((ymax - ymin) * x / 2048) + offs
    return result
end
-----------------------------------------------------------------------
-- emulate otx/etx getTime function
-----------------------------------------------------------------------
local function getTime()
    -- os.clock() resolution is 0.01 secs
    return os.clock()
end
-----------------------------------------------------------------------
-- translate competitions to combobox entries
-----------------------------------------------------------------------
local function comp2cb(w)
    local cb = {}
    local len = 0
    for i,v in ipairs(global.comp_types) do
        cb[i] = { v['name'], i }
        len = len + 1
    end    
    return cb,len
end
-----------------------------------------------------------------------
-- translate locations to combobox entries
-----------------------------------------------------------------------
local function loc2cb( w )
    local cb = {}
    local len = 0
    for i,v in ipairs(locations) do
        cb[i] = { string.format("%d: %s",i,v['name']), i }
        len = len + 1
    end    
    return cb,len
end
-------------------------------------------------------------------------------------------------
-- get one full entry from supported competition types {name, default_mode, course_length, file}
-------------------------------------------------------------------------------------------------
local function getCompEntry(name)
    if type(global.comp_types == 'table') then
        for key,entry in pairs(global.comp_types) do
            if entry.name == name then
                return entry
            end
        end
    end
    return nil
end
-----------------------------------------------------------------------
-- load a new competition type
-----------------------------------------------------------------------
local function reloadCompetition(w)
    -- reload competition accordingly to new parameters
    if type(global.comp_types) == 'table' and global.has_changed == true then
        print("<<<< (RE)LOAD COMPETITION >>>>")
        local save_gpsOK = w.gpsOK
        global.has_changed = false
        
        -- inactivate background process
        w.gpsOK = false 
    
        -- set some useful default values (just in case ...)
        local file_name = 'f3f.lua'
        local mode = 'training'
        local length = 50
        -- get competition
        local entry = getCompEntry(global.comp_type)
        if entry then
            -- overwrite the defaults
            file_name = entry.file
            mode = entry.default_mode
            length = entry.course_length / 2
        end
        if comp == nil or comp.name ~= file_name then
            -- empty or different competition required
            if comp ~= nil then
                print("unload: " .. comp.name)
            end
            print("load: " .. file_name)
            -- remove old competition class
            comp = nil
            -- cleanup memory
            collectgarbage("collect")
            -- load new competition (will crash if file does not exist!)
            comp = dofile(basePath..file_name)
        end
        -- reset competition
        comp.init(mode, global.baseA_left)
        -- set ground height
        if save_gpsOK then
            comp.groundHeight = sensor.gpsAlt() or 0.
        end
        -- reset course and update competition hooks
        course.init(length, math.rad(global.home_dir), comp)
        -- for F3B the home position is base A always. The course library needs the home in the middle between the bases. -> move home in direction of base B
        if string.find(global.comp_type,"f3b") then
            local new_position = gps.getDestination(global.home_pos, length, global.home_dir)
            print(string.format("F3B: moved home by %d meter from: %9.6f, %9.6f to: %9.6f, %9.6f",length, global.home_pos.lat, global.home_pos.lon, new_position.lat, new_position.lon))
            global.home_pos = new_position
        end
        -- any competition type with debug in the name is debugged
        if string.find(global.comp_type,"debug") then
            w.debug = true
        else
            w.debug = false
        end
        -- enable 
        w.gpsOK = save_gpsOK
    end

end
-----------------------------------------------------------------------
-- The create handler function is called on widget creation. 
-- It takes no arguments and will return the widget table which is then 
-- later passed to all functions. 
-- Initialize your variables here and store the state in the returned widget table.
-----------------------------------------------------------------------
local function create()
    print("<<< CREATE >>>")
    w = {
        on_simulator = false,
        debug = false,
        color=lcd.RGB(0, 0, 255),
        gpsOK = false,
        home_line = nil,
        setup = {
            home_pos = {lat=0., lon=0.},
            home_dir = 0,
            baseA_left = true,
            active_comp = 1,
            active_location = 1,
            comp_type = 'f3f_trai',
        },
    }
    -- check for simulator
    if system.getVersion().simulation then
	    w.on_simulator = true
    end
    -- load widgets
    gps = dofile(basePath..'gpslib.lua')
    locations = dofile(basePath..'locations.lua')
    screen = dofile(basePath..'screen.lua')
    sensor = dofile(basePath..'sensors.lua')
    course = dofile(basePath..'course.lua')
     -- init sensors
     w.gpsOK = sensor.init('logger3')

    return w
end
-----------------------------------------------------------------------
-- The configure handler function is called when the user enters widget 
-- configuration. It takes the widget table returned by create() as its 
-- only argument and returns nothing. 
-- It is called when the user enters the widget configuration. Here you 
-- can create the configuration form and use it to change values in the 
-- widget table
-----------------------------------------------------------------------
local function configure(widget)
    local f
    print("<<< CONFIGURE >>>")
    w.setup.home_dir = global.home_dir
    w.setup.home_pos = global.home_pos
    w.setup.comp_type = global.comp_type
    w.setup.active_comp = global.active_comp
    w.setup.active_location = global.active_location

    -------------------------------------------------------------------
    -- location
    -------------------------------------------------------------------
    local loc_list,len = loc2cb(widget)
    local line = form.addLine("Location")
    form.addChoiceField(line, nil, loc_list, function() return w.setup.active_location end, 
    function(newValue)
        print("new: " .. newValue) 
        w.setup.active_location = newValue
        if newValue == 1 then
            if w.home_line then
                local text = "waiting for GPS Data"
                if w.gpsOK then
                    w.setup.home_pos = global.gps_pos
                    text = string.format("%9.6f,%9.6f  ",w.setup.home_pos.lat,w.setup.home_pos.lon)
                end
                form.addStaticText(w.home_line, nil, text)
            end
        else
            local loc = locations[newValue]
            w.setup.home_dir = loc.dir
            w.setup.home_pos = {lat=loc.lat, lon=loc.lon}
            w.setup.comp_type = global.comp_types[loc.comp].name
            w.setup.active_comp = loc.comp
            w.setup.has_changed = true
            
            local text = string.format("%9.6f,%9.6f",w.setup.home_pos.lat,w.setup.home_pos.lon)
            print(text)
            form.addStaticText(w.home_line, nil, text)
        end
    end)
    -------------------------------------------------------------------
    -- direction
    -------------------------------------------------------------------
    line = form.addLine("Course Direction")

    f = form.addNumberField(line, nil, 0, 359, function() return w.setup.home_dir end, 
    function(newValue)
        w.setup.has_changed = true
        if w.setup.active_location == 1 then 
            w.setup.home_dir = newValue
        else
            w.setup.home_dir = locations[w.setup.active_location].dir
        end 
    end)
    f:suffix("°")
    f:default(w.setup.home_dir)
    f:step(1)
    -------------------------------------------------------------------
    -- home position
    -------------------------------------------------------------------
    line = form.addLine("Home Position")
    local text = "Waiting for GPS Data"
    print("active location: " .. global.active_location)
    if global.active_location == 1 then
        if w.gpsOK then
            w.setup.home_pos = global.gps_pos
            text = string.format("%9.6f,%9.6f",w.setup.home_pos.lat,w.setup.home_pos.lon)
            w.setup.has_changed = true
        end
    else
        w.setup.home_pos.lat = locations[global.active_location].lat or 0.
        w.setup.home_pos.lon = locations[global.active_location].lon or 0.
        text = string.format("%9.6f,%9.6f  ",w.setup.home_pos.lat,w.setup.home_pos.lon)
        w.setup.has_changed = true
    end
    print(text)
    w.home_line = line
    form.addStaticText(line, nil, text,1)
    
    -------------------------------------------------------------------
    -- competition type
    -------------------------------------------------------------------
    local comp_list,len = comp2cb(widget)
    local line = form.addLine("Competition Type")
    form.addChoiceField(line, nil, comp_list, function() return w.setup.active_comp end, 
    function(newValue)
        print("new_comp: " .. newValue) 
        w.setup.active_comp = newValue
        w.setup.has_changed = true
    end)
    -------------------------------------------------------------------
    -- base A left
    -------------------------------------------------------------------
    local line = form.addLine("Base A is left")
    form.addBooleanField(line, nil, function() return w.setup.baseA_left end, 
    function(newValue) 
        w.setup.baseA_left = newValue
    end)
    -------------------------------------------------------------------
    -- activate values
    -------------------------------------------------------------------
    line = form.addLine("Use new values")
    form.addTextButton(line, nil, "Activate", 
    function()
        if w.setup.has_changed then
            w.setup.has_changed = false
            global.baseA_left = w.setup.baseA_left
            global.home_pos = w.setup.home_pos
            global.active_location = w.setup.active_location
            global.active_comp = w.setup.active_comp
            global.comp_type = w.setup.comp_type
            global.has_changed = true 
            reloadCompetition(widget)
            form.invalidate()
            return true
        end
    end)
    --]]
end
-----------------------------------------------------------------------
-- The wakeup handler function is called during each loop, (every 50ms). 
-- It takes the widget table as its only argument and returns nothing.
-- 
-- The wakeup() should check if anything has changed. If yes, a refresh 
-- is needed so the invalidateWindow() function should be called. 
-- This will cause the paint() function to be called. 
-- You should make sure this function is very fast, ideally doing 
-- nothing most of the time
-----------------------------------------------------------------------
local function wakeup(widget)
    local now = getTime()
end
-----------------------------------------------------------------------
-- The event handler function called when an event is received. 
-- ETHOS provides the ability to catch any event in a widget, through 
-- this event function.
-----------------------------------------------------------------------
local function event(widget, category, value, x, y)
    print("Event received:", category, value, x, y, KEY_EXIT_BREAK)
    return false
    -- TODO: when true, when false?
end
-----------------------------------------------------------------------
-- The paint function ‘draws’ the widget. It takes the widget table as 
-- its only argument and returns nothing. It should be called when a 
-- refresh is needed, and is automatically called whenever 
-- lcd.invalidate() has been called. It can be slow, so only paint if 
-- something has changed
-----------------------------------------------------------------------
local function paint(widget)
    local w, h = lcd.getWindowSize()
    lcd.drawLine(0, h/2, w, h/2)
    lcd.color(widget.color)
    for i = 0,w do
      local val = math.sin(i*math.pi/(w/2))
      lcd.drawPoint(i, val*h/2+h/2)
    end
end
-----------------------------------------------------------
-- debug
-- board (string) board name, i.e. "X20S"
-- version (string) version
-- major (number) version major (i.e. 1 if version is "1.2.0-RC1")
-- minor (number) version minor (i.e. 2 if version is "1.2.0-RC1")
-- revision (number) version revision (i.e. 0 if version is "1.2.0-RC1")
-- suffix (string) version suffix (i.e. "RC1" if version is "1.2.0-RC1")
-- lcdWidth (number) LCD Width
-- lcdHeight (number) LCD Height
-- simulation (boolean)
-- serial (string)
-----------------------------------------------------------
local function vers()
    local t = system.getVersion()
    for k,v in pairs(t) do
        print(k,v)
    end
  end
-----------------------------------------------------------------------
-- local function read(widget)
-- Optional read handler. In ETHOS it is possible to use the storage 
-- as the user wishes.
-----------------------------------------------------------------------
local function read ( widget )
    print("<<< READ >>>")
    global.home_pos.lat = storageToConfig("globalHomePosLat", 0.0)
    global.home_pos.lon = storageToConfig("globalHomePosLon", 0.0)
    global.home_dir = storageToConfig("globalHomeDir", 0)
    global.comp_type = storageToConfig("globalCompType", 'f3f_trai')
    global.baseA_left = storageToConfig("globalBaseALeft", true)
    global.active_location = storageToConfig("globalActiveLocation", 1)
    global.active_comp = storageToConfig("globalActiveCompetition", 1)
    --widget.setup.active_location = storageToConfig("widgetActiveLocation", 1)
    -- load last valid competition without new configuration
    reloadCompetition( widget )
end
-----------------------------------------------------------------------
-- local function write(widget)
-- Optional write handler. In ETHOS it is possible to use the storage 
-- as the user wishes.
-----------------------------------------------------------------------
local function write ( widget )
    print("<<< WRITE >>>")
    storage.write("globalHomePosLat", widget.setup.home_pos.lat)
    storage.write("globalHomePosLon", widget.setup.home_pos.lon)
    storage.write("globalHomeDir", widget.setup.home_dir)
    storage.write("globalCompType", widget.setup.comp_type)
    storage.write("globalBaseALeft", widget.setup.baseA_left)
    storage.write("globalActiveLocation", widget.setup.active_location)
    storage.write("globalActiveCompetition", widget.setup.active_comp)
    --storage.write("widgetActiveLocation", widget.setup.active_location)
end
-----------------------------------------------------------------------
-- The init function is used to register the widget and various callbacks. 
-- system.registerWidget({ key = "unique", name = name, create = create,
-- configure = configure, wakeup = wakeup, paint = paint, read = read,
-- write = write, }) 
-----------------------------------------------------------------------
local function init()
    -- there's a limit on key size of 7 characters
    print("<<< INIT >>>")
    system.registerWidget({key="gps4f3x", name="LUA gps4F3X", create=create, configure=configure, paint=paint, read=read, write=write})
end

return {init=init}
