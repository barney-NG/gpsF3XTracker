--[[#############################################################################
COMPETITION Library: F3F (traing and competition)
state:
 0: not armed
 5: entry: arm starttimer
10: entry: wait for xxxBaseOut event
15: entry: wait for xxxBaseIn event
20: comp: arm comptimer, 
25: rightBaseOut, lap(1)
27: leftBaseOut, 
functions: ---------------------------------------------------------------------
################################################################################]]

local comp = {name='f3f.lua', baseAleft=true, mode='training', trainig=true, state=0, groundHeight=0., runtime=0, message='---'}

function comp.init(mode, startLeft)
    if mode == 'training' then
        comp.training = true
        comp.mode = mode
    else
        comp.training = false
        comp.mode = 'competition'
    end
    if startLeft then
        comp.baseAleft = true
    else
        comp.baseAleft = false
    end
    comp.state = 0 -- initial state
    comp.startTime_ms = 0
    comp.entrystart = 0
    comp.lap = 0
    comp.lastLap = 0
    comp.runs = 0
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
    comp.played = { }
end
-- play countdown messages
function comp.countdown(elapsed_milliseconds)
    local milliseconds = 30500 - elapsed_milliseconds
    local seconds = math.floor(milliseconds / 1000)
    
    if seconds >= 10 and seconds % 10 == 0 then 
        if not comp.played[seconds] then
            playNumber(seconds,0)
            comp.played[seconds] = true
        end
    end
    if seconds > 0 and seconds <= 5 then
        if not comp.played[seconds] then
            playNumber(seconds,0)
            comp.played[seconds] = true
        end
    end

end
-- prepare all bases for next timing event 
function comp.cleanbases()
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
end
-- start competition timer (if not started already during the entry phase)
function comp.startTimer()
    if comp.startTime_ms == 0 or comp.training == true then
        comp.runtime = 0
        comp.startTime_ms = getTime() * 10
    end
end
-- reset all values and start the competition
function comp.start()
    playTone(800,300,0,PLAY_NOW)
    comp.cleanbases()
    comp.lap = 0
    comp.runtime = 0
    -- cancel execution?
    if comp.state > 1 then
        comp.state = 0
        return
    end
    comp.message = "started..."
    if comp.training then
        comp.state = 15
    else
        comp.state = 5
    end
end
-- messages on base
local lapTimeOdd = 0
function comp.lapPassed(lap, laptime)
    comp.message = string.format("lap %d: %5.2fs", lap, laptime/1000.)
    playNumber(lap,0)
    if comp.training then
        -- My friend Markus Meissner wants to have time only on even laps
        if lap % 2 == 0 then
            laptime = laptime + lapTimeOdd
            playNumber((laptime+50) / 100., 0, PREC1) -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
        else
            -- store laptime on odd lap
            lapTimeOdd = laptime
        end
    end
end
-------------------------------------------------------
-- Update Competition Status Machine
-------------------------------------------------------
function comp.update(height)
    comp.groundHeight = height or 0.
    -------------------------------------------------------
    -- 0/1: not armed 
    -------------------------------------------------------
    if comp.state == 0 then
        comp.message = "waiting for start..."
        comp.state = 1
        return
    elseif comp.state == 1 then
        return
    end
    -------------------------------------------------------
    -- 5: START ENTRY
    -------------------------------------------------------
    if comp.state == 5 then
        -- playNumber(30,37)
        for number in pairs(comp.played) do
            comp.played[number] = false
        end
        comp.entrystart = getTime() * 10 -- timestamp in milliseconds
        comp.startTime_ms = 0
        comp.state = 10
        comp.cleanbases()
        comp.message = "start climbing..."
        return
    end
    -------------------------------------------------------
    -- STARTPHASE (between bases)
    -- wait for xxxBaseOutEvent
    -------------------------------------------------------
    if comp.state == 10 then
        if comp.baseAleft then
            if comp.leftBaseOut > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.cleanbases()
                comp.message = "out of course"
                comp.state = 15
                return
            end
        else
            if comp.rightBaseOut > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.cleanbases()
                comp.message = "out of course"
                comp.state = 15
                return
            end
        end
        -- check if entry time limit exceeded
        local elapsed = getTime() * 10 - comp.entrystart
        if elapsed > 30000 then
            -- yes start the competition timer
            if comp.startTime_ms == 0 then
                comp.startTimer()
                comp.message = "race timer started..."
            else
                comp.runtime =  getTime() * 10 - comp.startTime_ms
            end
        else
            comp.countdown(elapsed)
        end
        return
    end
    -------------------------------------------------------
    -- 15: OUTSIDE (beyond bases)
    -- wait for xxxBaseInEvent (start training here)
    -------------------------------------------------------
    if comp.state == 15 then
        if comp.baseAleft then
            if comp.leftBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20
                return
            end
        else
            if comp.rightBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20
                return
            end
        end
        -- check again if entry time limit exceeded
        if comp.entrystart > 0 then
            local elapsed = getTime() * 10 - comp.entrystart
            if elapsed > 30000 then
                -- yes start the competition timer
                if comp.startTime_ms == 0 then
                    comp.startTimer()
                    comp.message = "timer started..."
                else
                    comp.runtime = getTime() * 10 - comp.startTime_ms
                end
            else
                comp.countdown(elapsed)
            end
        end
        return
    end
    -------------------------------------------------------
    -- 20: IN COURSE
    -------------------------------------------------------
    if comp.state == 20 then
        comp.startTimer()
        comp.entrystart = 0 -- stop entry phase
        comp.cleanbases()
        comp.lastLap = comp.startTime_ms
        comp.lap = 1
        -- playNumber(comp.lap,0)
        if comp.baseAleft then
            comp.state = 25 -- first base is right
        else
            comp.state = 27 -- first base is left
        end
        return
    end
    -------------------------------------------------------
    -- 25: RIGHT BASE (comp running)
    -------------------------------------------------------
    if comp.state == 25 and comp.lap > 0 then
        -- working time...
        comp.runtime = getTime() * 10 - comp.startTime_ms  
        -- RIGHT BASE
        if comp.rightBaseOut  > 0 then
            local laptime = comp.rightBaseOut - comp.lastLap
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.rightBaseOut
            comp.cleanbases()
            if comp.lap > 9 then
                comp.state = 30
                return
            end
            comp.lapPassed(comp.lap, laptime)
            comp.lap = comp.lap + 1
            comp.state = 27
            return
        end
        return
    end
    -------------------------------------------------------
    -- 27: LEFT BASE (comp running)
    -------------------------------------------------------
    if comp.state == 27 and comp.lap > 0 then
        -- working time...
        comp.runtime = getTime() * 10 - comp.startTime_ms
        if comp.leftBaseOut > 0 then
            local laptime = comp.leftBaseOut - comp.lastLap
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.leftBaseOut
            comp.cleanbases()
            if comp.lap > 9 then
                comp.state = 30
                return
            end
            comp.lapPassed(comp.lap, laptime, lostHeight)
            comp.lap = comp.lap + 1
            comp.state = 25
            return
        end     
        return
    end
    -------------------------------------------------------
    -- END
    -------------------------------------------------------
    if comp.state == 30 then
        comp.runtime = comp.lastLap - comp.startTime_ms
        playNumber((comp.runtime + 50)/ 100., 37, PREC1) -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
        comp.runs = comp.runs + 1
        comp.state = 0
        return
    end
end

return comp
