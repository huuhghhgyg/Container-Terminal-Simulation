require('rmgqc')
require('ship')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 2 -- 仿真速度
local actionObjs = {} -- 动作队列声明
local roadList = {} -- 道路列表

-- 程序控制
local runcommand = true

-- 初始时间
local t = os.clock()
local dt = 0

-- todo: 此处的控制程序修改过，可能需要更新到正式使用的文件中
function update()
    -- 刷新时间间隔
    dt = (os.clock() - t) * simv
    t = os.clock()

    -- 计算最大更新时间
    local maxstep = dt
    for i = 1, #actionObjs do
        if #actionObjs[i].tasksequence > 0 then
            maxstep = math.min(maxstep, actionObjs[i]:maxstep())
        end
    end

    -- 执行更新
    for i = 1, #actionObjs do
        actionObjs[i]:executeTask(dt)
    end

    -- 回收
    for i = 1, #actionObjs do
        local obj = actionObjs[i]

        if obj.type == "agv" and #obj.tasksequence == 0 then
            recycle(obj)
            table.remove(actionObjs, i)
            break -- 假设每次同时只能到达一个，因此可以中止
        end
    end

    -- 绘图
    runcommand = scene.render()

    -- 下一次更新
    if runcommand then
        coroutine.queue(dt, update)
    end
end

function recycle(obj)
    if obj.type == "agv" then
        if obj.container ~= nil then
            obj.container:delete()
        end
        obj:delete()
    end
end

-- local rmgqc = RMGQC({-16, 0, 130})
local rmgqc = RMGQC({0, 0, 0})
local ship = Ship({8, 9, 2}, rmgqc.berthPosition)

-- ship填充集装箱
ship:fillAllContainerPositions()

-- 绑定Ship
rmgqc:bindShip(ship)

-- 添加任务
local target1 = {3, 4, 2}
rmgqc:addtask({"move2", rmgqc:getcontainercoord(target1[1], -1, rmgqc.toplevel)}) -- 初始化位置

-- 取下1
rmgqc:move2TargetPos(table.unpack(target1))
rmgqc:lift2Agv(table.unpack(target1))

-- 装载1
rmgqc:move2Agv(target1[1])
rmgqc:lift2TargetPos(table.unpack(target1))

-- 加入动作队列
table.insert(actionObjs, rmgqc)

update()
