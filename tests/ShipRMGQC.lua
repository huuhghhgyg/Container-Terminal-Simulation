require('rmgqc')
require('ship')
require('road')
require('watchdog')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 8 -- 仿真速度
local ActionObjs = {} -- 动作队列声明
local RoadList = {} -- 道路列表

-- 创建对象
-- local rmgqc = RMGQC({-16, 0, 130})
local rmgqc = RMGQC({0, 0, 0}, ActionObjs)
local ship = Ship({8, 9, 2}, rmgqc.berthPosition)
local road = Road({0,0,-60}, {0,0,60}, RoadList)
rmgqc:bindRoad(road)

-- ship填充集装箱
ship:fillAllContainerPositions()

-- 绑定Ship
rmgqc:bindShip(ship)

-- 添加任务
local target1 = {3, 4, 2}
rmgqc:addtask("move2", rmgqc:getContainerCoord(target1[1], -1, rmgqc.toplevel)) -- 初始化位置

-- 单个任务
local bay, row, level = 3, 4, 2
-- 取下1
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel))
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, level)) -- 移动爪子到指定位置
rmgqc:addtask("attach", {bay, row, level}) -- 抓取
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, row, rmgqc.toplevel)) -- 吊具提升到移动层
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel)) -- 移动爪子到agv上方
-- rmgqc:addtask("waitagv") -- 等待agv到达
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, 1)) -- 移动爪子到agv
rmgqc:addtask("detach", nil) -- 放下指定箱
rmgqc:addtask("move2", rmgqc:getContainerCoord(bay, -1, rmgqc.toplevel)) -- 爪子抬起到移动层

-- 集成任务
-- -- 添加fakeAgv
-- local fakeAgv = {
--     arrived = true,
--     taskType = 'load',
--     occupier = rmgqc,
--     id = 1,
--     type = 'agv',
--     contaienr = {}
-- }

-- -- 取下
-- rmgqc:move2TargetPos(bay, row)
-- rmgqc:lift2Agent(bay, row, level, fakeAgv)
-- -- 装载
-- -- rmgqc:move2Agent(bay)
-- -- rmgqc:lift2TargetPos(bay, row, level, fakeAgv)

-- rmgqc.agentqueue[1] = fakeAgv -- 测试时注入fakeAgv（只能支持同时测试一个任务）

-- 开始仿真
local watchdog = WatchDog(simv, ActionObjs)
watchdog:update()