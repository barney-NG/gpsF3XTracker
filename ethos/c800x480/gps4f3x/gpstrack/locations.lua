--[[#############################################################################
LOCATION Library: GPS F3X Tracker for Ethos v1.1

These are the locations shown by the program
You may add your own locations and remove the unused ones, program supports at this moment max 15 locations
Please do not remove the first entry!

Change log:
- v1.1: - the table enhanced by "dif" item, which modifies default course length (F3F 100m, F3B 150m), +: course is longer, -: course is shorter

-- type 1: f3f training
-- type 2: f3f competition
-- type 3: f3b distance
-- type 4: f3b speed
-- type 5: f3f debug
]]
local locations = {
    {name = '"Live" Position & Direction', lat = 0.0, lon = 0.0, dir = 0.0, dif = 20, comp = 1},
    {name = "Parkplatz", lat=53.550707, lon=9.923472,dir = 9.0, dif = 0, comp = 5},
    {name = "Loechle", lat = 47.701974, lon = 8.3558498, dir = 152.0, dif = 10, comp = 2},
    {name = "Soenderborg", lat = 53.333333, lon = 51.987654, dir = 19.9, dif = 0, comp = 3},
    {name = "Toftum Bjerge", lat = 56.5422283333, lon = 8.52163166667, dir = 244.0, dif = -10, comp = 1},
    {name = "Last Entry", lat = 53.555555, lon = 51.987654, dir = 10.9, dif = 0, comp = 4}
}

return locations