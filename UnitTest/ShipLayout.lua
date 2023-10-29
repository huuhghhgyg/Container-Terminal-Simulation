scene.setenv({
    grid = 'plane'
})

require('ship')

local shipSize = {8, 9, 2}
local shipOrigin = {0, 0, 0}

local ship = Ship(shipSize, shipOrigin)

scene.render()

-- 填充集装箱
local containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                       '/res/ct/container_yellow.glb'}
local shipIdleContainerPosition = ship:getIdlePosition()
while shipIdleContainerPosition do
    local containerUrl = containerUrls[math.random(#containerUrls)]
    local cbay, crow, clevel = table.unpack(shipIdleContainerPosition)
    local container = scene.addobj(containerUrl)
    container:setpos(table.unpack(ship.containerPositions[cbay][crow][clevel]))
    ship.containers[cbay][crow][clevel] = container
    -- 获取空闲集装箱位置
    shipIdleContainerPosition = ship:getIdlePosition()
end

scene.render()