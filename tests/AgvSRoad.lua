-- 控制器
scene.setenv({
    grid = 'plane'
})
print()

-- 参数设置
local simv = 2 -- 仿真速度
local actionobj = {} -- 动作队列声明

-- 引用库
require('agent')
require('agv')
require('road')
require('node')
require('watchdog')

local watchdog = WatchDog(simv, actionobj)

-- 创建道路系统
local RoadList = {} -- 道路列表
local NodeList = {} -- 节点列表

-- 创建节点
local node1 = Node({0, 0, 0}, NodeList)
local node2 = Node({0, 0, 50}, NodeList, {radius = 4})
-- local node3 = Node({50, 0, 50}, NodeList)
local node3 = Node({50, 0, 50}, NodeList)
local node4 = Node({50, 0, 0}, NodeList)
local node5 = Node({50,0,-50}, NodeList)
local node6 = Node({0, 0, -50}, NodeList)
local node7 = Node({0, 0, -100}, NodeList)
local node8 = Node({50, 0, -100}, NodeList)

-- 创建道路
local roadAuto1 = node1:createRoad(node2, RoadList)
local roadAuto2 = node2:createRoad(node3, RoadList)
local roadAuto3 = node3:createRoad(node4, RoadList)
local roadAuto4 = node4:createRoad(node5, RoadList)
local roadAuto5 = node5:createRoad(node6, RoadList)
local roadAuto6 = node6:createRoad(node7, RoadList)
local roadAuto7 = node7:createRoad(node8, RoadList)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)
print('autogen road:', roadAuto2, ', roadId=', roadAuto2.id)

-- 运行时（根据任务）注册道路
local agv1 = AGV()
agv1:addtask("moveon",{road = roadAuto1, distance = 10})
agv1:addtask("onnode",{node2,roadAuto1,roadAuto2})
agv1:addtask("moveon",{road = roadAuto2})
agv1:addtask("onnode",{node3,roadAuto2,roadAuto3})
agv1:addtask("moveon",{road = roadAuto3})
agv1:addtask("onnode",{node4,roadAuto3,roadAuto4})
agv1:addtask("moveon",{road = roadAuto4})
agv1:addtask("onnode",{node5,roadAuto4,roadAuto5})
agv1:addtask("moveon",{road = roadAuto5})
agv1:addtask("onnode",{node6,roadAuto5,roadAuto6})
agv1:addtask("moveon",{road = roadAuto6})
agv1:addtask("onnode",{node7,roadAuto6,roadAuto7})
agv1:addtask("moveon",{road = roadAuto7})
agv1:addtask("onnode",{node8,roadAuto7})
table.insert(actionobj, agv1)

-- 仿真任务
watchdog.refresh()