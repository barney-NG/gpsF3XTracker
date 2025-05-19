--[[#############################################################################
LOCATION Library: GPS F3X Tracker for Ethos v1.3

These are the locations shown by the program
You may add your own locations and remove the unused ones, program supports at this moment max 15 locations
!!! For proper function please keep format of the table as it is !!! 
!!! Please do not remove the first entry !!!
!!! Please do not remove the last entry and keep its name as "New Entry" (create new sites before that item)

Change log:
- v1.1: - the table enhanced by "dif" item, which modifies default course length (F3F 100m, F3B 150m), +: course is longer, -: course is shorter
- v1.2:
- v1.3: - the table enhanced by "New Entry" site as placeholder for a new site created from "Live Position & Direction" site

-- type 1: f3f training
-- type 2: f3f competition
-- type 3: f3b distance
-- type 4: f3b speed
-- type 5: f3f debug
]]
local locations = {
    {name = "Live Position & Direction", lat = 0.0, lon = 0.0, dir = 0.0, dif = 0, comp = 1},
    {name = "Debug", lat = 53.550707, lon = 9.923472,dir = 9.0, dif = 20, comp = 5},
    {name = "Loechle", lat = 47.701974, lon = 8.3558498, dir = 152.0, dif = 10, comp = 2},
    {name = "F3B Distance site", lat = 53.333333, lon = 51.987654, dir = 19.9, dif = 0, comp = 3},
    {name = "Toftum Bjerge", lat = 56.542000, lon =  8.521000, dir = 244.0, dif = -7, comp = 1},
    {name = "F3B Speed site", lat = 53.555555, lon = 51.987654, dir = 10.9, dif = 0, comp = 4},
    {name = "Trutnov", lat = 51.234567, lon = 15.678901, dir =  10.0, dif = 40, comp = 2},
    {name = "Test site", lat = 31.212000, lon = 121.400000, dir =   0.2, dif = 25, comp = 1},
    {name = "Last Entry", lat = 0.0, lon = 0.0, dir = 0.0, dif = 0, comp = 1}
}
return locations
