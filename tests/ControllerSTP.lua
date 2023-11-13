-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用组件
require('node')
require('road')
require('controller')
require('agv')
require('watchdog')
local controller = Controller()

-- 创建节点
local n1 = controller:addNode({ 0, 0, -50 })
local n2 = controller:addNode({ 0, 0, 0 })
local n3 = controller:addNode({ 0, 0, 30 })
local n4 = controller:addNode({ -30, 0, 30 })
local n5 = controller:addNode({ -30, 0, 120 })
local n6 = controller:addNode({ 0, 0, 120 })
local n7 = controller:addNode({ 0, 0, 150 })
local n8 = controller:addNode({ -30, 0, 150 })
local n9 = controller:addNode({ -30, 0, 240 })
local n10 = controller:addNode({ 0, 0, 240 })
local n11 = controller:addNode({ 0, 0, 270 })
local n12 = controller:addNode({ -30, 0, 270 })
local n13 = controller:addNode({ -30, 0, 360 })
local n14 = controller:addNode({ 0, 0, 360 })
local n15 = controller:addNode({ 0, 0, 390 })
local n16 = controller:addNode({ 20, 0, 390 })
local n17 = controller:addNode({ 80, 0, 390 })
local n18 = controller:addNode({ 80, 0, 0 })
local n19 = controller:addNode({ 20, 0, 0 })
local n20 = controller:addNode({ 0, 0, 430 })

-- 创建道路
local rd1 = controller:linkNode(n1, n2)
local rd2 = controller:linkNode(n2, n3)
local rd3 = controller:linkNode(n3, n4)
local rd4 = controller:linkNode(n4, n5)
local rd5 = controller:linkNode(n5, n6)
local rd6 = controller:linkNode(n3, n6)
local rd7 = controller:linkNode(n6, n7)
local rd8 = controller:linkNode(n7, n8)
local rd9 = controller:linkNode(n8, n9)
local rd10 = controller:linkNode(n9, n10)
local rd11 = controller:linkNode(n7, n10)
local rd12 = controller:linkNode(n10, n11)
local rd13 = controller:linkNode(n11, n12)
local rd14 = controller:linkNode(n12, n13)
local rd15 = controller:linkNode(n13, n14)
local rd16 = controller:linkNode(n11, n14)
local rd17 = controller:linkNode(n14, n15)
local rd18 = controller:linkNode(n15, n20)
local rd19 = controller:linkNode(n15, n16)
local rd20 = controller:linkNode(n16, n17)
local rd21 = controller:linkNode(n16, n19)
local rd22 = controller:linkNode(n17, n18)
local rd23 = controller:linkNode(n19, n2)
local rd24 = controller:linkNode(n18, n19)

-- 显示节点
for nodeId, node in ipairs(controller.Nodes) do
    local label = scene.addobj('label', { text = 'node' .. nodeId })
    label:setpos(table.unpack(node.center))
end

-- 显示道路
for roadId, road in ipairs(controller.Roads) do
    local label = scene.addobj('label', { text = 'road' .. roadId })
    local centerPos = {}
    for i = 1, 3 do
        centerPos[i] = (road.originPt[i] + road.destPt[i]) / 2
    end
    label:setpos(table.unpack(centerPos))
end

scene.render()

print('RoadNum:', #controller.Roads)
print('NodeNum:', #controller.Nodes)

-- local stpFromNodeId, stpToNodeId = 1, 19 -- road.id 正向
local stpFromNodeId, stpToNodeId = 17, 5 -- road.id 反向
local agv = AGV()

-- -- 手动添加stpFromNodeId到stpToNodeId的道路任务步骤
-- local stpRoadIds = controller:shortestPath(stpFromNodeId, stpToNodeId)
-- -- 显示规划得到的道路结果列表
-- local strRoadIds = ''
-- for i, roadId in ipairs(stpRoadIds) do
--     strRoadIds = strRoadIds .. roadId .. (i == #stpRoadIds and '' or ',')
-- end
-- print('stpRoadIds:', strRoadIds)
-- -- 将规划得到的道路结果列表按照从stpFromNodeId到stpToNodeId的顺序排序
-- local sortedSTPResult = controller:sortRoadIdSequence(stpFromNodeId ,stpRoadIds)

-- -- debug.pause()
-- controller:setAgvRoute(agv, sortedSTPResult, controller.Roads[20], {road = controller.Roads[5]}) -- 提供下一条道路的信息
-- -- controller:setAgvRoute(agv, sortedSTPResult, controller.Roads[20]) -- 不提供下一条道路的信息

-- 自动添加stpFromNodeId到stpToNodeId的道路任务步骤
agv:addtask('moveon',{road = controller.Roads[20]})
debug.pause()
controller:addAgvNaviTask(agv, stpFromNodeId, stpToNodeId, controller.Roads[20], {road = controller.Roads[5]}) -- 提供下一条道路的信息
-- controller:addAgvNaviTask(agv, stpFromNodeId, stpToNodeId, controller.Roads[20]) -- 不提供下一条道路的信息

local ActionObjs = {}
local watchdog = WatchDog(4, ActionObjs)
table.insert(ActionObjs, agv)
watchdog.update()