--[[#############################################################################
GPS Library: GPS F3X Tracker for Ethos v1.3

Copyright (c) 2024 Axel Barnitzke - original code for OpenTx          MIT License
Copyright (c) 2024 Milan Repik - porting to FrSky Ethos               MIT License

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

functions:
point = gps.newPoint(lat, lon)
distance = gps.getDistance(point, point2)
bearing = gps.getBearing(point1, point2)

Change log:
- v1.1: - 
- v1.2: - 
- v1.3: - some small optimizations
################################################################################]]

-- Meta class "gps"
gps = {}
local gps_meta = {lat=0., lon=0.}

function gps.newPoint( lat, lon )                           -- fast function to get a gps point, not invoking any checks
  return setmetatable( { lat=lat, lon=lon }, gps_meta )
end

function gps.getValue( point )                              -- return lat and lon of a given gps point
  return point.lat, point.lon
end

function gps.getBearing(p1,p2)                              -- Returns the angle in degrees between two GPS positions, p1 = startPoint, p2 = endPoint
                                                            -- Latitude and Longitude in decimal degrees, E.g. 40.1234, -75.4523342
                                                            -- http://www.igismap.com/formula-to-find-bearing-or-heading-angle-between-two-points-latitude-longitude/
                                                            -- spherical earth
  local phi1 = math.rad(p1.lat)
  local phi2 = math.rad(p2.lat)
  local dphi = math.rad(p2.lon-p1.lon)
  local X =  math.cos(phi2) * math.sin(dphi)
  local Y = (math.cos(phi1) * math.sin(phi2)) - (math.sin(phi1) * math.cos(phi2) * math.cos(dphi))
--  local bearing_rad = math.atan2(math.rad(X), math.rad(Y))                                               !!! atan2 function is deprecated as of LUA release 5.3 !!!
  local bearing_rad = math.atan(math.rad(X), math.rad(Y))
    --]]
     --[[ Flat-Earth math
     local x = (p2.lon - p1.lon) * math.cos(math.rad(p1.lat))
     local bearing_rad =  1.5708 - math.atan2(p2.lat - p1.lat, x)
    --]]
  if bearing_rad < 0. then
    bearing_rad = math.pi + math.pi + bearing_rad
  end
  return bearing_rad
end

function gps.getDistance(p1, p2)                            -- Returns distance in meters between two GPS positions
                                                            -- Latitude and Longitude in decimal degrees, E.g. 40.1234, -75.4523342
                                                            -- http://www.movable-type.co.uk/scripts/latlong.html
  local R = 6371000.                                        -- radius of the earth in meters
  local phi1 = math.rad(p1.lat)
  local phi2 = math.rad(p2.lat)
  local dphi = math.rad(p2.lat-p1.lat)
  local dLambda = math.rad(p2.lon-p1.lon)
  local a = math.sin(dphi/2.)^2 + math.cos(phi1) * math.cos(phi2) * math.sin(dLambda/2.)^2
--  local c = 2. * math.atan2(math.sqrt(a), math.sqrt(1.-a))                                               !!! atan2 function is deprecated as of LUA release 5.3 !!!
  local c = 2. * math.atan(math.sqrt(a), math.sqrt(1.-a))
  
  return R * c                                              -- distance = R * c
end

gps_meta.__eq = function( cx1,cx2 )
  if cx1.lat == cx2.lat and cx1.lon == cx2.lon then
    return true
  end
  return false
end

function gps.getDestination(fromCoord, distance_m, bearingDegrees)    -- develops a new point from distance and bearing
  local distanceRadians = distance_m / 6371000.0
  local bearingRadians = math.rad(bearingDegrees)
  local fromLatRadians = math.rad(fromCoord.lat)
  local fromLonRadians = math.rad(fromCoord.lon)
  local toLatRadians = math.asin(math.sin(fromLatRadians) * math.cos(distanceRadians) +
                                    math.cos(fromLatRadians) * math.sin(distanceRadians) * math.cos(bearingRadians))
  local toLonRadians = fromLonRadians + math.atan(math.sin(bearingRadians) * math.sin(distanceRadians) * math.cos(fromLatRadians),
                                                     math.cos(distanceRadians) - math.sin(fromLatRadians) * math.sin(toLatRadians))  -- !!! atan2 function is deprecated as of LUA release 5.3 !!!
    -- TODO: adjust toLonRadians to be in the range -pi to +pi...
  return {lat=math.deg(toLatRadians), lon=math.deg(toLonRadians)}
end

return gps