scene.setenv({
    grid = 'plane'
})

require('ship')

local shipSize = {8, 9, 2}
local shipOrigin = {0, 0, 0}

local ship = Ship(shipSize, shipOrigin)

scene.render()

-- 填充集装箱(使用IdlePosition)
local shipIdleContainerPosition = ship:getIdlePosition()
while shipIdleContainerPosition do
    -- 填充集装箱
    ship:fillWithContainer(table.unpack(shipIdleContainerPosition))
    -- 获取空闲集装箱位置
    shipIdleContainerPosition = ship:getIdlePosition()
end

-- 填充集装箱(使用fillAllContainerPositions)
-- ship:fillAllContainerPositions()

scene.render()