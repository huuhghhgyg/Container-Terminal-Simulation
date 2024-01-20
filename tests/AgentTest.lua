-- 总流程部分
scene.setenv({
    grid = 'plane'
})

require('agent')

print()
local agent = Agent()
agent:addtask('move2', {0, 0, 10})
agent:addtask('move2', {10, 0, 10})
agent:addtask('move2', {10, 10, 10})
agent:addtask('move2', {0, 0, 0})

-- 独立刷新的绘图协程
require('watchdog')
local simv = 5
local ActionObjs = {agent}

local watchdog = WatchDog(simv, ActionObjs)
watchdog:refresh()
