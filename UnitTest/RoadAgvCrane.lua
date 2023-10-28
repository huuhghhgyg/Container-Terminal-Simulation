require('agv')

-- 控制器
scene.setenv({
    grid = 'plane'
})

-- 参数设置
local simv = 1 -- 仿真速度
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

require('road')
require('cy')
require('rmg')

-- 创建对象
local cy1 = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3) -- 创建堆场
local road1 = Road({-15, 0, -50}, {-15, 0, 50}, roadList) -- 创建道路

-- 绑定道路
cy1:bindRoad(road1)
cy1:showBindingPoint()

cy1:fillAllContainerPositions()

local rmg1 = RMG(cy1, actionObjs) -- 创建rmg

scene.render()

-- 仿真任务
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)}) 
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 3)})
-- rmg1:addtask({'attach', {3, 2, 3}})
-- rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)})
-- rmg1:addtask({'move2', rmg1:getContainerCoord(2, -1, 1)})

rmg1:addtask({'move2', rmg1:getContainerCoord(3, 2, 5)})
rmg1:attachContainer(3, 2, 3)
rmg1:lift2Agv(3, 2)

-- 开始仿真
update()