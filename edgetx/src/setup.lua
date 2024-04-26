--[[#############################################################################
MAIN:

functions: ---------------------------------------------------------------------
course direction: s1:  0 - 360 cardinal direction
competition type: s2:  scrolls through valid types
base A:           rud: left -> left; rudder right -> right
+/- keys (scrollbar):  select predefined location and competion from list
enter:                 activate current selection
################################################################################]]
-- VARIABLES
local sliderId = getFieldInfo('s1').id
local slider2Id = getFieldInfo('s2').id
local rudderId = getFieldInfo('rud').id


-- GLOBAL VARIABLES
-- global_gps_pos = ... -- from main.lua
global_home_dir = 0.0 -- placeholder
global_home_pos = {lat=0.,lon=0.} -- placeholder
global_baseA_left = true -- default
global_has_changed = false -- default
global_comp_type = 'f3f_trai' -- default
global_comp_types = {
    {name='f3f_trai', default_mode='training', course_length=100, file='f3f.lua' },
    {name='f3f', default_mode='competition', course_length=100, file='f3f.lua' },
    {name='f3b_dist', default_mode='competition', course_length=150, file='f3bdist.lua' },
    {name='f3b_spee', default_mode='competition', course_length=150, file='f3bsped.lua' },
    {name='f3f_debug', default_mode='training', course_length=10, file='f3f.lua' }
}

-- VARIABLES (private -- do not edit)
local basePath = '/SCRIPTS/TELEMETRY/gpstrack/'

-- WIDGETS
local screen = nil 

-----------------------------------------------------------
-- module load function
-----------------------------------------------------------
function mydofile (filename)
    -- local f = assert(loadfile(filename))
    --  mode: b: only binary, t: only text, c: compile only, x: do not compile
    local mode = 'bx'
    if on_simulator then
        mode = 'T'
    end
    local f = assert(loadScript(filename,mode))
    return f()
end

-----------------------------------------------------------
-- linear extrapolation
-----------------------------------------------------------
local function straight(x, ymin, ymax, b)
    local offs = b or 0
    local result = math.floor((ymax - ymin) * x / 2048 + offs)
    return result
end
-----------------------------------------------------------
-- comp_type helper
-----------------------------------------------------------
local function compName(index)
    local entry = global_comp_types[index]
    if type(entry) == 'table' then
        return entry.name
    end
    -- default is the first entry.name
    return global_comp_types[1].name
end

-------------------------------------------------------------------------
-- background (periodically called when custom telemetry screen is not visible)
-------------------------------------------------------------------------
local function background( event )
    -- not used
end

-------------------------------------------------------------------------
-- run (periodically called when custom telemetry screen is visible)
-------------------------------------------------------------------------

local cleaned = false
local cblist = {}
local cblen = 0
local idx = 0
local lat = 0.0
local lon = 0.0
local cdir = 0.0
local activated = 0
local sliderVal = 0
local slider2Val = 0
local comp_type = '???'
local locations = {}

local function run(event)
    ------------------------------------------------------------------------------------------
    -- Renew complete screen
    ------------------------------------------------------------------------------------------
        if not screen.cleaned then
        -- create a full new screen
        screen.clean()
        screen.title("GPS Parameter Setup", 2, 2)
        
        lcd.drawCombobox(0,9,LCD_W-1,cblist,idx,0)
        if lat == 0.0 and lon == 0.0 then
            screen.text(2, "    GPS Position: waiting for signal...")
        else
            screen.text(2, string.format("    GPS Position: %9.6f, %9.6f",lat,lon))
        end
        screen.text(3, string.format("    Course Direction: %5.1f",cdir))
        screen.text(4, string.format("    Competition Type: %s", comp_type))
        screen.text(5, "    Activate values by pressing Enter")
        cleaned = true
    end
    
    if event == EVT_PLUS_FIRST or event == EVT_ROT_LEFT then
        ----------------------------------------------------
        -- plus key released -> go backward in combobox
        ----------------------------------------------------
        idx = idx -1
        if idx < 0 then
            idx = 0
        end
        if idx > 0 then
            -- update all parameters with values from list
            print(string.format("idx: %d, name: %s",idx+1,locations[idx+1].name))
            local ci = locations[idx+1].comp
            comp_type = global_comp_types[ci].name
            lat = locations[idx+1].lat
            lon = locations[idx+1].lon
            cdir = locations[idx+1].dir
        end
        -- redraw screen in next loop
        screen.cleaned = false
    elseif event == EVT_MINUS_FIRST or event == EVT_ROT_RIGHT then
        ----------------------------------------------------
        -- minus key released -> go forward in combobox
        ----------------------------------------------------
        idx = idx + 1
        if idx >= cblen then
            idx = cblen-1
        end
        if idx > 0 then
            -- update all parameters with values from list
            -- print(string.format("idx: %d, name: %s",idx+1,locations[idx+1].name))
            local ci = locations[idx+1].comp
            comp_type = global_comp_types[ci].name
            lat = locations[idx+1].lat
            lon = locations[idx+1].lon
            cdir = locations[idx+1].dir
        end
        -- redraw screen in next loop
        screen.cleaned = false
    elseif event == EVT_ENTER_BREAK or event == EVT_ROT_BREAK then
        ---------------------------------------------------------------------------------------
        -- if enter key released -> make values global and block action for at least 5 seconds
        ---------------------------------------------------------------------------------------
        if activated == 0 then
            global_home_dir = cdir
            global_home_pos.lat = lat
            global_home_pos.lon = lon 
            global_comp_type = comp_type
            global_has_changed = true
            screen.text(5, "    --- Activated ---",INVERS)
            activated = 50
        end
    end

    if event == EVT_PAGE_BREAK or event == EVT_PAGE_LONG then
        ----------------------------------------------------
        -- leave page -> redraw screen on next activation
        ----------------------------------------------------
        screen.cleaned = false
    end
    if activated == 0 then
        -- base left from rudder (can be changed for all types)
        local rudderVal = getValue(rudderId)
        if rudderVal < -250 and global_baseA_left == false then
            global_baseA_left = true
            screen.text(5, "    Course Base: left")
        end
        if rudderVal > 250 and global_baseA_left == true then
            global_baseA_left = false
            screen.text(5, "    Course Base: right")
        end
    end
    if idx == 0 and activated == 0 then
        ----------------------------------------------------
        -- dropdown shows first line -> read live values
        ----------------------------------------------------
        
        -- course direction from slider 1
        local newDir
        sliderVal = getValue(sliderId)
        newDir = straight(sliderVal,0,360,180) + 0.0
        if cdir ~= newDir then
            cdir = newDir
            screen.text(3, string.format("    Course Direction: %5.1f",cdir))
        end
        
        -- competition type from slider 2
        local newChoice
        local len = #global_comp_types
        slider2Val = getValue(slider2Id)
        newChoice = math.floor((slider2Val + 1024) / 2048 * len) + 1
        if newChoice > len then
            newChoice = len
        end
        if comp_type ~= compName(newChoice) then
            comp_type = compName(newChoice)
            screen.text(4, string.format("    Competition Type: %s", comp_type))
        end
        
        -- home position from actual GPS values
        if type(global_gps_pos) == 'table' then
            local newLat = global_gps_pos.lat
            local newLon = global_gps_pos.lon
            if newLat ~= lat or newLon ~= lon then
                lat = newLat
                lon = newLon
                screen.text(2, string.format("    GPS Position: %9.6f, %9.6f",lat,lon))
            end
        else
            screen.text(2, "    GPS Position: waiting for signal...")
        end 
    end
    if activated > 0 then
        -- block activation for a dedicated amount of time
        activated = activated - 1
        if activated == 0 then
            screen.cleaned = false
        end
    end
end

-- translate locations to combobox entries
local function loc2cb( loc )
    local cb = {}
    local len = 0
    for i,v in ipairs(loc) do
        -- set default competition type
        if i == 1 then
            local ci = v['comp']
            local cname = global_comp_types[ci].name
            comp_type = cname
        end
        cb[i] = string.format("%d: %s",i,v['name'])
        len = len + 1
    end    
    return cb,len
end

-- debug
local function vers(event)
    local ver, radio, maj, minor, rev = getVersion()
    print("version: "..ver)
    if radio then print ("radio: "..radio) end
    if maj then print ("maj: "..maj) end
    if minor then print ("minor: "..minor) end
    if rev then print ("rev: "..rev) end
    return 1
end

-------------------------------------------------------------------------
-- init (the script init function)
-------------------------------------------------------------------------
local tools = {}
-- config.locations = {name = "Hang1",lat = 0.987654321, lon = 0.123457689, default = true} 
local function init()
    print("<<< INIT SETUP >>>")
    -- are we running on simulator?
    local ver, radio, maj, minor, rev = getVersion()
    if string.find(radio,"-simu") then
        print("Simulator detectded")
        on_simulator = true
    end

        -- load locations table  
    locations = mydofile(basePath..'locations.lua')
    -- load screen  
    screen = mydofile(basePath..'screen.lua')
    screen.init(5)

    -- setup the locations combobox
    print(type(global_comp_types))
    cblist,cblen = loc2cb(locations)
    
    -- test if we can store locations
    -- tools = mydofile(basePath..'tools.lua')
    -- print(tools.serializeTable(locations))
    -- local f = io.open(basePath.."foo.bar", "w")
    -- io.write(f,"locations = " .. tools.serializeTable(locations))
    -- io.close(f)
end

return { init=init, background=nil, run=run }