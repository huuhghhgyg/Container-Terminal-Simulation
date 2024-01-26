-- 总流程部分
scene.setenv({
    grid = 'plane'
})

require('agent')
require('agv2')

print()
local agv = AGV()

-- move
-- agv:addtask('move2', {0, 0, 10})
-- agv:addtask('move2', {10, 0, 10})
-- -- agv:addtask('move2', {10, 0, 0})
-- agv:addtask('move2', {10, 10, 10})
-- agv:addtask('move2', {0, 0, 0})

-- waitoperator
-- local fakermg = {type = 'rmg'}
-- agv:addtask('waitoperator', {operator = fakermg})
-- function setoperator()
--     agv.operator = nil
-- end
-- coroutine.qtime(30, setoperator)

-- moveon
local road = Road()

-- 独立刷新的绘图协程
require('watchdog')
local simv = 1
local ActionObjs = {agv}

local watchdog = WatchDog(simv, ActionObjs)
watchdog:refresh()
