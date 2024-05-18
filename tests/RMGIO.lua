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
local node1 = Node({0, 0, -20}, NodeList)
local node2 = Node({0, 0, 80}, NodeList)
-- 创建道路
local rd1 = node1:createRoad(node2, RoadList)

-- 创建堆场
local cy = CY(5, 8, 3, {origin = {10, 0, 0}})
cy:bindRoad(rd1)
cy:showBindingPoint()
cy:fillRandomContainerPositions(50, {'/res/ct/container_blue.glb'})

local rmg = RMG({stack = cy, actionObjs = ActionObjs})
scene.render()

local containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                       '/res/ct/container_yellow.glb'} -- 集装箱模型路径列表（从其他文件中复制过来的）

local generateConfig = {
    cy = cy,
    -- summonNum = 50,
    summonNum = 1,
    averageSummonSpan = 15
}
-- 生成具有任务的agv(cy)
function generateagv()
    -- 获取位置可用箱数信息，如果没有则注入
    -- 只有generateagv函数中能存取集装箱，因此只有此处设置positionLevels
    if cy.positionLevels == nil then
        cy.positionLevels = {} -- 初始化集装箱可用位置列表

        for i = 1, cy.row do
            cy.positionLevels[i] = {}
            for j = 1, cy.col do
                -- 计算此位置的堆叠层数
                local levelCount = 0
                for k = 1, cy.level do
                    if cy.containers[i][j][k] ~= nil then
                        levelCount = levelCount + 1
                    end
                end
                cy.positionLevels[i][j] = levelCount
            end
        end
    end

    -- 生成agv任务类型
    local taskType = math.random(2) == 1 and 'unload' or 'load' -- 1:agv卸货，2:agv装货

    -- 识别任务类型并生成可用位置列表
    local availablePos = {} -- 可用位置
    for i = 1, cy.row do
        for j = 1, cy.col do
            local containerLevel = cy.positionLevels[i][j] -- 获取堆叠层数
            if taskType == 'unload' then
                -- agv卸货，找到所有可用的存货位置(availableNum < cy.level)
                if containerLevel < cy.level then
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
    cy.positionLevels[trow][tcol] = cy.positionLevels[trow][tcol] + (taskType == 'unload' and 1 or -1)
    print('生成AGV，taskType=', taskType, '目标位置=', table.unpack(targetPos))

    -- 生成agv
    local agv = AGV()
    agv.taskType = taskType -- 设置agv任务类型(unload/load)
    if agv.taskType == 'unload' then -- agv卸货，生成集装箱
        agv.container = scene.addobj(containerUrls[1]) -- 生成agv携带的集装箱
    end
    agv:setpos(10, 0, -10)
    agv.targetContainerPos = targetPos -- 设置agv目标位置{bay,row,col}
    agv:bindCrane(cy, targetPos) -- 绑定agv和堆场

    -- agv添加任务
    -- agv移动到目标位置(以后由controller调度)
    -- print('[agv] targetPos=', targetPos[1], targetPos[2], targetPos[3]) -- debug
    agv:addtask('moveon', {
        road = rd1,
        targetDistance = cy.parkingSpaces[targetPos[2]].relativeDist,
        stay = true
    })
    agv:addtask('waitoperator', {operator = rmg})
    agv:addtask('moveon', {
        road = rd1,
        distance = cy.parkingSpaces[targetPos[2]].relativeDist,
        stay = false
    })
    agv:addtask('onnode', {node2, rd1, nil})

    rmg:registerAgv(agv, agv.taskType, agv.targetContainerPos)
    table.insert(ActionObjs, agv)

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
watchdog.refresh()
