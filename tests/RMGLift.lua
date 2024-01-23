-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用组件
require('agent')
require('cy')
require('rmg2')
require('agv2')
require('node')
require('road')

-- 参数设置
local simv = 2 -- 仿真速度
local ActionObjs = {} -- 动作队列声明

-- 仿真控制
require('watchdog')
local watchdog = WatchDog(simv, ActionObjs)

-- 创建道路系统
local RoadList = {} -- 道路列表
local NodeList = {} -- 节点列表

-- 创建节点
local node1 = Node({0, 0, -20}, NodeList)
local node2 = Node({0, 0, 80}, NodeList)
-- 创建道路
local rd1 = node1:createRoad(node2, RoadList)

-- 创建堆场
local cy = CY(5, 10, 3, {origin = {10, 0, 0}})
cy:bindRoad(rd1)
cy:showBindingPoint()
-- cy:fillRandomContainerPositions(50, {'/res/ct/container_blue.glb'})
cy:fillAllContainerPositions()

local rmg = RMG() -- 创建rmg时会自动添加到ActionObjs中
table.insert(ActionObjs, rmg)
rmg:bindStack(cy)

scene.render()

-- test1
rmg:addtask('move2', rmg:getContainerCoord(2, 3, 3))
rmg:addtask('attach', {2, 3, 3})
rmg:addtask('move2', rmg:getContainerCoord(2, 3, #cy.levelPos))
rmg:addtask('move2', rmg:getContainerCoord(-1, 6, #cy.levelPos))
rmg:addtask('move2', rmg:getContainerCoord(-1, 6, 1))
rmg:addtask('detach', nil)
rmg:addtask('move2', rmg:getContainerCoord(-1, 6, #cy.levelPos)) -- t=17.42, end t=19.315

-- -- test1.5
-- -- 添加agv作为测试agent
-- local agentPosition = rmg:getContainerCoord(-1, 6, 1)
-- agentPosition[2] = 0 -- 修正高度
-- agentPosition[1], agentPosition[3] = agentPosition[1], agentPosition[3] -- 修正坐标系
-- print('agentPosition', table.unpack(agentPosition))
-- local agv = AGV()
-- agv:setpos(table.unpack(agentPosition))
-- -- 设置占用
-- agv.occupier = rmg
-- agv.state = 'wait'
-- rmg.occupier = agv
-- rmg.agentqueue = {agv}

-- 仿真任务
-- debug.pause()
watchdog.refresh()
