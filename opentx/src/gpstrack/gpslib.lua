--[[#############################################################################
GPS Library:

functions: ---------------------------------------------------------------------
point = gps.newPoint(lat, lon)
distance = gps.getDistance(point, point2)
bearing = gps.getBearing(point1, point2)
################################################################################]]

-- Meta class "gps"
gps = {}
local gps_meta = {lat=0., lon=0.}

-- Functions
function gps.newPoint( lat, lon )
    -- fast function to get a gps point, not invoking any checks
    return setmetatable( { lat=lat, lon=lon }, gps_meta )
end
function gps.getValue( point )
    -- return lat and lon of a given gps point
    return point.lat, point.lon
end
function gps.getBearing(p1,p2)
    -- gps.getBearing(startPoint, endPoint)
    -- Returns the angle in degrees between two GPS positions
    -- Latitude and Longitude in decimal degrees
    -- E.g. 40.1234, -75.4523342
    -- http://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
    
    local phi1 = math.rad(p1.lat)
    local phi2 = math.rad(p2.lat)
    local dphi = math.rad(p2.lon-p1.lon)
    local X =  math.cos(phi2) * math.sin(dphi)
    local Y = (math.cos(phi1) * math.sin(phi2)) 
            - (math.sin(phi1) * math.cos(phi2) * math.cos(dphi))
    local bearing = math.atan2(math.rad(X), math.rad(Y))
    
    if bearing < 0. then
        bearing = math.pi + math.pi + bearing
    end
    return bearing
end
function gps.getDistance(p1, p2)
    -- gps.getDistance(gpsPoint1, gpsPoint2)
    -- Returns distance in meters between two GPS positions
    -- Latitude and Longitude in decimal degrees
    -- E.g. 40.1234, -75.4523342
    -- http://www.movable-type.co.uk/scripts/latlong.html

    local R = 6371000.  -- radius of the earth in meters
    local phi1 = math.rad(p1.lat)
    local phi2 = math.rad(p2.lat)
    local dphi = math.rad(p2.lat-p1.lat)
    local dLambda = math.rad(p2.lon-p1.lon)
    local a = math.pow(math.sin(dphi/2.),2) + math.cos(phi1) * math.cos(phi2) * math.pow(math.sin(dLambda/2.),2)
    local c = 2. * math.atan2(math.sqrt(a), math.sqrt(1.-a))
  
    -- distance = R * c
    return R * c
  end

  gps_meta.__eq = function( cx1,cx2 )
    if cx1.lat == cx2.lat and cx1.lon == cx2.lon then
       return true
    end
    return false
 end

function gps.getDestination(fromCoord, distance_m, bearingDegrees)
    -- develope a new point from distance and bearing
    local distanceRadians = distance_m / 6371000.0
    local bearingRadians = math.rad(bearingDegrees)
    local fromLatRadians = math.rad(fromCoord.lat)
    local fromLonRadians = math.rad(fromCoord.lon)
    local toLatRadians = math.asin(math.sin(fromLatRadians) * math.cos(distanceRadians) +
                                    math.cos(fromLatRadians) * math.sin(distanceRadians) * math.cos(bearingRadians))
    local toLonRadians = fromLonRadians + math.atan2(math.sin(bearingRadians) * math.sin(distanceRadians) * math.cos(fromLatRadians),
                                                     math.cos(distanceRadians) - math.sin(fromLatRadians) * math.sin(toLatRadians))
    -- TODO: adjust toLonRadians to be in the range -pi to +pi...
    return {lat=math.deg(toLatRadians), lon=math.deg(toLonRadians)}
 end

--[[
 ufer = gps.newPoint(53.544391120481784, 9.894426479472363)
 sueden = gps.newPoint(53.539606847026164, 9.894723296744695)
 norden =gps.newPoint(53.5506297062015, 9.895094318335113)
 westen =gps.newPoint(53.54469976471789, 9.883110320964665)
 osten =gps.newPoint(53.54467771877567, 9.90359071275565)
 
 wnorden = gps.getBearing(ufer,norden)
 print("norden: ", math.deg(wnorden))
 wosten = gps.getBearing(ufer,osten)
 print("osten:   ", math.deg(wosten))
 wsueden = gps.getBearing(ufer,sueden)
 print("sueden: ", math.deg(wsueden))
 wwesten = gps.getBearing(ufer,westen)
 print("westen: ", math.deg(wwesten))

 offs = gps.getDestination(ufer, 100, 271.0)

 print("offs: ", offs.lat, offs.lon)
 ]]

 return gps