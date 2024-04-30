-- 总流程部分
scene.setenv({
    grid = 'plane'
})

require('agent')
require('agv')


print()
local agv = AGV()

-- move
agv:addtask('move2', {0, 0, 10})
agv:addtask('move2', {10, 0, 10})
-- agv:addtask('move2', {10, 0, 0})
agv:addtask('move2', {10, 10, 10})
agv:addtask('move2', {0, 0, 0})

-- waitoperator
local fakermg = {type = 'rmg'}
agv:addtask('waitoperator', {operator = fakermg})
function setoperator()
    agv.operator = nil
    coroutine.queue(0, agv.execute, agv) -- 通知agv
    print('运行setoperator at', coroutine.qtime())
end
coroutine.queue(8, setoperator)

-- moveon
-- local road = Road()

-- 独立刷新的绘图协程
require('watchdog')
local simv = 3
local ActionObjs = {agv}

local watchdog = WatchDog(simv, ActionObjs)
watchdog.refresh()
