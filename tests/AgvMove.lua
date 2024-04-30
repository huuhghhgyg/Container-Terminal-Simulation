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
local n2 = Node({0,0,100+NodeDefaultRadius}, NodeList)
local rd = n1:createRoad(n2, RoadList)

local agv = AGV()
-- move2 测试
-- agv:addtask('move2',{0,150})

-- onnode 测试
agv:addtask('moveon',{road=rd})
agv:addtask('onnode',{n2,rd})

table.insert(ActionObjs, agv)

watchdog.refresh()