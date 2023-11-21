-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用库
require('agv')
require('road')
require('node')

-- 创建道路系统
local RoadList = {} -- 道路列表
local NodeList = {} -- 节点列表

local node1 = Node({0, 0, 10}, NodeList)
local node2 = Node({0, 0, 50}, NodeList)
local node3 = Node({30, 0, 50}, NodeList)

-- 手动绘制道路并连接
-- local road1 = Road({0, 0, 10}, {0, 0, 30}, RoadList)
-- node3:connectRoad(road1.id)
-- local road2 = Road({10, 0, 40}, {30, 0, 40}, RoadList)

local roadAuto1 = node1:createRoad(node2, RoadList)
local roadAuto2 = node2:createRoad(node3, RoadList)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)
print('autogen road:', roadAuto2, ', roadId=', roadAuto2.id)

-- 显示节点连接道路的状态
print('node1 connectedRoad:', #node1.connectedRoads)
print('node2 connectedRoad:', #node2.connectedRoads)
print('node3 connectedRoad:', #node3.connectedRoads)

scene.render()