scene.setenv({
    grid = 'plane'
})

-- 程序控制
local runcommand = true

-- 参数设置
local simv = 10 -- 仿真速度
local actionobj = {} -- 动作队列声明
local agvSummonSpan = 46 -- agv生成间隔

-- 引用组件
require('rmg')
require('agv')
require('cy')
require('rmgqc')
require('ship')

-- 创建堆场
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)

-- 分配堆场给场桥
local rmg = RMG(cy, actionobj)
table.insert(actionobj, rmg)

local rmgqc = RMGQC() -- 获取岸桥
rmg.nextstep = rmgqc -- 设置岸桥
table.insert(actionobj, rmgqc)

local ship = SHIP(rmgqc)
ship:initqueue()

local line = scene.addobj("polyline", {
    vertices = {cy.summon[1], cy.summon[2], cy.summon[3], ship.exit[1], ship.exit[2], ship.exit[3]},
    color = "black"
})
local pt = scene.addobj("points", {
    vertices = {cy.summon[1], cy.summon[2], cy.summon[3], ship.exit[1], ship.exit[2], ship.exit[3]},
    color = "red",
    size = 5
})

-- 生成具有任务的agv（取货）
function generateagv()
    -- 生成有箱子位置的列表
    local availablepos = {}
    for i = 1, cy.row do
        for j = 1, cy.col do
            for k = cy.level, 1, -1 do -- 只要最高层的箱子
                local found = false -- 本次循环预定了最高层的箱子
                -- 对应位置有集装箱且没有被预定
                if cy.containers[i][j][k] ~= nil and cy.containers[i][j][k].reserved == nil then
                    table.insert(availablepos, {i, j, k})
                    found = true
                end
                if found then
                    break
                end
            end
        end
    end

    -- 判断堆场是否有箱子，如果没有则停止
    if #availablepos == 0 and runcommand then
        return
    end

    -- 随机抽取一个位置，生成agv
    local pos = availablepos[math.random(#availablepos)]
    cy.containers[pos[1]][pos[2]][pos[3]].reserved = true -- 标记为已经被预定
    local agv = AGV(cy, pos)
    print("[agv] summoned at: ", coroutine.qtime())

    local tArriveSpan = math.random(agvSummonSpan) + 1 -- 平均到达间隔120s
    print("[agv] next summon span: ", tArriveSpan, "s")
    coroutine.queue(tArriveSpan, generateagv)
end

-- 判断所有任务是否执行完成
function havetask()
    for i = 1, #actionobj do
        if #actionobj[i].tasksequence > 0 then
            return true
        end
    end
    return false
end

function recycle(obj)
    if obj.type == "agv" then
        if obj.container ~= nil then
            obj.container:delete()
        end
        obj:delete()
    end
end

-- 初始时间
local t = os.clock()
local dt = 0

function update()
    if runcommand then
        coroutine.queue(dt, update)
    end

    -- 计算最大更新时间
    local maxstep = math.huge
    for i = 1, #actionobj do
        if #actionobj[i].tasksequence > 0 then
            maxstep = math.min(maxstep, actionobj[i]:maxstep())
        end
    end

    -- 执行更新
    for i = 1, #actionobj do
        actionobj[i]:executeTask(dt)
    end

    -- 回收
    for i = 1, #actionobj do
        local obj = actionobj[i]

        if obj.type == "agv" and #obj.tasksequence == 0 then
            recycle(obj)
            table.remove(actionobj, i)
            break -- 假设每次同时只能到达一个，因此可以中止
        end
    end

    -- 绘图
    runcommand = scene.render()

    -- 刷新时间间隔
    dt = (os.clock() - t) * simv
    dt = math.min(dt, maxstep)
    t = os.clock()
end

update()

-- 生成agv
generateagv()
