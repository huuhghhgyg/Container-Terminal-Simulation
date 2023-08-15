scene.setenv({
    grid = 'plane'
})

-- 测试全局变量
local actionobj = {rmgqc}
local simv = 5
local runcommand = true


function RMGQC()
    local rmgqc = scene.addobj('/res/ct/rmqc.glb')
    rmgqc.trolley = scene.addobj('/res/ct/trolley_rmqc.glb')
    rmgqc.wirerope = scene.addobj('/res/ct/wirerope.glb')
    rmgqc.spreader = scene.addobj('/res/ct/spreader.glb')

    rmgqc.origin = {0, 0, 100} --rmgqc初始位置
    rmgqc.pos = 0
    rmgqc.level = {}
    rmgqc.level.agv = 2.1 + 2.42
    rmgqc.shipposx = -30
    rmgqc.ship = {} -- 对应的船
    rmgqc.iox = 0
    rmgqc.tasksequence = {} -- 初始化任务队列
    rmgqc.speed = 4 -- 移动速度
    rmgqc.attached = nil -- 抓取的集装箱
    rmgqc.stash = nil -- io物品暂存
    rmgqc.agvqueue = {} -- agv服务队列
    rmgqc.queuelen = 6 -- 服务队列长度（额外）
    rmgqc.summon = {} -- 车生成点
    rmgqc.exit = {} -- 车出口
    rmgqc.agvspan = 2 -- agv间距

    rmgqc.posbay = {} -- 船对应的bay位

    for i = 1, 8 do -- 初始化船bay位
        rmgqc.posbay[i] = (5 - i) * 6.06
    end

    -- 初始化集装箱船高度
    for i = 1, 5 do
        rmgqc.level[i] = 11.29 + i * 2.42
    end

    rmgqc.spreaderpos = {0, 0, 0}
    -- wirerope:setpos(0,1.1,0)
    -- wirerope:setscale(1,26.54+0.34,1)

    -- 初始化位置
    rmgqc.wirerope:setpos(rmgqc.origin[1] + 0 , rmgqc.origin[2] + 1.1 , rmgqc.origin[3])
    rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - (rmgqc.origin[2] ), 1)
    rmgqc.spreader:setpos(rmgqc.origin[1] + 0 , rmgqc.origin[2] , rmgqc.origin[3])
    rmgqc.trolley:setpos(rmgqc.origin[1] + 0 , rmgqc.origin[2], rmgqc.origin[3])
    rmgqc:setpos(rmgqc.origin[1], rmgqc.origin[2], rmgqc.origin[3])
    print("初始化：spreader z = ",rmgqc.origin[3])

    function rmgqc:registeragv(agv)
        -- 初始化agv
        agv.arrived = false --设置到达标识
        agv.targetcontainer = rmgqc.ship:getidlepos() -- 设置目标集装箱位置（船上空余位置）
        agv.targetbay = agv.targetcontainer[1]

        -- 为agv添加任务
        agv:setpos(table.unpack(rmgqc.summon))
        agv:addtask({"waitagv", {
            occupy = 1
        }}) -- 等待第一个车位
        agv:addtask({"move2", {
            occupy = 1
        }}) -- 移动到第一个车位

        -- 为岸桥添加任务
        rmgqc:addtask({"waitagv"}) -- 等待agv到达
        rmgqc:attachcontainer(table.unpack(agv.targetbay)) -- 抓取集装箱
        rmgqc:lift2ship(agv.targetcontainer[1], agv.targetcontainer[2]) -- 将抓住的集装箱移动到agv上
        
        table.insert(rmgqc.agvqueue, agv) -- 加入agv队列
        for i = 1, rmgqc.agvspan do
            rmgqc.parkingspace[i].occupied = rmgqc.parkingspace[i].occupied + 1 -- 停车位占用数+1
        end
        table.insert(actionobj, agv) -- 加入动作队列
    end

    -- 抓箱子
    function rmgqc:attach(row, col, level)
        rmgqc.attached = rmgqc.ship.containers[row][col][level]
        rmgqc.ship.containers[row][col][level] = nil
    end

    -- 放箱子
    function rmgqc:detach()
        rmgqc.stash = rmgqc.attached
        rmgqc.attached = nil
    end

    -- 爪子移动
    -- x移动：横向；y移动：上下；z移动(负方向)：纵向(微调,不常用)
    function rmgqc:spreadermove(dx, dy, dz)
        rmgqc.spreaderpos = {rmgqc.spreaderpos[1] + dx, rmgqc.spreaderpos[2] + dy, rmgqc.spreaderpos[3] + dz}
        local wx, wy, wz = rmgqc.wirerope:getpos()
        local sx, sy, sz = rmgqc.spreader:getpos()
        local tx, ty, tz = rmgqc.trolley:getpos()

        rmgqc.wirerope:setpos(wx + dx, wy + dy, wz - dz)
        rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - wy - dy, 1)
        rmgqc.trolley:setpos(tx + dx, ty, tz)
        rmgqc.spreader:setpos(sx + dx, sy + dy, sz - dz)

        -- 移动箱子
        if rmgqc.attached then
            local cx, cy, cz = rmgqc.attached:getpos()
            rmgqc.attached:setpos(cx + dx, cy + dy, cz - dz)
        end
    end

    -- 移动到指定位置
    function rmgqc:spreadermove2(x, y, z)
        rmgqc:spreadermove(x - rmgqc.spreaderpos[1], y - rmgqc.spreaderpos[2], z - rmgqc.spreaderpos[3])
    end

    -- 车移动(-z方向)
    function rmgqc:move(dist)
        rmgqc.pos = rmgqc.pos + dist
        local wx, wy, wz = rmgqc.wirerope:getpos()
        local sx, sy, sz = rmgqc.spreader:getpos()
        local tx, ty, tz = rmgqc.trolley:getpos()
        local rx, ry, rz = rmgqc:getpos()

        rmgqc.wirerope:setpos(wx, wy, wz + dist)
        rmgqc.spreader:setpos(sx, sy, sz + dist)
        rmgqc.trolley:setpos(tx, ty, tz + dist)
        rmgqc:setpos(rx, ry, rz + dist)

        -- 移动箱子
        if rmgqc.attached then
            local cx, cy, cz = rmgqc.attached:getpos()
            rmgqc.attached:setpos(cx, cy, cz + dist)
        end
    end

    function rmgqc:executeTask(dt)
        if #rmgqc.tasksequence == 0 then
            return
        end

        local task = rmgqc.tasksequence[1]
        local taskname, param = task[1], task[2]

        if taskname == "move2" then -- 1:col(x), 2:height(y), 3:bay(z), [4:初始bay, 5:已移动bay距离,向量*2(6,7),当前位置*2(8,9),初始位置*2(10,11),到达(12,13)*2]
            local ds = {}
            -- 计算移动值
            for i = 1, 2 do
                ds[i] = param.speed[i] * dt -- dt移动
                -- print("ds[",i,"]=",ds[i])
                param[i + 7] = param[i + 7] + ds[i] -- 累计移动
            end
            ds[3] = param.speed[3] * dt -- rmg向量速度*时间

            if not param[12] then -- bay方向没有到达目标                
                if (param[5] + ds[3]) / (param[3] - param[4]) > 1 then -- 首次到达目标
                    -- rmgqc:deltask()
                    rmgqc:move(param[3] - param[4] - param[5])
                    param[12] = true
                else
                    param[5] = param[5] + ds[3] -- 已移动bay
                    rmgqc:move(ds[3])
                end
            end

            if not param[13] then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param[i + 5] ~= 0 and (param[i] - param[i + 7]) * param[i + 5] <= 0 then -- 分方向到达目标
                        -- rmgqc:deltask()
                        rmgqc:spreadermove2(param[1], param[2], 0)
                        -- return
                        param[13] = true
                        break
                    end
                end
                rmgqc:spreadermove2(param[8], param[9], 0) -- 设置到累计移动值
                -- print("rmgqc:spreadermove2(",param[8],",",param[9],")")
            end

            if param[12] and param[13] then
                -- print("param 12 and 13:", param[12], ",", param[13])
                rmgqc:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmgqc.agvqueue[1] == nil then
                -- rmgqc:deltask()
                print("rmgqc: rmgqc.agvqueue[1]=nil")
            end
            if rmgqc.agvqueue[1] ~= nil and rmgqc.agvqueue[1].arrived then -- agv到达
                table.remove(rmgqc.agvqueue, 1) -- 移除等待的agv
                rmgqc:deltask()
            end
        elseif taskname == "attach" then -- {"attach", {ship.row,ship.col,ship.level}}
            rmgqc:attach(param[1], param[2], param[3])
            rmgqc:deltask()
        elseif taskname == "detach" then -- {"detach", nil}
            rmgqc:detach()
            rmgqc:deltask()
        end
    end

    -- interface:计算最大允许步进
    function rmgqc:maxstep()
        local dt = math.huge -- 初始化步进
        if rmgqc.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmgqc.tasksequence[1][1] -- 任务名称
        local param = rmgqc.tasksequence[1][2] -- 任务参数
        if taskname == "move2" then
            -- print("maxstep: move2")
            if param[4] == nil then
                param[4] = rmgqc.pos -- 初始位置
                param[5] = 0 -- 已经移动的距离
                for i = 1, 2 do
                    param[i + 7] = rmgqc.spreaderpos[i] -- 当前位置(8,9)
                    param[i + 9] = rmgqc.spreaderpos[i] -- 初始位置(10,11)
                    if param[i] - param[i + 9] == 0 then -- 目标距离差为0，向量设为0
                        param[i + 5] = 0
                    else
                        param[i + 5] = param[i] - param[i + 9] -- 计算初始向量
                    end
                end
                param[12], param[13] = param[3] == param[4], false

                -- 计算各方向分速度
                local l = math.sqrt(param[6] ^ 2 + param[7] ^ 2)
                param.speed = {param[6] / l * rmgqc.speed, param[7] / l * rmgqc.speed,
                               rmgqc.speed * ((param[3] - rmgqc.pos) / math.abs(param[3] - rmgqc.pos))} -- speed[3]:速度乘方向
            end

            if not param[12] then -- bay方向没有到达目标
                dt = math.min(dt, math.abs((param[3] - param[4] - param[5]) / param.speed[3]))
                -- if dt == math.abs((param[3] - param[4] - param[5]) / param.speed[3]) then --debug
                --     print("maxstep更新：(param[3] - param[4] - param[5]) / param.speed[3]=",(param[3] - param[4] - param[5]) / param.speed[3])
                -- end
            end
            if not param[13] then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param[i + 5] ~= 0 then -- 只要分方向移动，就计算最大步进
                        dt = math.min(dt, (param[i] - param[i + 7]) / param.speed[i]) -- 根据move2判断条件
                        -- if dt<0 then --debug
                        --     print("maxstep更新：(param[i] - param[i + 7]) / param.speed[i]=",(param[i] - param[i + 7]) / param.speed[i])
                        -- end
                    end
                end
            end
        end
        return dt
    end

    -- 添加任务
    function rmgqc:addtask(obj)
        table.insert(rmgqc.tasksequence, obj)
        -- print("rmgqc:addtask(): ", rmgqc.tasksequence[#rmgqc.tasksequence][1], ", task count:", #rmgqc.tasksequence)
    end

    -- 删除任务
    function rmgqc:deltask()
        -- print("rmgqc:deltask(): ", rmgqc.tasksequence[1][1], ", task count:", #rmgqc.tasksequence)
        table.remove(rmgqc.tasksequence, 1)

        if (rmgqc.tasksequence[1] ~= nil and rmgqc.tasksequence[1][1] ~= "move2") then
            print("[rmgqc] task executing: ", rmgqc.tasksequence[1][1])
        end
    end

    -- 获取爪子移动坐标（x,y)
    function rmgqc:getcontainercoord(bay, col, level)
        local x
        if col == -1 then
            x = rmgqc.iox
        else
            x = rmgqc.ship.pos[1][col][1][1] - rmgqc.origin[1]
        end

        local ry = 0 -- 相对高度
        if col == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            ry = ry + rmgqc.level.agv -- 加上agv高度
        else
            ry = ry + rmgqc.level[level] -- 加上层高
        end
        local y = ry - rmgqc.origin[2]
        -- print("rmgqc.origin[1]=",rmgqc.origin[1]," rmgqc.iox=",rmgqc.iox," x=",x)
        local z = rmgqc.posbay[bay] -- 通过车移动解决z

        print("go (", bay, ",", level, ",", col, ")->(x", x, ",y", y, ",z", z, ")")
        return {x, y, z}
    end

    return rmgqc
end

local rmgqc = RMGQC() -- 获取岸桥

function SHIP(rmgqc)
    -- 初始化船
    local ship = scene.addobj('/res/ct/ship.glb')
    
    ship.origin = {rmgqc.origin[1] + rmgqc.shipposx, rmgqc.origin[2], rmgqc.origin[3]}
    ship:setpos(ship.origin[1],ship.origin[2],rmgqc.origin[3])
    print("ship origin:",ship.origin[1],",",ship.origin[2],",",ship.origin[3])
    
    ship.bays = 8
    ship.cols = 9
    ship.level = 2
    ship.clength, ship.cspan = 6.06, 0 

    -- 初始化集装箱位置和集装箱
    ship.pos = {}
    ship.containers = {}
    for bay = 1, ship.bays do
        ship.pos[bay] = {}
        ship.containers[bay] = {}
        for col = 1, ship.cols do
            ship.pos[bay][col] = {}
            ship.containers[bay][col] = {}
            for level = 1, ship.level do
                -- print("bay,col,level=",bay,",",col,",",level)
                -- print("container[bay]=",ship.containers[bay],",container[bay][col]=",ship.containers[bay][col],",container[bay][col][level]=")
                -- local container = scene.addobj('/res/ct/container.glb')
                ship.containers[bay][col][level] = nil
                ship.pos[bay][col][level] = {ship.origin[1] + 2.44 * (5 - col), ship.origin[2] + 11.29 + (level - 1) * 2.42,
                                             rmgqc.origin[3] + rmgqc.posbay[bay]}
                -- container:setpos(table.unpack(ship.pos[bay][col][level]))
            end
        end
    end
    rmgqc.ship = ship

    rmgqc.parkingspace = {}
    function ship:initqueue() -- 初始化队列(ship.parkingspace) iox出入位置x相对坐标
        -- 停车队列(iox)
        ship.parkingspace = {} -- 属性：occupied:停车位占用情况，pos:停车位坐标，bay:对应堆场bay位

        -- 停车位
        for i = 1, ship.bays do
            ship.parkingspace[i] = {} -- 初始化
            ship.parkingspace[i].occupied = 0 -- 0:空闲，1:临时占用，2:作业占用
            print("ship.origin=",ship.origin[1],",",ship.origin[2],",",ship.origin[3])
            ship.parkingspace[i].pos = {rmgqc.origin[1] , 0, ship.pos[ship.bays - i + 1][1][1][3]} -- x,y,z
            ship.parkingspace[i].bay = ship.bays - i + 1
            local sign = scene.addobj("box")
            sign:setpos(table.unpack(ship.parkingspace[i].pos))
        end

        local lastbaypos = ship.parkingspace[1].pos -- 记录最后一个添加的位置

        -- 队列停车位
        for i = 1, rmgqc.queuelen do
            local pos = {lastbaypos[1], 0, lastbaypos[3] - i * (ship.clength + ship.cspan)}
            table.insert(ship.parkingspace, 1, {
                occupied = 0,
                pos = pos
            }) -- 无对应bay
            -- print("队列位置=", ship.queuelen - i + 1, " pos={", pos[1], ",", pos[2], ",", pos[3], "}")
            local sign = scene.addobj("box")
            sign:setpos(table.unpack(ship.parkingspace[1].pos))
        end

        rmgqc.summon = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[1].pos[3]}
        rmgqc.exit = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[#ship.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    function ship:reservepos(bay, col, level)
        ship.containers[bay][col][level] = {}
    end
    
    -- 返回空余位置编号
    function ship:getidlepos()
        for bay = 1, ship.bays do
            for col = 1, ship.cols do
                for level = 1, ship.level do
                    if ship.containers[bay][col][level] == nil then
                        return {bay, col, level}
                    end
                end
            end
        end
        
        return nil --没找到
    end
    
    return ship
end

local ship = SHIP(rmgqc)
ship:initqueue()
-- rmgqc:move2(0, rmgqc.level.agv, rmgqc.posbay[1])
scene.render()

-- 寻找空位
-- local p = ship:getidlepos()
-- print("idle pos on board: ",p[1],",",p[2],",",p[3])

-- 测试任务
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, -1, 4)}) -- 放下箱子
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, 4, 4)}) -- 放下箱子
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, 4, 2)}) -- 放下箱子
-- rmgqc:addtask({"attach", {2,4,2}})
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, 4, 4)}) -- 放下箱子
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, -1, 4)}) -- 放下箱子
-- rmgqc:addtask({"move2", rmgqc:getcontainercoord(2, -1, 1)}) -- 放下箱子


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

    -- 测试
    if #actionobj==0 or #actionobj[1].tasksequence == 0 then
        print("任务结束")
        runcommand = false
        return
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
        if #obj.tasksequence == 0 then
            recycle(obj)
        end
    end

    -- 绘图
    runcommand = scene.render()

    -- 刷新时间间隔
    dt = (os.clock() - t) * simv
    -- print("dt = ", dt, " maxstep = ", maxstep)
    dt = math.min(dt, maxstep)
    t = os.clock()
end

update()

-- 原点信标
local container0 = scene.addobj("/res/ct/container.glb")
-- container:setpos(0,18.55,0)

-- 生成具有任务的agv（取货）
function generateagv()
    -- 判断堆场是否有箱子，如果没有则停止
    if #pos == nil and runcommand then
        return
    end
    
    -- 生成有箱子位置的列表
    local pos = ship:getidlepos()
    ship:reservepos(table.unpack(pos))

    local tArriveSpan = math.random(agvSummonSpan) + 1 -- 平均到达间隔120s
    coroutine.queue(tArriveSpan, generateagv)

    -- 随机抽取一个位置，生成agv
    local agv = AGV(cy, pos)
    print("agv summoned at: ", coroutine.qtime())
end