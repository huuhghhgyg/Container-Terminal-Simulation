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
local node3 = Node({50, 0, 100}, NodeList)
local node4 = Node({100,0,150}, NodeList)
local node5 = Node({-50, 0, 50}, NodeList)

-- 创建道路
local roadAuto1 = node1:createRoad(node2, RoadList)
local roadAuto2 = node2:createRoad(node3, RoadList)
local roadAuto3 = node3:createRoad(node4, RoadList)
local roadAuto4 = node2:createRoad(node5, RoadList)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)
print('autogen road:', roadAuto2, ', roadId=', roadAuto2.id)

-- 运行时（根据任务）注册道路
local agv1 = AGV()
-- agv3:addtask("move2", {roadAuto1.originPt[1], roadAuto1.originPt[3]})
agv1:addtask("moveon",{road = roadAuto1, distance = 10})
agv1:addtask("onnode",{node2,roadAuto1,roadAuto2})
agv1:addtask("moveon",{road = roadAuto2})
agv1:addtask("onnode",{node3,roadAuto2,roadAuto3})
agv1:addtask("moveon",{road = roadAuto3})
agv1:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv1)

-- 右转的AGV
local agv2 = AGV()
agv2:addtask("moveon",{road = roadAuto1})
agv2:addtask("onnode",{node2,roadAuto1,roadAuto4})
agv2:addtask("moveon",{road = roadAuto4})
agv2:addtask("onnode",{node5,roadAuto4})
table.insert(actionobj, agv2)

-- 测试onnode任务的出口阻塞等待
local agv3 = AGV()
-- agv3.speed = 1.5 --设置agv低速阻塞，测试onnode任务的阻塞等待 -- 仿真中暂时不考虑agv速度不同
agv3:addtask("moveon",{road = roadAuto3})
agv3:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv3)

-- 测试moveon任务的入口阻塞等待
local agv4 = AGV()
agv4:addtask("onnode",{node2,roadAuto1,roadAuto2})
agv4:addtask("moveon",{road = roadAuto2})
agv4:addtask("onnode",{node3,roadAuto2,roadAuto3})
agv4:addtask("moveon",{road = roadAuto3})
agv4:addtask("onnode",{node4,roadAuto3})
table.insert(actionobj, agv4)

-- 仿真任务
watchdog.refresh()