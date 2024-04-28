--[[#############################################################################
COMPETITION Library: F3B Distance
F3B: we define: baseA is always left. 
state:
 0: not armed
 5: entry: armed
10: entry: wait for BaseLineOut/In event
15: entry: wait for BaseLineIn event
20: competition: start race 
25: BaseBOut, lap = lap + 1
27: BaseAOut, lap = lap + 1 and end  
functions: ---------------------------------------------------------------------
################################################################################]]

local comp = {name='f3bdist.lua', baseAleft=true, mode='training', trainig=true, state=0, groundHeight=0., lastHeight=0., runtime=0, message='---'}

function comp.init(mode, startLeft)
    comp.training = false -- not needed
    comp.mode = 'competition' -- not needed
    comp.baseAleft = true -- always true for F3B
    comp.state = 0 -- initial state
    comp.startTime_ms = 0
    comp.lap = 0
    comp.lastLap = 0
    comp.runs = 0
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
    comp.workingTime_ms = (7 * 60 * 1000)
    comp.compTime_ms = (4 * 60 * 1000)
    comp.played = { }
    comp.played_minutes = { }
end
-- prepare all bases for next timing event 
function comp.cleanbases()
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
end
-- start competition timer 
function comp.startTimer()
    comp.runtime = 0
    comp.startTime_ms = getTime() * 10
end
-- reset all values and start the competition
function comp.start()
    -- start the status machine
    comp.message = "started..."
    comp.cleanbases()
    comp.lap = 0
    comp. state = 10
    playTone(800,300,0,PLAY_NOW)
end
-- messages on base
local lapTimeOdd = 0
function comp.lapPassed(lap, laptime)
    comp.message = string.format("lap %d: %5.2fs", lap, laptime/1000.)
    playNumber(lap,0)
    -- It seems to make sense to have only one interim time
    if lap % 2 == 0 then
        laptime = laptime + lapTimeOdd
        playNumber((laptime+50) / 100., 0, PREC1) -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
    else
        -- store laptime on odd lap
        lapTimeOdd = laptime
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
        -- set start message and block further updates
        comp.message = "waiting for start..."
        comp.state = 1
        return
    elseif comp.state == 1 then
        return
    end
    -------------------------------------------------------
    -- 10: WAIT for BASE A IN/OUT
    -------------------------------------------------------
    if comp.state == 10 then
        if comp.leftBaseOut > 0 then
            playTone(800,300,0,PLAY_NOW)
            comp.cleanbases()
            comp.message = "out of course"
            comp.state = 15
        elseif comp.leftBaseIn > 0 then
            playTone(800,300,0,PLAY_NOW)
            comp.message = "in course..."
            comp.state = 20
        end
        return
    end
    -------------------------------------------------------
    -- 15: BASE A IN (from outside)
    -------------------------------------------------------
    if comp.state == 15 then
        if comp.leftBaseIn > 0 then
            playTone(800,300,0,PLAY_NOW)
            comp.message = "in course..."
            comp.state = 20
            return
        end
        return
    end
    -------------------------------------------------------
    -- 20: START at BASE A
    -------------------------------------------------------
    if comp.state == 20 then
        comp.startTimer()
        comp.cleanbases()
        comp.lastLap = comp.startTime_ms
        comp.lap = 1
        comp.state = 25 -- next base must be B
        return
    end
    -------------------------------------------------------
    -- 25: BASE B (comp running)
    -------------------------------------------------------
    if comp.state == 25 and comp.lap > 0 then
        -- working time...
        comp.runtime = getTime() * 10 - comp.startTime_ms  
        -- Base B
        if comp.rightBaseOut  > 0 then
            local laptime = comp.rightBaseOut - comp.lastLap
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.rightBaseOut
            comp.cleanbases()
            if comp.lap > 3 then
                comp.state = 30
                return
            end
            comp.lapPassed(comp.lap, laptime)
            comp.lap = comp.lap + 1
            comp.state = 27 -- next base must be A
            return
        end
        return
    end
    -------------------------------------------------------
    -- 27: BASE A (comp running)
    -------------------------------------------------------
    if comp.state == 27 and comp.lap > 0 then
        -- working time...
        comp.runtime = getTime() * 10 - comp.startTime_ms
        -- Base A
        if comp.leftBaseOut > 0 then
            local laptime = comp.leftBaseOut - comp.lastLap
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.leftBaseOut
            comp.cleanbases()
            if comp.lap > 3 then
                comp.state = 30
                return
            end
            comp.lapPassed(comp.lap, laptime)
            comp.lap = comp.lap + 1
            comp.state = 25 -- next base must be B
            return
        end     
        return
    end
    -------------------------------------------------------
    -- 30: END
    -------------------------------------------------------
    if comp.state == 30 then
        comp.runtime = comp.lastLap - comp.startTime_ms
        playNumber((comp.runtime + 50 ) / 100., 37, PREC1) -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
        comp.runs = comp.runs + 1
        comp.state = 0
        return
    end
end

return comp
