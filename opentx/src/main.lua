--[[#############################################################################
MAIN:

functions: ---------------------------------------------------------------------

################################################################################]]

-- VARIABLES
local startSwitchId = getFieldInfo("sh").id  -- start race when this switch is > 1024

-- GLOBAL VARIABLES (don't change)
global_gps_pos = {lat=0.,lon=0.}
-- global_home_dir -- defined in setup.lua
-- global_home_pos -- defined in setup.lua
-- global_comp_type = ... -- defined in setup.lua
-- global_comp_types = ... -- defined in setup.lua
-- global_baseA_left = ... -- defined in setup.lua
-- global_has_changed = ... -- defined in setup.lua


-- VARIABLES (internal)
local on_simulator = false
local basePath = '/SCRIPTS/TELEMETRY/gpstrack/' 
local gpsOK = false

-- WIDGETS
local course = nil
local sensor = nil
local screen = nil
local comp = nil
local gps = nil

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
-- simple linear extrapolation
local function straight(x, ymin, ymax, b)
    local offs = b or 0
    local result = math.floor((ymax - ymin) * x / 2048 + offs)
    return result
end
--[[ debug (we use this function to emulate GPS input)
local rudId = getFieldInfo("rud").id
local eleId = getFieldInfo("ele").id
local function getPosition()
    local direction = math.rad(straight(getValue(eleId),-45,45)) 
    local position = straight(getValue(rudId),-60,60)
    if string.find(global_comp_type,"f3b") then
        position = position * 1.5
    end
    global_gps_pos.lat = direction + 45.0
    global_gps_pos.lon = position + 60.0
    -- local az = sensor.az()
    return position,direction   
end
--]]
-------------------------------------------------------------------------
-- background (periodically called)
-------------------------------------------------------------------------
local function background( event )
    if gpsOK then
        -- read next gps position from sensor
        global_gps_pos = sensor.gpsCoord()
        if type(global_gps_pos) == 'table' and type(global_home_pos) == 'table' then
            -- read sensor data
            local dist2home = gps.getDistance(global_home_pos, global_gps_pos)
            local dir2home = gps.getBearing(global_home_pos, global_gps_pos)
            local groundSpeed = sensor.gpsSpeed() or 0.
            local gpsHeight = sensor.gpsAlt() or 0.
            local acclZ = sensor.az() or 0.
            --]]
            --[[ debug
            local dist2home,dir2home = getPosition()
            local groundSpeed = 10
            local gpsHeight = 99
            global_home_dir = 9
            local acclZ = 0.1
            --]]

            -- update course
            course.update(dist2home, dir2home, groundSpeed, acclZ)
            -- update competition
            comp.update(gpsHeight)
        else
            -- print("waiting...")
        end
    end
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
-------------------------------------------------------
-- load a new competition type
-------------------------------------------------------
local function reloadCompetition()
    -- reload competition accordingly to new parameters
    if type(global_comp_types) == 'table' and global_has_changed == true then
        print("<<<< Reload Competition >>>>")
        local save_gpsOK = gpsOK
        global_has_changed = false
        
        -- inactivate background process
        gpsOK = false 
    
        -- set some useful default values (just in case ...)
        local file_name = 'f3f.lua'
        local mode = 'training'
        local length = 50
        -- get competition
        local entry = getCompEntry(global_comp_type)
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
            comp = mydofile(basePath..file_name)
        end

        -- reset competition
        comp.init(mode, global_baseA_left)
        -- set ground height
        if save_gpsOK then
            comp.groundHeight = sensor.gpsAlt() or 0.
        end
        -- reset course and update competition hooks
        course.init(length, math.rad(global_home_dir), comp)
        -- for F3B the home position is base A always. The course library needs the home in the middle between the bases. -> move home in direction of base B
        if string.find(global_comp_type,"f3b") then
            local new_position = gps.getDestination(global_home_pos, length, global_home_dir)
            print(string.format("F3B: moved home by %d meter from: %9.6f, %9.6f to: %9.6f, %9.6f",length, global_home_pos.lat, global_home_pos.lon, new_position.lat, new_position.lon))
            global_home_pos = new_position
        end

        -- enable 
        gpsOK = save_gpsOK
    end

end
-------------------------------------------------------------------------
-- run (periodically called when custom telemetry screen is visible)
-------------------------------------------------------------------------
local runs = 0
local loops = 0
local last_timestamp = 0
local last_loop = 0

local function run(event)
    -------------------------------------------------------
    -- setup screen   
    -------------------------------------------------------
    if not screen.cleaned then
        if global_has_changed then
            reloadCompetition()
        end
        local text
        screen.clean()
        -- set screen title
        if global_comp_type == "f3b_dist" then
            text = "F3B: Distance"
        elseif global_comp_type == "f3b_spee" then
            text = "F3B: Speed"
        else
            text = string.format("F3F: %s mode", comp.mode)
        end
        screen.title(text,1,2)
        -- line 2: General info
        if type(global_comp_types) ~= 'table' then
            text = "Course Setup: use setup screen"
        else
            local base = "base A: right"
            if global_baseA_left then
                base = "base A: left"
            end
            text = string.format("Course Setup: %s", base)
        end
        screen.text(2, text)
        screen.showStack()
    end
    -------------------------------------------------------
    -- draw continous updated values
    -------------------------------------------------------
    loops = loops+1
    if gpsOK then
        if type(global_gps_pos) == 'table' then
            
            -- update screen every ~ .5s
            if loops % 5 == 0 then
                local time_stamp = getTime()
                local time_diff = time_stamp - last_timestamp
                local num_loops = loops - last_loop
                local rate = num_loops/ time_diff * 100.0

                last_timestamp = time_stamp
                last_loop = loops
                -- check for start event
                local startVal = getValue(startSwitchId)
                if comp and startVal > 0 then
                    if global_comp_type == 'f3b_dist' then
                        if comp.state ~= 1 and comp.runs > 0 and runs ~= comp.runs then
                            -- comp finished by hand
                            runs = comp.runs -- lock update 
                            screen.addLaps(comp.runs, comp.lap - 1)
                        end
                    end
                    comp.start()
                end
                -- line 1: competition status
                screen.text(1, "Comp: " .. comp.message)
                -- add result to the right screen
                if comp.state == 1 and comp.runs > 0 and runs ~= comp.runs then
                    runs = comp.runs -- lock update
                    if global_comp_type == 'f3b_dist' then
                        screen.addLaps(runs, comp.lap - 1)
                    else
                        screen.addTime(runs, comp.runtime)
                    end
                    screen.showStack()
                end
                -- line 2: General Info
                screen.text(2, string.format("Runtime: %5.2fs",comp.runtime/1000.0))
                -- line 3: Course state
                screen.text(3, "Course: " .. course.message)
                -- line 4: course information
                screen.text(4, string.format("V: %6.2f m/s Dst: %-7.2f m ",course.lastGroundSpeed, course.lastDistance))
                screen.text(5, string.format("H: %5.2fm           %5.1f calls/s",comp.groundHeight, rate))
                -- line 5: gps information
                -- screen.text(5, string.format("GPS: %9.6f %9.6f",global_gps_pos.lat,global_gps_pos.lon))  
            end
        else
            -- GPS sensor is warming up
            screen.text(4, "GPS: waiting for data...")
        end
    else
        -- sensor not defined/connected
        screen.text(5, "GPS sensor not found: " .. sensor.name, BLINK)
    end
    -- miscelanious
    if event == EVT_PAGE_BREAK or event == EVT_PAGE_LONG then
        ----------------------------------------------------
        -- leave page -> redraw screen on next activation
        ----------------------------------------------------
        screen.cleaned = false
    end
end
-----------------------------------------------------------
-- debug
-----------------------------------------------------------
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
local function init()
    print("<<< INIT MAIN >>>")
    -- are we running on simulator?
    local ver, radio, maj, minor, rev = getVersion()
    if string.find(radio,"-simu") then
        print("Simulator detectded")
        on_simulator = true
    end

    -- load gps library
    gps = mydofile(basePath..'gpslib.lua')
    -- load screen  
    screen = mydofile(basePath..'screen.lua')
    screen.init(5,true)
    -- load sensor 
    sensor = mydofile(basePath..'sensors.lua')
    -- gpsOK = sensor.init('gpsV2')
    gpsOK = sensor.init('logger3')
    -- load course (2 bases)   
    course = mydofile(basePath..'course.lua')

    if type(global_comp_types) == 'table' then
        -- setup screen already initialized
        print("<<< INITIAL RELOAD COMPETITION >>>")
        global_has_changed = true
        reloadCompetition()  
    else
        -- if this module is loaded after the setup module we need some defaults for competition and course
        print("<<< SETUP MISSED >>>")
        global_comp_type = 'f3f_trai'
        global_baseA_left = true
        -- my parking lot :-)
        global_home_dir = 9.0
        global_home_pos = { lat=53.550707, lon=9.923472 }
        -- load competition (default f3f and training)
        comp = mydofile(basePath..'f3f.lua')
        comp.init('training', global_baseA_left)
        -- setup course (debuggg)    
        course.init(10, math.rad(global_home_dir), comp)
    end    
end

return { init=init, background=background, run=run }