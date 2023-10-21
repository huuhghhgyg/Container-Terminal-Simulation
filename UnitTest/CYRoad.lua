scene.setenv({
    grid = 'plane'
})

require('road')
require('cy')

local RoadList = {}

local road = Road({-20, 0, -30}, {-10, 0, 50}, RoadList)
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)

print('road vecE=(', road.vecE[1], ',', road.vecE[2], ',', road.vecE[3], ')')

cy:bindRoad(road)

-- 显示cy.parkingSpaces的位置
for k, v in ipairs(cy.parkingSpaces) do
    local x, y, z = road:getRelativePosition(v.relativeDist)

    -- 显示位置
    scene.addobj('points', {
        vertices = {x, y, z},
        color = 'red',
        size = 5
    })
    local pointLabel = scene.addobj('label', {
        text = 'no.' .. k
    })
    pointLabel:setpos(x, y, z)

    -- print('cy debug: set parking space at (', x, ',', y, ',', z, ')')
    print('cy debug: parking space', k, ' iox = ', cy.parkingSpaces[k].iox)
end

scene.render()
