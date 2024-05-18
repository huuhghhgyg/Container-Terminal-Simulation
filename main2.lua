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
local simv = 8 -- 仿真速度
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
local pgb = ProgressBar(_, _, _, 500)

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
cys[3] = CY(cyRow, cyCol, cyLevel, {
    origin = {30, 0, 40}
})
cys[2] = CY(cyRow, cyCol, cyLevel, {
    origin = {30, 0, 160}
})
cys[1] = CY(cyRow, cyCol, cyLevel, {
    origin = {30, 0, 280}
})
cys[6] = CY(cyRow, cyCol, cyLevel, {
    origin = {90, 0, 40}
})
cys[5] = CY(cyRow, cyCol, cyLevel, {
    origin = {90, 0, 160}
})
cys[4] = CY(cyRow, cyCol, cyLevel, {
    origin = {90, 0, 280}
})

for i = 1, 6 do
    local road = i <= 3 and rd21 or rd22
    cys[i]:bindRoad(road)
    cys[i]:showBindingPoint()
    cys[i]:fillRandomContainerPositions(50, {'/res/ct/container_blue.glb'})
    cys[i].id = i
    pgb:setp(pgb.value + 1 / 2 / 6 / 2) -- 创建cy集装箱的进度为1/2/2
    rmgs[i] = RMG({
        stack = cys[i],
        actionObjs = ActionObjs
    }) -- 创建rmg时会自动添加到ActionObjs中
    pgb:setp(pgb.value + 1 / 2 / 6 / 2) -- 创建rmg的进度为1/2/2
end

-- 将资源添加到controller中
controller.cys = cys
controller.rmgs = rmgs

-- 创建船和rmgqc
local rmgqcs = {}
local ships = {}

for i = 1, 3 do
    rmgqcs[i] = RMGQC({
        anchorPoint = {-30, 0, -70 + 120 * i},
        actionObjs = ActionObjs
    })
    ships[i] = Ship({
        anchorPoint = rmgqcs[i].berthPosition
    })
    rmgqcs[i]:bindRoad(controller.Roads[i * 5 - 1]) -- 绑定road
    rmgqcs[i]:bindStack(ships[i]) -- 绑定Ship
    rmgqcs[i]:showBindingPoint()
    pgb:setp(pgb.value + 1 / 2 / 3 / 2) -- 创建rmg和ship的进度为1/2/2
    -- ship填充集装箱
    ships[i]:fillRandomContainerPositions(30, {'/res/ct/container_yellow.glb'})
    ships[i].id = i
    pgb:setp(pgb.value + 1 / 2 / 3 / 2) -- 创建ship集装箱的进度为1/2/2
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
scene.setenv({
    camtype = 'persp'
})

scene.render()
print('实体生成完成，可以随时开始')
debug.pause()

-- 简易版
-- 任意选择一个控件，任意选择一项任务，执行。
local containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                       '/res/ct/container_yellow.glb'} -- 集装箱模型路径列表（从其他文件中复制过来的）

local generateConfig = {
    summonNum = 10,
    -- averageSummonSpan = 8,
    rate = {
        rmg = 0.5, -- 生成rmg类型任务的几率
        load = 0.5 -- 生成load任务的几率
    },
    taskNum = 100 -- 生成任务数量
}

controller.containers = {}

-- 初始化agv
function initAgv(num, controller)
    assert(controller.agvs ~= nil, 'initAgv中输入的controller没有在controller.agvs中创建列表')

    for i = 1, num do
        -- 生成agv
        local agv = AGV()
        -- agv:setpos(10, 0, -10)
        agv:setpos(0, 0, -50)

        table.insert(controller.agvs, agv)
        table.insert(ActionObjs, agv)
        agv:addtask('delay', {3 * (i - 1)}) -- 从第一个往后每个delay 3s出发
    end
end
controller.agvs = {}
initAgv(generateConfig.summonNum, controller)

-- 生成agv任务

-- 获取可用位置
-- return targetPos={row, col, level}
function getAvailablePosition(stack, taskType)
    -- 获取位置可用箱数信息，如果没有则注入
    if stack.positionLevels == nil then
        stack.positionLevels = {} -- 初始化集装箱可用位置列表

        for i = 1, stack.row do
            stack.positionLevels[i] = {}
            for j = 1, stack.col do
                -- 计算此位置的堆叠层数
                local levelCount = 0
                for k = 1, stack.level do
                    if stack.containers[i][j][k] == nil then
                        break
                    end
                    levelCount = k
                end
                stack.positionLevels[i][j] = levelCount
            end
        end
    end

    -- print(tablestr(stack.positionLevels))

    -- 识别任务类型并修改可用位置列表
    local availablePos = {} -- 搜索可用位置
    for i = 1, stack.row do
        for j = 1, stack.col do
            if taskType == 'unload' then
                if stack.positionLevels[i][j] < stack.level then
                    table.insert(availablePos, {i, j, stack.positionLevels[i][j] + 1})
                end
            else
                -- load
                if stack.positionLevels[i][j] > 0 then
                    -- 如果初始没有，就不用
                    if stack.containers ~= nil then
                        table.insert(availablePos, {i, j, stack.positionLevels[i][j]})
                    end
                end
            end
        end
    end

    -- {i, j, containerLevel}
    local targetPos = availablePos[math.random(#availablePos)] -- 抽取可用位置

    -- 记录抽取位置的影响
    local trow, tcol = targetPos[1], targetPos[2]

    print('return position of', targetPos[1], targetPos[2], targetPos[3], 'for taskType', taskType)
    stack.positionLevels[trow][tcol] = stack.positionLevels[trow][tcol] + (taskType == 'unload' and 1 or -1)

    return targetPos
end

-- 生成任务函数，并返回对象信息
-- return task={fromOperator=,fromPos=,toOperator=,toPos=}
function generateTask()
    -- 生成任务类型
    local operatorFrom, operatorTo = nil, nil -- 初始化od operator

    -- 抽取operator对象
    if math.random() > 0.5 then
        operatorFrom = controller.rmgqcs[math.random(#controller.rmgqcs)]
        operatorTo = controller.rmgs[math.random(#controller.rmgs)]
    else
        operatorFrom = controller.rmgs[math.random(#controller.rmgs)]
        operatorTo = controller.rmgqcs[math.random(#controller.rmgqcs)]
    end

    local fromPos = getAvailablePosition(operatorFrom.stack, 'load')
    print('抽取得到的fromPos:', fromPos[1], fromPos[2], fromPos[3])
    local toPos = getAvailablePosition(operatorTo.stack, 'unload')
    print('抽取得到的toPos:', toPos[1], toPos[2], toPos[3])

    local task = {
        fromOperator = operatorFrom,
        fromPos = fromPos,
        toOperator = operatorTo,
        toPos = toPos
    }

    -- 记录数据
    local row, bay, level = table.unpack(fromPos)

    return task
end

-- 为agv规划的节点（只在生成任务时有用，确定任务结束后AGV节点的位置）
local agvAtRoad, agvAtNodeId = {}, {}
for a, agv in ipairs(controller.agvs) do
    agvAtRoad[agv.id] = controller.Roads[1] -- 初始化agv当前节点（初始位置节点）
    agvAtNodeId[agv.id] = 1
end

function addAgvCarryTask(agv, task)
    -- 参数初始化
    local fromOperator, fromPos, toOperator, toPos = task.fromOperator, task.fromPos, task.toOperator, task.toPos

    agv:addtask('register', {
        operator = fromOperator,
        taskType = 'load',
        targetContainerPos = fromPos
    })
    agv:addtask('register', {
        operator = toOperator,
        taskType = 'unload',
        targetContainerPos = toPos
    })

    for i = 1, 2 do
        local operator = i == 1 and fromOperator or toOperator
        local pos = i == 1 and fromPos or toPos

        agv:addtask('setvalue', {
            key = 'taskType',
            value = i == 1 and 'load' or 'unload'
        })

        -- 为agv添加任务
        -- 去operator
        agv:addtask('setvalue', {
            key = 'targetContainerPos',
            value = pos
        }) -- 设置agv目标位置{bay,row,col}

        -- 绑定Crane信息
        agv:bindCrane(operator.stack, pos) -- 绑定Crane

        local stack = operator.stack
        local toRoad = stack.bindingRoad or operator.road -- cy/rmgqc绑定的road
        local stpTargetNode = toRoad.fromNode

        controller:addAgvNaviTask(agv, agvAtNodeId[agv.id], stpTargetNode.id, agvAtRoad[agv.id], {
            road = toRoad,
            targetDistance = stack.parkingSpaces == nil and operator.parkingSpaces[pos[2]].relativeDist or
                stack.parkingSpaces[pos[2]].relativeDist,
            stay = true
        })
        agv:addtask('waitoperator', {
            operator = operator
        })
        -- 记录装载时间
        if i == 1 then
            agv:addtask('fn', {
                f = function()
                    if agv.container.loaded == nil then
                        agv.container.loaded = {}
                    end
                    table.insert(agv.container.loaded, coroutine.qtime()) -- 涉及多次装载
                end,
                args = {}
            })
        end
        -- 记录卸载时间
        if i == 2 then
            agv:addtask('fn', {
                f = function()
                    if operator.attached.unload == nil then
                        operator.attached.unload = {}
                    end
                    table.insert(operator.attached.unload, coroutine.qtime()) -- 涉及多次装载
                    controller.containers[operator.attached.id] = operator.attached -- 记录集装箱
                end,
                args = {}
            })
        end
        agv:addtask('moveon', {
            road = toRoad,
            distance = stack.parkingSpaces == nil and operator.parkingSpaces[pos[2]].relativeDist or
                stack.parkingSpaces[pos[2]].relativeDist,
            stay = false
        })

        agvAtRoad[agv.id] = toRoad -- 记录agv此次任务完成后的目标节点
        agvAtNodeId[agv.id] = toRoad.toNode.id
    end

end

-- agv拉取任务
function pullTask(agv)
    agv:addtask('fn', {
        f = function()
            if generateConfig.taskNum > 0 then
                local task = generateTask()
                addAgvCarryTask(agv, task)
                generateConfig.taskNum = generateConfig.taskNum - 1
                -- print('agv' .. agv.id, 'pullTask', generateConfig.taskNum, '的执行时间', coroutine.qtime())
                pullTask(agv)
            end
        end,
        args = {}
    })
end

-- 为AGV分配初始任务
function allocateAgvTask()
    -- 初始化参数
    local agvNum = generateConfig.summonNum

    -- 拉取初始任务
    for a = 1, agvNum do
        pullTask(controller.agvs[a])
    end
end

allocateAgvTask()

-- 开始仿真任务is
watchdog:refresh()

-- 获取数据
function getData()
    print('here is getData()')
    local file = io.open('result.csv', 'w+')
    io.output(file)
    io.write('container_id,loadt,unloadt\n')

    for k, container in pairs(controller.containers) do
        for i = 1, #container.loaded do
            local str = container.id .. ',' .. tostring(container.loaded[i]) .. ',' .. tostring(container.unload[i]) ..
                            '\n'
            io.write(str)
        end
    end

    -- 清除场景
    -- os.execute("RemoteCall('eval', 'scene.reload(true)')") 
end

coroutine.queue(10e5, getData)
