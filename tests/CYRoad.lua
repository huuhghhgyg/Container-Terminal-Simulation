scene.setenv({
    grid = 'plane'
})

require('road')
require('cy')

local RoadList = {}

local road = Road({-20, 0, -30}, {-10, 0, 80}, RoadList)
local cy = CY(5, 10, 3)

print('road vecE=(', road.vecE[1], ',', road.vecE[2], ',', road.vecE[3], ')')

cy:bindRoad(road)
cy:showBindingPoint()

cy:fillAllContainerPositions()

scene.render()

for k, v in ipairs(cy.parkingSpaces) do
    print('bay', k, ' iox=', v.iox)
end
