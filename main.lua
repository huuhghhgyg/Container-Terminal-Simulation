-- 控制器
scene.setenv({
    grid = 'plane'
})

print()

-- 引用组件
require('agent')
require('cy')
require('rmg')
require('agv')
require('node')
require('road')
require('ship')
require('rmgqc')

-- 1.下载函数库到虚拟磁盘
print('正在下载依赖库到虚拟磁盘...')
os.upload('https://www.zhhuu.top/ModelResource/libs/tablestr.lua')
print('下载完成')
-- 2.引用库
require('tablestr')

-- 参数设置
local simv = 2 -- 仿真速度
local ActionObjs = {} -- 动作队列声明

-- 仿真控制
require('watchdog')
watchdog = WatchDog(simv, ActionObjs)

require('controller')
local controller = Controller()

-- 创建节点
local n1 = controller:addNode({0, 0, -50})
local n2 = controller:addNode({0, 0, 0})
local n3 = controller:addNode({0, 0, 30})
local n4 = controller:addNode({-30, 0, 30})
local n5 = controller:addNode({-30, 0, 120})
local n6 = controller:addNode({0, 0, 120})
local n7 = controller:addNode({0, 0, 150})
local n8 = controller:addNode({-30, 0, 150})
local n9 = controller:addNode({-30, 0, 240})
local n10 = controller:addNode({0, 0, 240})
local n11 = controller:addNode({0, 0, 270})
local n12 = controller:addNode({-30, 0, 270})
local n13 = controller:addNode({-30, 0, 360})
local n14 = controller:addNode({0, 0, 360})
local n15 = controller:addNode({0, 0, 390})
local n16 = controller:addNode({20, 0, 390})
local n17 = controller:addNode({80, 0, 390})
local n18 = controller:addNode({80, 0, 0})
local n19 = controller:addNode({20, 0, 0})
local n20 = controller:addNode({0, 0, 430})

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

require('ProgressBar')
local pgb = ProgressBar(_,_,_,500)

-- for k, node in ipairs(controller.Nodes) do
--     print('node',k,'.id=',node.id)
-- end

-- for k, road in ipairs(controller.Roads) do
--     print('road',k,'.id=',road.id)
-- end

-- print('打印节点OD信息')
-- for k, node in ipairs(controller.Nodes) do
--     print('node',k,'.id=',node.id)
--     print('fromNodesId:')
--     for k1, v1 in ipairs(node.fromNodesId) do
--         print(k1,':', v1)
--     end
--     print('toNodesId:')
--     for k1, v1 in ipairs(node.toNodesId) do
--         print(k1,':', v1)
--     end
-- end


-- 创建堆场和rmg
local cys = {}
local rmgs = {}
local cyRow, cyCol, cyLevel = 5, 10, 3
cys[3] = CY(cyRow, cyCol, cyLevel, {origin = {30, 0, 40}})
cys[2] = CY(cyRow, cyCol, cyLevel, {origin = {30, 0, 160}})
cys[1] = CY(cyRow, cyCol, cyLevel, {origin = {30, 0, 280}})
cys[6] = CY(cyRow, cyCol, cyLevel, {origin = {90, 0, 40}})
cys[5] = CY(cyRow, cyCol, cyLevel, {origin = {90, 0, 160}})
cys[4] = CY(cyRow, cyCol, cyLevel, {origin = {90, 0, 280}})

for i = 1, 6 do
    local road = i <= 3 and rd21 or rd22
    cys[i]:bindRoad(road)
    cys[i]:showBindingPoint()
    cys[i]:fillRandomContainerPositions(50, {'/res/ct/container_blue.glb'})
    pgb:setp(pgb.value+1/2/6/2) -- 创建cy集装箱的进度为1/2/2
    rmgs[i] = RMG({stack = cys[i], actionObjs = ActionObjs}) -- 创建rmg时会自动添加到ActionObjs中
    pgb:setp(pgb.value+1/2/6/2) -- 创建rmg的进度为1/2/2
end

-- 将资源添加到controller中
controller.cys = cys
controller.rmgs = rmgs

-- 创建船和rmgqc
local rmgqcs = {}
local ships = {}

for i = 1, 3 do
    rmgqcs[i] = RMGQC({anchorPoint = {-30, 0, -70 + 120 * i}, actionObjs = ActionObjs})
    ships[i] = Ship({anchorPoint = rmgqcs[i].berthPosition})
    rmgqcs[i]:bindRoad(controller.Roads[i * 5 - 1]) -- 绑定road
    rmgqcs[i]:bindStack(ships[i]) -- 绑定Ship
    rmgqcs[i]:showBindingPoint()
    pgb:setp(pgb.value+1/2/3/2) -- 创建rmg和ship的进度为1/2/2
    -- ship填充集装箱
    ships[i]:fillRandomContainerPositions(30, {'/res/ct/container_yellow.glb'})
    pgb:setp(pgb.value+1/2/3/2) -- 创建ship集装箱的进度为1/2/2
end

-- 将资源添加到controller中
controller.rmgqcs = rmgqcs
controller.ships = ships

-- 显示节点
for nodeId, node in ipairs(controller.Nodes) do
    local label = scene.addobj('label', {
        text = 'node' .. nodeId
    })
    label:setpos(table.unpack(node.center))
end

-- 显示道路
for roadId, road in ipairs(controller.Roads) do
    local label = scene.addobj('label', {
        text = 'road' .. roadId
    })
    local centerPos = {}
    for i = 1, 3 do
        centerPos[i] = (road.originPt[i] + road.destPt[i]) / 2
    end
    label:setpos(table.unpack(centerPos))
end

pgb:del()
scene.setenv({camtype = 'persp'})

scene.render()
print('实体生成完成，可以随时开始')
debug.pause()

-- 简易版
-- 任意选择一个控件，任意选择一项任务，执行。
local containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                       '/res/ct/container_yellow.glb'} -- 集装箱模型路径列表（从其他文件中复制过来的）

local generateConfig = {
    summonNum = 6,
    averageSummonSpan = 15,
    rate = {
        rmg = 0.5, -- 生成rmg类型任务的几率
        load = 0.5 -- 生成load任务的几率
    }
}

-- 生成agv任务
-- return operator, operator.stack, 'rmg'/'rmgqc'
function generateTask()
    -- 生成任务类型
    local taskType = math.random() > generateConfig.rate.load and 'unload' or 'load'
    -- 抽取operator对象并返回
    local operatorType = math.random() > 0.5 and 'rmg' or 'rmgqc'
    
    local operatorList = controller[operatorType..'s'] -- controller中存储rmgs/rmgqcs
    local operatorId = math.random(#operatorList) -- 从列表中随机抽取
    local operator = operatorList[operatorId]
    
    return operator, operator.stack, taskType
end

-- 生成具有任务的agv(ship)
function generateAgv()
    -- 程序控制
    if not watchdog.runcommand or generateConfig.summonNum == 0 then
        return
    end
    generateConfig.summonNum = generateConfig.summonNum - 1 -- agv剩余生成次数减1

    
    -- 抽取生成agv任务类型
    local operatorAgent, stack, agvTaskType = generateTask()
    print('生成AGV，taskType=', agvTaskType, ', operatorType=', operatorAgent.type, 'operator.id=', operatorAgent.id)

    -- 获取位置可用箱数信息，如果没有则注入
    -- 只有generateagv函数中能存取集装箱，因此只有此处设置positionLevels
    if stack.positionLevels == nil then
        stack.positionLevels = {} -- 初始化集装箱可用位置列表

        for i = 1, stack.row do
            stack.positionLevels[i] = {}
            for j = 1, stack.col do
                -- 计算此位置的堆叠层数
                local levelCount = 0
                for k = 1, stack.level do
                    if stack.containers[i][j][k] ~= nil then
                        levelCount = levelCount + 1
                    end
                end
                stack.positionLevels[i][j] = levelCount
            end
        end
    end

    -- 识别任务类型并生成可用位置列表
    local availablePos = {} -- 可用位置
    for i = 1, stack.row do
        for j = 1, stack.col do
            local containerLevel = stack.positionLevels[i][j] -- 获取堆叠层数
            if agvTaskType == 'unload' then
                -- agv卸货，找到所有可用的存货位置(availableNum < stack.level)
                if containerLevel < stack.level then
                    table.insert(availablePos, {i, j, containerLevel + 1}) -- 记录可用位置{bay, row}
                end
            else
                -- agv装货，找到所有可用的取货位置(availableNum > 0)
                if containerLevel > 0 then
                    table.insert(availablePos, {i, j, containerLevel}) -- 记录可用位置{bay, row}
                end
            end
        end
    end

    local targetPos = availablePos[math.random(#availablePos)] -- 抽取可用位置
    -- 记录抽取位置的影响
    local trow, tcol = targetPos[1], targetPos[2]
    stack.positionLevels[trow][tcol] = stack.positionLevels[trow][tcol] + (agvTaskType == 'unload' and 1 or -1)

    -- 生成agv
    local agv = AGV()
    agv.taskType = agvTaskType -- 设置agv任务类型(unload/load)
    if agv.taskType == 'unload' then -- agv卸货，生成集装箱
        agv.container = scene.addobj(containerUrls[1]) -- 生成agv携带的集装箱
    end
    agv:setpos(10, 0, -10)
    agv.targetContainerPos = targetPos -- 设置agv目标位置{bay,row,col}
    agv:bindCrane(stack, targetPos) -- 绑定agv和船

    -- agv添加任务
    -- if stack.type == 'cy' then
    --     -- 直接到rmg
    --     agv2rmgTask(agv, targetPos)
    --     print('[main] agv', agv.id, '2rmg')
    -- elseif stack.type == 'ship' then
    --     agv2rmgqcTask(agv, targetPos)
    --     print('[main] agv', agv.id, '2rmgqc')
    -- else
    --     print('[main] error: unknown dataModel type', stack.type, '. stopped.')
    --     os.exit()
    -- end
    -- table.insert(ActionObjs, agv)
    -- print('[main] agv', agv.id, 'added to ActionObjs, #ActionObjs=', #ActionObjs)

    -- print('[main] agv target=', agv.targetContainerPos[1], agv.targetContainerPos[2], agv.targetContainerPos[3],
    --     ', agv taskType=', agv.taskType)
    agv:addtask('register', {operator = operatorAgent})
    agv:addtask('moveon', {
        road = controller.Roads[1]
    })
    if operatorAgent.type == 'rmg' then
        -- operator类型为rmg
        local toRoad = stack.bindingRoad
        local stpTargetNode = toRoad.fromNode
        controller:addAgvNaviTask(agv, 2, stpTargetNode.id, controller.Roads[1], {
            road = stack.bindingRoad,
            targetDistance = stack.parkingSpaces[targetPos[2]].relativeDist,
            stay = true
        })
        print(agv.type .. agv.id, '目标road.id=', toRoad.id, '目标node.id=', stpTargetNode.id, '目标停车位=', targetPos[2], '(',
            stack.parkingSpaces[targetPos[2]].relativeDist, ')')
        agv:addtask('waitoperator', {operator = operatorAgent})
        agv:addtask('moveon', {
            road = stack.bindingRoad,
            distance = stack.parkingSpaces[targetPos[2]].relativeDist,
            stay = false
        })
        controller:addAgvNaviTask(agv, stack.bindingRoad.toNode.id, 15, toRoad, {road=controller.Roads[18]})
    elseif operatorAgent.type == 'rmgqc' then
        -- operator类型为rmgqc
        local toRoad = operatorAgent.road
        local stpTargetNode = toRoad.fromNode
        controller:addAgvNaviTask(agv, 2, stpTargetNode.id, controller.Roads[1], {
            road = operatorAgent.road,
            targetDistance = operatorAgent.stack.parkingSpaces[targetPos[2]].relativeDist,
            stay = true
        })
        agv:addtask('waitoperator', {operator = operatorAgent})
        agv:addtask('moveon', {
            road = operatorAgent.road,
            distance = operatorAgent.stack.parkingSpaces[targetPos[2]].relativeDist,
            stay = false
        })
        controller:addAgvNaviTask(agv, operatorAgent.road.toNode.id, 15, toRoad, {road=controller.Roads[18]})
    else
        print('[main] error: unknown operator type', operatorAgent.type, ', stopped.')
        os.exit()
    end
    -- 添加delete前的任务
    agv:addtask('onnode',{controller.Nodes[20], controller.Roads[18]})
    table.insert(ActionObjs, agv)
    print('[main] agv', agv.id, 'added to ActionObjs, #ActionObjs=', #ActionObjs, 'agv #tasks=', #agv.tasksequence)
    -- print(tablestr(agv.tasksequence, 2))

    -- 添加事件
    print("[agv"..agv.id.. "] summon at: ", coroutine.qtime())
    local tArriveSpan = math.random(generateConfig.averageSummonSpan)
    coroutine.queue(tArriveSpan, generateAgv)
end
generateAgv()

-- 仿真任务
watchdog:refresh()
