--[[#############################################################################
COURSE Library: GPS F3X Tracker for Ethos v1.3

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

You can use this library for a course with 2 bases. There is one center and one base at the left and one base at the right of the center.
The center is exacly in the middle between the two bases. (This makes direction estimation much easier)
This library creates 4 events (realised as external function calls to the class competition): 
correction -- I set competition.rightBaseOut = timestamp (better approach in single threaded environment)
    1. the object leaves the course from center over the right base
        competition.rightBaseOut(timestamp)
    2. the object enters the course from outsight over the right base in direction center
        competition.rightBaseIn(timestamp)
    3. the object leaves the course from center over the left base
        competition.leftBaseOut(timestamp) 
    4. the object enters the course from outsight over the left base in direction center
        competition.leftBaseIn(timestamp)
functions:
course.init
    initializes class internal variables
    special: course length and cardinal direction of course   
course.update
    input gps bearing and distance of an object to the center of the course
    if available acceleration perpenticular to movement vector of the object (there are many sensors which deliver ax/ay/az)
    
Change log:
- v1.1: - 
- v1.2: - 
- v1.3: - some small optimizations
################################################################################]]

local course = {direction=0., length=50., az_max=3.0, lastDistance=0, lastGroundSpeed=0, message = ''}

function course.init(courseLength, courseDirection, competition)      -- initializes class internal variables
  course.length = courseLength or 50.                       -- this is indeed half of the course length
  course.direction = courseDirection or 0.                  -- direction of course in rad. axis from left to right base
  course.comp = competition                                 -- the competition class 
  course.az_max = 5.0                                       -- G-limit, when gps sensor starts to get inaccurate
  course.leftOutside = false                                -- object is left from outside
  course.leftInside = false                                 -- object moved from left outside to left inside
  course.rightOutside = false                               -- object is right outside
  course.rightInside = false                                -- object moved from right outside to right inside
  course.Distance = 0.                                      -- distance measured from the center between the bases. (negative to left, positive to right)
  course.delta = 0.                                         -- object movement in this timestep
  course.lastDistance = 0.                                  -- last valid distance (gps)
  course.lastGroundSpeed = 0                                -- last valid groundspeed (gps)
  course.lastDelta = 0.                                     -- last valid movement.
  course.lastTimestamp = 0                                  -- timestamp for last valid gps measurement
  course.no_movements = 0                                   -- debugging
  course.useCorrection = false                              -- use the lookahead function  
	course.correctionFactor = 0.1                             -- empiric value (F. Schreiber)
  course.text = ''
end

function course.output(text)
  course.message = text
--  print("<<< " .. text)
end

function course.update(distance, bearing, groundspeed, acceleration)
                              -- distance: gps distance from center of course to object [m]
                              -- bearing: gps angle from center of course to object [rad]
                              -- groundspeed: unit must be [m/s]. (SM modellbau gps groundspeed gives km/h, sensor.gpsSpeed() recalculates it)
                              -- accelleration: accel in local object z axis direction (needs to be mapped to correct physical unit [m/s**2])
  local az = acceleration or 0.
  local timestamp = getETime()
  if az < course.az_max then                                -- is value of GPS az sensor bellow the set limit?
    local deltaBearing = bearing - course.direction         -- map actual home -> object vector onto course vector
    if deltaBearing < 0. then
      deltaBearing = 2*math.pi + deltaBearing
    end
    course.Distance = distance * math.cos(deltaBearing)     -- calculate projection of flown distance into the course (no difference between course and flight means it is 1:1)
    course.delta = course.Distance - course.lastDistance
    course.lastDistance = course.Distance                   -- save last valid gps status
    course.lastGroundSpeed = groundspeed
    course.lastTimestamp = timestamp
    course.lastDelta = course.delta
  else                        -- if accelleration is too high the gps sensor will become inaccurate (unusable)
                              -- assume object speed remains constant and acceleration is always perpendicular on the speed vector
                              -- the object will move on a circle with radius R ~= |V|, w ~= az/V and x(t) ~= x0 + R * cos(w*t)
                                                            -- TODO: maybe there is a hysteresis needed. (start > 2;  end < 1)
    local dt = (timestamp - course.lastTimestamp) / 1000.0  -- delta t in seconds
    local w = 2*math.pi * az/course.lastGroundSpeed
    course.delta = course.lastGroundSpeed * math.cos(w*dt)
    if course.lastDelta < 0 then                            -- continue in last valid direction
      course.delta = -course.delta 
    end
    course.Distance = course.lastDistance + course.delta    -- estimate the distance by v0 and acceleration only  
--    print(string.format("az-mode: az:%6.2f delta:%6.2f dist:%6.2f", az, course.delta, course.Distance))
  end

  if math.abs(course.delta) > 0.0 then                      -- evaluate only if object is moving
    course.no_movements = 0
		local estimatedDistance = math.abs(course.Distance)
    local estimatedOutsideDistance = estimatedDistance

    if estimatedDistance < 2 then                           -- check for center (it's just convenient to have this message)
      course.message = string.format("center: %-4.1f", course.Distance)
    else
      if string.find(course.message, "center:") then        -- plane has just passed center -> no information
        course.message = ''
      end
    end

    if course.useCorrection then                            -- use the Schreibersche distance estimation 
      estimatedDistance = estimatedDistance + course.correctionFactor * groundspeed
			estimatedOutsideDistance = estimatedOutsideDistance - course.correctionFactor * groundspeed          
    end
    if course.Distance < 0 then                             -- the object is left from the course center
      if course.delta < 0. and estimatedDistance >= course.length and course.leftOutside == false  then
        course.leftOutside = true                           -- . moving left (delta < 0) from inside left -> outside
        course.output(string.format("leftOutside: %-4.1f", course.Distance))
        course.comp.leftBaseOut =timestamp
        course.leftInside = false
      end
      if course.delta > 0. and estimatedOutsideDistance <= course.length and course.leftOutside == true and course.leftInside == false then
        course.leftInside = true                            -- . moving right (delta > 0) from outside left -> inside
        course.output(string.format("leftInside:   %-4.1f", course.Distance))
        course.comp.leftBaseIn = timestamp
        course.leftOutside = false
--        course.startLeft = false
      end
    else                                                    -- the object is right from the course center
      if course.delta > 0. and estimatedDistance >= course.length and course.rightOutside == false  then
        course.rightOutside = true                          -- .moving right (delta > 0) from inside right -> outside
        course.output(string.format("rightOutside: %-4.1f", course.Distance))
        course.comp.rightBaseOut = timestamp
        course.rightInside = false
      end
      if course.delta < 0. and estimatedOutsideDistance <= course.length and course.rightOutside == true and course.rightInside == false then
        course.rightInside = true                           -- . moving left (delta < 0) from outside right -> inside
        course.output(string.format("rightInside:   %-4.1f", course.Distance))
        course.comp.rightBaseIn = timestamp                
        course.rightOutside = false
      end
    end

    if math.abs(course.Distance) < course.length then       -- enable detection if object is inside course
      course.leftOutside = false
      course.rightOutside = false
    end
  else
    course.no_movements = course.no_movements + 1           -- needed for debugging
  end
end

return course
