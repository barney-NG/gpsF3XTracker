-- this are the locations shown by the program
-- you may add your own locations and remove the unused ones
-- please do not remove the first entry!
-- type 1: f3f training
-- type 2: f3f complett
-- type 3: f3b distance
-- type 4: f3b speed
-- type 5: f3f debug
local locations = {
    {name = 'Use "Live" Position and Direction', lat = 0.0, lon = 0.0, dir = 0.0, comp = 1},
    {name = "Parkplatz", lat=53.550707, lon=9.923472,dir = 9,0, comp = 5},
    {name = "Loechle", lat = 47.701974, lon = 8.3558498, dir = 152.0, comp = 1},
    {name = "Soenderborg", lat = 53.333333, lon = 51.987654, dir = 19.9, comp = 3},
    {name = "Toftum Bjerge", lat = 56.5422283333, lon = 8.52163166667, dir = 244.0, comp = 1},
    {name = "Last Entry", lat = 53.555555, lon = 51.987654, dir = 10.9, comp = 3}
}
return locations