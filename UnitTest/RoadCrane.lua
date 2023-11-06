require('agv')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 2 -- 仿真速度
local ActionObjs = {} -- 动作队列声明

require('road')
require('cy')
require('rmg')
require('watchdog')

-- 创建道路系统
local RoadList = {} -- 道路列表

-- 创建对象
local cy1 = CY({-19.66 / 2, -51.49 / 2}, {19.66 / 2, 51.49 / 2}, 3) -- 创建堆场
local road1 = Road({-15, 0, -50}, {-15, 0, 50}, RoadList) -- 创建道路

-- 绑定道路
cy1:bindRoad(road1)
cy1:showBindingPoint()

cy1:fillAllContainerPositions()

local rmg1 = RMG(cy1, ActionObjs) -- 创建rmg

scene.render()

-- 仿真任务
local target = {2, 5, 3}
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)}) 
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 3)})
-- rmg1:addtask({'attach', {3, 2, 3}})
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)})
-- rmg1:addtask({'move2', rmg1:getContainerCoord(2, -1, 1)})

-- 添加假agv用于进行单元测试
local fakeAgv = { arrived = true }
rmg1.agvqueue[1] = fakeAgv
rmg1.agvqueue[2] = fakeAgv

rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, rmg1.toplevel)}) -- 初始化位置
-- 取出
rmg1:move2TargetPos(target[1], target[2])
rmg1:lift2Agv(table.unpack(target))
-- 存放
rmg1:move2Agv(target[1])
rmg1:lift2TargetPos(table.unpack(target))

-- 开始仿真
-- update()
local watchdog = WatchDog(simv, ActionObjs)
watchdog:update()
