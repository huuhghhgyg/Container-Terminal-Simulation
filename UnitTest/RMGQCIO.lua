-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 引用组件
require('agv')
require('node')
require('road')
require('ship')
require('rmgqc')

-- 参数设置
local simv = 4 -- 仿真速度
local ActionObjs = {} -- 动作队列声明

-- 仿真控制
require('watchdog')
local watchdog = WatchDog(simv, ActionObjs)

-- 创建道路系统
local RoadList = {} -- 道路列表
local NodeList = {} -- 节点列表

-- 创建节点
local node1 = Node({0, 0, 10}, NodeList)
local node2 = Node({0, 0, 50}, NodeList)
local node3 = Node({20, 0, 50}, NodeList)
local node4 = Node({20, 0, 160}, NodeList)
local node5 = Node({0, 0, 160}, NodeList)
local node6 = Node({-30, 0, 160}, NodeList)
local node7 = Node({-30, 0, 280}, NodeList)
local node8 = Node({0, 0, 280}, NodeList)
local node9 = Node({0, 0, 300}, NodeList)
-- 创建道路
local rd1 = node1:createRoad(node2, RoadList)
local rd2 = node2:createRoad(node3, RoadList)
local rd3 = node3:createRoad(node4, RoadList)
local rd4 = node4:createRoad(node5, RoadList)
local rd5 = node2:createRoad(node5, RoadList)
local rd6 = node5:createRoad(node6, RoadList)
local rd7 = node6:createRoad(node7, RoadList)
local rd8 = node7:createRoad(node8, RoadList)
local rd9 = node5:createRoad(node8, RoadList)
local rd10 = node8:createRoad(node9, RoadList)

-- 创建堆场和rmg
local rmgqc = RMGQC({-30, 0, 210}, ActionObjs)
local ship = Ship({8, 9, 2}, rmgqc.berthPosition)

rmgqc:bindRoad(rd7) -- 绑定road
rmgqc:bindShip(ship) -- 绑定Ship
rmgqc:showBindingPoint()

-- ship填充集装箱
ship:fillRandomContainerPositions(30, {'/res/ct/container_blue.glb'})


scene.render()

local containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                       '/res/ct/container_yellow.glb'} -- 集装箱模型路径列表（从其他文件中复制过来的）

local generateConfig = {
    ship = ship,
    summonNum = 50,
    averageSummonSpan = 15
}
-- 生成具有任务的agv(ship)
function generateagv()
    -- 获取位置可用箱数信息，如果没有则注入
    -- 只有generateagv函数中能存取集装箱，因此只有此处设置positionLevels
    if ship.positionLevels == nil then
        ship.positionLevels = {} -- 初始化集装箱可用位置列表

        for i = 1, ship.bay do
            ship.positionLevels[i] = {}
            for j = 1, ship.row do
                -- 计算此位置的堆叠层数
                local levelCount = 0
                for k = 1, ship.level do
                    if ship.containers[i][j][k] ~= nil then
                        levelCount = levelCount + 1
                    end
                end
                ship.positionLevels[i][j] = levelCount
            end
        end
    end

    -- 生成agv任务类型
    local agvTaskType = math.random(2) == 1 and 'unload' or 'load' -- 1:agv卸货，2:agv装货
    print('生成AGV，taskType=', agvTaskType)

    -- 识别任务类型并生成可用位置列表
    local availablePos = {} -- 可用位置
    for i = 1, ship.bay do
        for j = 1, ship.row do
            local containerLevel = ship.positionLevels[i][j] -- 获取堆叠层数
            if agvTaskType == 'unload' then
                -- agv卸货，找到所有可用的存货位置(availableNum < ship.level)
                if containerLevel < ship.level then
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
    ship.positionLevels[trow][tcol] = ship.positionLevels[trow][tcol] + (agvTaskType == 'unload' and 1 or -1)

    -- 生成agv
    local agv = AGV()
    agv.taskType = agvTaskType -- 设置agv任务类型(unload/load)
    if agv.taskType == 'unload' then -- agv卸货，生成集装箱
        agv.container = scene.addobj(containerUrls[1]) -- 生成agv携带的集装箱
    end
    agv:move2(10, 0, -10)
    agv.targetContainerPos = targetPos -- 设置agv目标位置{bay,row,col}
    agv:bindCrane(ship, targetPos) -- 绑定agv和船

    -- agv添加任务
    -- agv移动到目标位置(以后由controller调度)
    agv:addtask({'moveon', {road=rd1}})
    agv:addtask({'onnode', {node2, rd1, rd5}})
    agv:addtask({'moveon',{road = rd5}})
    agv:addtask({'onnode', {node5, rd5, rd6}})
    agv:addtask({'moveon',{road = rd6}})
    agv:addtask({'onnode', {node6, rd6, rd7}})
    agv:addtask({'moveon',{road = rd7, targetDistance = rmgqc.parkingSpaces[targetPos[1]].relativeDist, stay = true}})
    if agv.taskType == 'unload' then
        agv:addtask({'detach', nil})
        agv:addtask({'waitoperator', {agv.taskType}})
    else
        agv:addtask({'waitoperator', {agv.taskType}})
        agv:addtask({'attach', nil})
    end
    agv:addtask({'moveon', {
        road = rd7,
        distance = rmgqc.parkingSpaces[targetPos[1]].relativeDist,
        stay = false
    }})
    agv:addtask({'onnode', {node7, rd7, rd8}})
    agv:addtask({'moveon',{road = rd8}})
    agv:addtask({'onnode', {node8, rd8, rd10}})
    agv:addtask({'moveon',{road = rd10}})
    agv:addtask({'onnode', {node9, rd10, nil}})

    rmgqc:registerAgv(agv)
    print('[main] agv target=',agv.targetContainerPos[1],agv.targetContainerPos[2],agv.targetContainerPos[3], ', agv taskType=', agv.taskType)

    -- 程序控制
    if not watchdog.runcommand or generateConfig.summonNum == 0 then
        return
    end
    generateConfig.summonNum = generateConfig.summonNum - 1 -- agv剩余生成次数减1

    -- 添加事件
    print("[agv", agv.roadAgvId or agv.id, "] summon at: ", coroutine.qtime())
    local tArriveSpan = math.random(generateConfig.averageSummonSpan)
    coroutine.queue(tArriveSpan, generateagv)
end
generateagv()

-- 仿真任务
watchdog:update()