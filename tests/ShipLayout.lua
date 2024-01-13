scene.setenv({
    grid = 'plane'
})

require('ship')
local ship = Ship({origin = {10,0,-20}})

local originPoint = scene.addobj('points', {
    vertices = {table.unpack(ship.origin)},
    size = 10,
    color = 'blue'
})
local acrPoint = scene.addobj('points', {
    vertices = {table.unpack(ship.anchorPoint)},
    size = 10,
    color = 'red'
})

scene.render()

-- 填充集装箱(使用fillAllContainerPositions)
-- ship:fillAllContainerPositions()
ship:fillRandomContainerPositions(60)

print('getIdlePosition:', table.unpack(ship:getIdlePosition()))

scene.render()