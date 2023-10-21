scene.setenv({
    grid = 'plane'
})

require('road')
require('cy')

local RoadList = {}

local road = Road({-20, 0, -30}, {-20, 0, 50}, RoadList)
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)

print('road vecE=(', road.vecE[1], ',', road.vecE[2], ',', road.vecE[3], ')')

cy:bindRoad(road)

scene.render()