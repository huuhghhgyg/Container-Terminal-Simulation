require('agent')
require('rmgqc')
require('ship')
require('road')
require('agv')
require('watchdog')
print()

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 2 -- 仿真速度
local ActionObjs = {} -- 动作队列声明
local RoadList = {} -- 道路列表

-- 创建对象
-- local rmgqc = RMGQC({-16, 0, 130})
local rmgqc = RMGQC({actionObjs = ActionObjs})
local ship = Ship({anchorPoint = rmgqc.berthPosition})
local road = Road({0,0,0}, {0,0,60}, RoadList)

-- ship填充集装箱
ship:fillAllContainerPositions()

-- 绑定Ship
rmgqc:bindRoad(road) -- 先绑定road
rmgqc:bindStack(ship) -- 再绑定stack
rmgqc:showBindingPoint()

-- 添加任务
local target1 = {3, 4, 2}
rmgqc:addtask("move2", rmgqc:getContainerCoord(-1, target1[1], #rmgqc.stack.levelPos)) -- 初始化位置

-- 单个任务
local bay, row, level = 3, 4, 2

-- 添加目标agv
local agv = AGV()
local ax, _, az = table.unpack(rmgqc:getContainerCoord(-1, bay, 1))
agv:setpos(ax, 0, az)
rmgqc.agentqueue = {agv}
agv:addtask('waitoperator', {operator = rmgqc})
-- agv:addtask('register', {
--     operator = rmgqc, 
--     f = function() 
--         agv.targetContainerPos = {bay, row, level}
--         agv.taskType = 'unload'
--     end
-- })
-- agv:addtask('waitoperator', {operator = rmgqc})
table.insert(ActionObjs, agv)

-- 取下1
rmgqc:addtask("move2", rmgqc:getContainerCoord(row, bay, #rmgqc.stack.levelPos))
rmgqc:addtask("move2", rmgqc:getContainerCoord(row, bay, level)) -- 移动爪子到指定位置
rmgqc:addtask("attach", {row, bay, level}) -- 抓取
rmgqc:addtask("move2", rmgqc:getContainerCoord(row, bay, #rmgqc.stack.levelPos)) -- 吊具提升到移动层
rmgqc:addtask("move2", rmgqc:getContainerCoord(-1, bay, #rmgqc.stack.levelPos)) -- 移动爪子到agv上方
-- rmgqc:addtask("waitagv") -- 等待agv到达
rmgqc:addtask("move2", rmgqc:getContainerCoord(-1, bay, 1)) -- 移动爪子到agv
rmgqc:addtask("detach", nil) -- 放下指定箱
rmgqc:addtask("move2", rmgqc:getContainerCoord(-1, bay, #rmgqc.stack.levelPos)) -- 爪子抬起到移动层

-- 取下
-- rmgqc:move2TargetPos(row, bay)
-- rmgqc:lift2Agent(row, bay, level, agv)
-- 装载
-- rmgqc:move2Agent(bay)
-- rmgqc:lift2TargetPos(row, bay, level, agv)

-- 开始仿真
local watchdog = WatchDog(simv, ActionObjs)
watchdog:refresh()