scene.setenv({
    grid = 'plane'
})

local ActionObjs = {}
local simv = 2

require('agent')
require('rmgqc')
local rmgqc = RMGQC()
-- rmgqc:move2(0, 0, 10)
-- rmgqc:move2(0, 10, 0)
-- rmgqc:move2(-20, 0, 0)
-- rmgqc:setpos(-20,0,0)

rmgqc:addtask('move2',{0, 0, 10})
rmgqc:addtask('move2',{0, 10, 10})
rmgqc:addtask('move2',{-20, 10, 10})
rmgqc:addtask('move2',{0, 0, 0})

table.insert(ActionObjs, rmgqc)

require('watchdog')
local watchdog = WatchDog(simv, ActionObjs)

-- 1.下载函数库到虚拟磁盘
print('正在下载依赖库到虚拟磁盘...')
os.upload('https://www.zhhuu.top/ModelResource/libs/setpoint.lua')
print('下载完成')
-- 2.引用库
require('setpoint')
setpoint(0,0,10)
setpoint(0, 10, 10)
setpoint(-20, 10, 10)
setpoint(0,0,0,{text='origin'})

scene.render()

watchdog:refresh()