--[[#############################################################################
COMPETITION Library: F3F (traing and competition): GPS F3X Tracker for Ethos v1.3

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

state:
 0: not armed
 5: entry: arm starttimer
10: entry: wait for xxxBaseOut event
15: entry: wait for xxxBaseIn event
20: comp: arm comptimer, 
25: rightBaseOut, lap(1)
27: leftBaseOut
30: end

Change log:
- v1.1: - 
- v1.2: - 
- v1.3: - some small optimizations
################################################################################]]

local comp = {name='f3f.luac', baseAleft=true, mode='training', trainig=true, state=0, groundHeight=0., runtime=0, message='---'}

function comp.init(mode, startLeft)                         -- initialize event values
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
  comp.state = 0                                            -- initial state
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

function comp.countdown(elapsed_milliseconds)               -- play countdown messages
  local milliseconds = 30500 - elapsed_milliseconds
  local seconds = math.floor(milliseconds / 1000)
    
  if seconds >= 10 and seconds % 10 == 0 then 
    if not comp.played[seconds] then
      system.playNumber(seconds)
      comp.played[seconds] = true
    end
  end
  if seconds > 0 and seconds <= 5 then
    if not comp.played[seconds] then
      system.playNumber(seconds)
      comp.played[seconds] = true
    end
  end
end
 
function comp.cleanbases()                                  -- prepare all bases for next timing event
  comp.leftBaseIn = 0
  comp.leftBaseOut = 0
  comp.rightBaseIn = 0
  comp.rightBaseOut = 0
end

function comp.startTimer()                                  -- start competition timer (if not started already during the entry phase)
  if comp.startTime_ms == 0 or comp.training == true then
    comp.runtime = 0
    comp.startTime_ms = getETime()
  end
end
-------------------------------------------------------
-- function comp.start - Reset Competition Status Machine
-------------------------------------------------------
function comp.start()                                       -- reset all values and start the competition
  system.playTone(600,300)
  comp.cleanbases()                                         -- prepare all bases for next timing event
  comp.lap = 0
  comp.runtime = 0
    
  if comp.state == 1 then
     comp.message = "started..."
     if comp.training then
       comp.state = 15
     else
       comp.state = 5
     end
  else
     comp.message = "canceled..."
     comp.state = 0
  end
end

local lapTimeOdd = 0
function comp.lapPassed(lap, laptime)                       -- messages on base
  comp.message = string.format("lap %d: %5.2fs", lap, laptime/1000.)
  system.playNumber(lap)
  if comp.training then                                   -- My friend Markus Meissner wants to have time only on even laps
    if lap % 2 == 0 then
      laptime = laptime + lapTimeOdd
      system.playNumber((laptime+50) / 1000., UNIT_SECOND,0)
    else
      lapTimeOdd = laptime                                  -- store laptime on odd lap
    end
  end
end
-------------------------------------------------------
-- function comp.update - Update Competition Status Machine
-------------------------------------------------------
function comp.update(height)
  comp.groundHeight = height or 0.
  if comp.state == 0 then                                   -- 0/1: not armed 
    comp.message = "waiting for start..."
    comp.state = 1
    return
  elseif comp.state == 1 then
    return
  end

  if comp.state == 5 then                                   -- 5: START ENTRY: arm starttimer
    for number in pairs(comp.played) do
            comp.played[number] = false
    end
    comp.entrystart = getETime()
    comp.startTime_ms = 0
    comp.state = 10
    comp.cleanbases()
    comp.message = "start climbing..."
    return
  end

  if comp.state == 10 then                                  -- 10: STARTPHASE (between bases): wait for xxxBaseOutEvent
    if comp.baseAleft then
      if comp.leftBaseOut > 0 then
        system.playTone(800,300)
        comp.cleanbases()
        comp.message = "out of course"
        comp.state = 15
        return
      end
    else
      if comp.rightBaseOut > 0 then
        system.playTone(800,300)
        comp.cleanbases()
        comp.message = "out of course"
        comp.state = 15
        return
      end
    end

    local elapsed = getETime() - comp.entrystart            -- check if entry time limit exceeded
      if elapsed > 30000 then
        if comp.startTime_ms == 0 then                      -- yes start the competition timer
          comp.startTimer()
          comp.message = "race timer started..."
        else
          comp.runtime =  getETime() - comp.startTime_ms
        end
      else
          comp.countdown(elapsed)
      end
    return
  end

  if comp.state == 15 then                                  -- 15: OUTSIDE (beyond bases): wait for xxxBaseInEvent (start training here)
    if comp.baseAleft then
      if comp.leftBaseIn > 0 then
        system.playTone(1000,300)
        comp.message = "in course..."
        comp.state = 20
        return
      end
    else
      if comp.rightBaseIn > 0 then
        system.playTone(1000,300)
        comp.message = "in course..."
        comp.state = 20
        return
      end
    end

    if comp.entrystart > 0 then                             -- check again if entry time limit exceeded
      local elapsed = getETime() - comp.entrystart
      if elapsed > 30000 then
        if comp.startTime_ms == 0 then                      -- yes start the competition timer
          comp.startTimer()
          comp.message = "timer started..."
        else
          comp.runtime = getETime() - comp.startTime_ms
        end
      else
        comp.countdown(elapsed)
      end
    end
    return
  end

  if comp.state == 20 then                                  -- 20: IN COURSE: arm comptimer
    comp.startTimer()
    comp.entrystart = 0                                     -- stop entry phase
    comp.cleanbases()
    comp.lastLap = comp.startTime_ms
    comp.lap = 1
--    playNumber(comp.lap,0)
    if comp.baseAleft then
      comp.state = 25                                       -- first base is right
    else
      comp.state = 27                                       -- first base is left
    end
    return
  end

  if comp.state == 25 and comp.lap > 0 then                 -- 25: RIGHT BASE (comp running): rightBaseOut
    comp.runtime = getETime() - comp.startTime_ms           -- working time... 
    if comp.rightBaseOut  > 0 then                          -- RIGHT BASE
      local laptime = comp.rightBaseOut - comp.lastLap
      system.playTone(1200,300)
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

  if comp.state == 27 and comp.lap > 0 then                 -- 27: LEFT BASE (comp running): leftBaseOut
    comp.runtime = getETime() - comp.startTime_ms           -- working time...
    if comp.leftBaseOut > 0 then                            -- LEFT BASE
      local laptime = comp.leftBaseOut - comp.lastLap
      system.playTone(1200,300)
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

  if comp.state == 30 then                                  -- 30: END
    comp.runtime = comp.lastLap - comp.startTime_ms
--    playNumber((comp.runtime + 50)/ 100., 37, PREC1)      -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
    system.playNumber((comp.runtime + 50)/ 1000., UNIT_SECOND, 1)
    comp.runs = comp.runs + 1
    comp.state = 0
    return
  end
end

return comp
