require('rmgqc')
require('ship')
require('watchdog')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 2 -- 仿真速度
local ActionObjs = {} -- 动作队列声明

-- 创建对象
-- local rmgqc = RMGQC({-16, 0, 130})
local rmgqc = RMGQC({0, 0, 0})
local ship = Ship({8, 9, 2}, rmgqc.berthPosition)

-- ship填充集装箱
ship:fillAllContainerPositions()

-- 绑定Ship
rmgqc:bindShip(ship)

-- 添加任务
local target1 = {3, 4, 2}
rmgqc:addtask({"move2", rmgqc:getcontainercoord(target1[1], -1, rmgqc.toplevel)}) -- 初始化位置

-- 取下1
rmgqc:move2TargetPos(table.unpack(target1))
rmgqc:lift2Agv(table.unpack(target1))

-- 装载1
rmgqc:move2Agv(target1[1])
rmgqc:lift2TargetPos(table.unpack(target1))

-- 加入动作队列
table.insert(ActionObjs, rmgqc)

-- 开始仿真
local watchdog = WatchDog(simv, ActionObjs)
watchdog:update()