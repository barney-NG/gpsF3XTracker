--[[#############################################################################
COURSE Library:
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
functions: ---------------------------------------------------------------------
course.init
    initializes class internal variables
    special: course length and cardinal direction of course   
course.update
    input gps bearing and distance of an object to the center of the course
    if available acceleration perpenticular to movement vector of the object (there are many sensors which deliver ax/ay/az)
################################################################################]]
-- minimal competition class needed by the course class
local dummy_competition = {leftBaseIn=0, leftBaseOut=0, rightBaseIn=0, rightBaseOut=0}
--[[
function dummy_competition.leftBaseIn(timestamp) 
    print("leftBaseIn")
end
function dummy_competition.leftBaseOut(timestamp) 
    print("leftBaseOut")
    playTone(800,300,0,PLAY_NOW)
end
function dummy_competition.rightBaseIn(timestamp) 
    print("rightBaseIn")
end
function dummy_competition.rightBaseOut(timestamp) 
    print("rightBaseOut")
    playTone(800,300,0,PLAY_NOW)
end
]]
local course = {direction=0., length=50., az_max=3.0, lastDistance=0, lastGroundSpeed=0, message = ''}

function course.init(courseLength, courseDirection, competition)
    course.length = courseLength or 50. -- this is indeed half of the course length
    course.direction = courseDirection or 0. -- direction of course in rad. axis from left to right base
    course.comp = competition or dummy_competition -- the competition class 
    course.screen = screen or nil
    course.line = line or 0
    course.az_max = 5.0 -- G-limit, when gps sensor starts to get inaccurate
    course.leftOutside = false -- object is left from outside
    course.leftInside = false -- object moved from left outside to left inside
    course.rightOutside = false -- object is right outside
    course.rightInside = false -- object moved from right outside to right inside
    course.Distance = 0. -- distance measured from the center between the bases. (negative to left, positive to right)
    course.delta = 0. -- object movement in this timestep
    course.lastDistance = 0. -- last valid distance (gps)
    course.lastGroundSpeed = 0 -- last valid groundspeed (gps)
    course.lastDelta = 0. -- last valid movement.
    course.lastTimestamp = 0 -- timestamp for last valid gps measurement
    course.no_movements = 0 -- debugging
    course.useCorrection = false -- use the lookahead function  
	course.correctionFactor = 0.1  -- empiric value (F. Schreiber)
    course.text = ''
end
function course.output(text)
    -- course.message = text
    print(text)
end    
function course.update(distance, bearing, groundspeed, acceleration)
    -- distance: gps distance from center of course to object [m]
    -- bearing: gps angle from center of course to object [rad]
    -- groundspeed: unit must be [m/s]. (SM modellbau gps groundspeed gives km/h by default)
    -- accelleration: accel in local object z axis direction (needs to be mapped to correct physical unit [m/s**2])
    local az = acceleration or 0.
    local timestamp = getTime() * 10 -- timestamp in milliseconds
    -- are gps values valid?
    if az < course.az_max then
        -- map actual home -> object vector onto course vector
        local deltaBearing = bearing - course.direction
        if deltaBearing < 0. then
            deltaBearing = 2*math.pi + deltaBearing
        end
        course.Distance = distance * math.cos(deltaBearing)
        course.delta = course.Distance - course.lastDistance
        -- save last valid gps status
        course.lastDistance = course.Distance
        course.lastGroundSpeed = groundspeed
        course.lastTimestamp = timestamp
        course.lastDelta = course.delta
    else
        -- if accelleration is too high the gps sensor will become inaccurate (unusable)
        -- assume object speed remains constant and acceleration is always perpendicular on the speed vector
        -- the object will move on a circle with radius R ~= |V|, w ~= az/V and x(t) ~= x0 + R * cos(w*t)
        -- TODO: maybe there is a hysteresis needed. (start > 2;  end < 1)
        local dt = (timestamp - course.lastTimestamp) / 1000.0 -- delta t in seconds
        local w = 2*math.pi * az/course.lastGroundSpeed
        course.delta = course.lastGroundSpeed * math.cos(w*dt)
        -- continue in last valid direction
        if course.lastDelta < 0 then
            course.delta = -course.delta 
        end
        -- estimate the distance by v0 and acceleration only
        course.Distance = course.lastDistance + course.delta  
        -- print(string.format("az-mode: az:%6.2f delta:%6.2f dist:%6.2f", az, course.delta, course.Distance))
    end
    -- evaluate only if object is moving
    if math.abs(course.delta) > 0.0 then
        course.no_movements = 0
        -- print("distance: ", course.Distance)
		local estimatedDistance = math.abs(course.Distance)
        local estimatedOutsideDistance = math.abs(course.Distance)
        -- use the Schreibersche distance estimation 
        if course.useCorrection then
            estimatedDistance = estimatedDistance + course.correctionFactor * groundspeed
			estimatedOutsideDistance = estimatedOutsideDistance - course.correctionFactor * groundspeed          
        end
        if course.Distance < 0 then
            -- the object is left from the course center
            -- ...moving left (delta < 0) from inside left -> outside 
            if course.delta < 0. and estimatedDistance >= course.length and course.leftOutside == false  then
                course.leftOutside = true
                course.output(string.format("leftOutside: %-4.1f", course.Distance))
                course.comp.leftBaseOut =timestamp
                course.leftInside = false
            end
            -- ...moving right (delta > 0) from outside left -> inside
            if course.delta > 0. and estimatedOutsideDistance <= course.length and course.leftOutside == true and course.leftInside == false then
                course.leftInside = true
                course.output(string.format("leftInside:   %-4.1f", course.Distance))
                course.comp.leftBaseIn = timestamp
                course.leftOutside = false
                -- course.startLeft = false
            end
        else
            -- the object is right from the course center
            -- ...moving right (delta > 0) from inside right -> outside
            if course.delta > 0. and estimatedDistance >= course.length and course.rightOutside == false  then
                course.rightOutside = true
                course.output(string.format("rightOutside: %-4.1f", course.Distance))
                course.comp.rightBaseOut = timestamp
                course.rightInside = false
            end
            -- ...moving left (delta < 0) from outside right -> inside
            if course.delta < 0. and estimatedOutsideDistance <= course.length and course.rightOutside == true and course.rightInside == false then
                course.rightInside = true
                course.output(string.format("rightInside:   %-4.1f", course.Distance))
                course.comp.rightBaseIn = timestamp                
                course.rightOutside = false
            end
        end
        -- enable detection if object is inside course
        if math.abs(course.Distance) < course.length then
            course.leftOutside = false
            course.rightOutside = false
        end
    else
        course.no_movements = course.no_movements + 1 -- needed for debugging
    end
end

return course
