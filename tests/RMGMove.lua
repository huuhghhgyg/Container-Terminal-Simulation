-- 仿真流程部分
scene.setenv({
    grid = 'plane'
})

local actionObjs = {}
local simv = 1

require('rmg')

local rmg = RMG()
rmg:addtask('move2', {0, 0, 20})
rmg:addtask('move2', {0, 10, 20})
rmg:addtask('move2', {-10, 10, 20})
rmg:addtask('move2', {0, 0, 0})

table.insert(actionObjs, rmg)

require('watchdog')
local watchdog = WatchDog(simv, actionObjs)
watchdog.update()