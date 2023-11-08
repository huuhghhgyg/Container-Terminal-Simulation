-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用组件
require('cy')
require('rmg')
require('agv')
require('node')
require('road')
require('ship')
require('rmgqc')

-- 参数设置
local simv = 4        -- 仿真速度
local ActionObjs = {} -- 动作队列声明

-- 仿真控制
require('watchdog')
local watchdog = WatchDog(simv, ActionObjs)

require('controller')
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

print('正在生成实体...')

for k, node in ipairs(controller.Nodes) do
    print('node',k,'.id=',node.id)
end

for k, road in ipairs(controller.Roads) do
    print('road',k,'.id=',road.id)
end

print('打印节点OD信息')
for k, node in ipairs(controller.Nodes) do
    print('node',k,'.id=',node.id)
    print('fromNodesId:')
    for k1, v1 in ipairs(node.fromNodesId) do
        print(k1,':', v1)
    end
    print('toNodesId:')
    for k1, v1 in ipairs(node.toNodesId) do
        print(k1,':', v1)
    end
end

-- 创建堆场和rmg
local cys = {}
local rmgs = {}

cys[3] = CY({ 25, 40 }, { 45, 110 }, 3)
cys[2] = CY({ 25, 160 }, { 45, 230 }, 3)
cys[1] = CY({ 25, 280 }, { 45, 350 }, 3)
cys[6] = CY({ 85, 40 }, { 105, 110 }, 3)
cys[5] = CY({ 85, 160 }, { 105, 230 }, 3)
cys[4] = CY({ 85, 280 }, { 105, 350 }, 3)

for i = 1, 6 do
    local road = i <= 3 and rd21 or rd22
    cys[i]:bindRoad(road)
    cys[i]:showBindingPoint()
    cys[i]:fillRandomContainerPositions(50, { '/res/ct/container_blue.glb' })
    rmgs[i] = RMG(cys[i], ActionObjs) -- 创建rmg时会自动添加到ActionObjs中
end

-- 创建船和rmgqc
local rmgqcs = {}
local ships = {}

for i = 1, 3 do
    rmgqcs[i] = RMGQC({ -30, 0, -40 + 120 * i }, ActionObjs)
    ships[i] = Ship({ 8, 9, 2 }, rmgqcs[i].berthPosition)
    rmgqcs[i]:bindRoad(controller.Roads[i * 5 - 1]) -- 绑定road
    rmgqcs[i]:bindShip(ships[i])            -- 绑定Ship
    rmgqcs[i]:showBindingPoint()
    -- ship填充集装箱
    ships[i]:fillRandomContainerPositions(30, { '/res/ct/container_blue.glb' })
end


scene.render()
print('实体生成完成')
