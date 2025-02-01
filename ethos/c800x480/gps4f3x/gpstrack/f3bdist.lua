--[[#############################################################################
COMPETITION Library: F3B Distance: GPS F3X Tracker for Ethos v1.0

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

F3B: we define: baseA is always left. 
state:
 0: not armed
 5: entry: armed
10: entry: wait for BaseLineOut/In event
15: entry: wait for BaseLineIn event
20: competition: start countdown timer (4 mins or remaining frame time) 
25: BaseBOut, lap = lap + 1
27: BaseAOut, lap = lap + 1 
functions: ---------------------------------------------------------------------
################################################################################]]

local comp = {name='f3bdist.luac', baseAleft=true, mode='training', trainig=true, state=0, groundHeight=0., lastHeight=0., runtime=0, message='---'}

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


function comp.countdown(elapsed_milliseconds)
    local milliseconds = (comp.comptTime_ms + 500) - elapsed_milliseconds
    local seconds = math.floor(milliseconds / 1000)
    
    if seconds >= 60 then
        local minutes = math.floor(seconds/60)
        if not com.played_minutes[minutes] then
--            playNumber(minutes,36)
            system.playNumber(minutes)
            comp.played_minutes[minutes] = true
        end
        return
    end
    if seconds >= 10 and seconds % 10 == 0 then 
        if not comp.played[seconds] then
            system.playNumber(seconds)
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
-- start competition timer
function comp.startTimer()
    comp.runtime = 0
    comp.startTime_ms = getETime()
end
-- reset all values and start the competition
function comp.start()
    system.playTone(800,300)
    -- start button activated during run -> finish run
    if comp.state == 25 or comp.state == 27 then
        comp.state = 30
        return
    end
    -- start the status machine
    comp.cleanbases()
    comp.lap = 0
    if comp.state == 1 then
        comp.message = "started..."
        comp. state = 10
    else
        comp.message = "cancelled..."
        comp. state = 0
    end
end
-- messages on base
function comp.lapPassed(lap, laptime, lostHeight)
    comp.message = string.format("lap %d: %5.2fs diff: %-5.1fm", lap, laptime/1000.0, lostHeight)
    system.playNumber(lap,0)
    playNumber((laptime+50) / 1000., UNIT_SECOND,0)
    if math.abs(lostHeight) > 0.5 then
        system.playNumber(lostHeight,0) -- lost height in meters per lap
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
            system.playTone(800,300)
            comp.cleanbases()
            comp.message = "out of course"
            comp.state = 15 -- wait for base A in event
        elseif comp.leftBaseIn > 0 then
            system.playTone(800,300)
            comp.message = "in course..."
            comp.state = 20 -- go to start
        end
        return
    end
    -------------------------------------------------------
    -- 15: BASE A IN (from outside)
    -------------------------------------------------------
    if comp.state == 15 then
        if comp.leftBaseIn > 0 then
            system.playTone(800,300)
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
        -- working time exceeded?
        comp.runtime = getETime() - comp.startTime_ms
        if comp.runtime > comp.compTime_ms then
            -- competition ended after 4 minutes
            comp.state = 30
            return
        end  
        -- Base B
        if comp.rightBaseOut  > 0 then
            local laptime = comp.rightBaseOut - comp.lastLap
            local lostHeight = comp.groundHeight - comp.lastHeight
            system.playTone(800,300)
            comp.lastLap = comp.rightBaseOut
            comp.lastHeight = comp.groundHeight
            comp.cleanbases()
            comp.lapPassed(comp.lap, laptime, lostHeight)
            comp.lap = comp.lap + 1
            comp.state = 27 -- next base must be A
        end
        return
    end
    -------------------------------------------------------
    -- 27: BASE A (comp running)
    -------------------------------------------------------
    if comp.state == 27 and comp.lap > 0 then
        -- working time exceeded?
        comp.runtime = getETime() - comp.startTime_ms
        if comp.runtime > comp.compTime_ms then
            -- competition ended after 4 minutes
            comp.state = 30
            return
        end
        -- Base A
        if comp.leftBaseOut > 0 then
            local laptime = comp.leftBaseOut - comp.lastLap
            local lostHeight = comp.groundHeight - comp.lastHeight
            playTone(800,300)
            comp.lastLap = comp.leftBaseOut
            comp.lastHeight = comp.groundHeight
            comp.cleanbases()
            comp.lapPassed(comp.lap, laptime, lostHeight)
            comp.lap = comp.lap + 1
            comp.state = 25 -- next base must be A
        end     
        return
    end
    -------------------------------------------------------
    -- 30: END
    -------------------------------------------------------
    if comp.state == 30 then
        system.playNumber(comp.lap - 1, 0) -- lap count
        comp.runs = comp.runs + 1
        comp.state = 0
        return
    end
end

return comp
