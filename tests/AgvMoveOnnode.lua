-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用库
require('watchdog')
require('agent')
require('agv')
require('road')
require('node')

local ActionObjs = {}
local simv = 2

local watchdog = WatchDog(simv, ActionObjs)

-- 路网
local RoadList = {}
local NodeList = {}

local NodeDefaultRadius = 5
local n1 = Node({0,0,0-NodeDefaultRadius}, NodeList)
local n2 = Node({0,0,50}, NodeList)
local n3 = Node({0,0,100}, NodeList)
local n4 = Node({50+NodeDefaultRadius,0,100}, NodeList)
local rd1 = n1:createRoad(n2, RoadList)
local rd2 = n2:createRoad(n3, RoadList)
local rd3 = n3:createRoad(n4, RoadList)

local agv = AGV()
-- move2 测试
-- agv:addtask('move2',{0,150})

-- onnode 测试
agv:addtask('moveon',{road=rd1})
agv:addtask('onnode',{n2,rd1,rd2})
agv:addtask('moveon',{road=rd2})
agv:addtask('onnode',{n2,rd2,rd3})
agv:addtask('moveon',{road=rd3})
agv:addtask('onnode',{n3,rd3})

table.insert(ActionObjs, agv)

watchdog:refresh()