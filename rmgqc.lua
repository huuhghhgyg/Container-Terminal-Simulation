function RMGQC()
    local rmgqc = scene.addobj('/res/ct/rmqc.glb')
    rmgqc.trolley = scene.addobj('/res/ct/trolley_rmqc.glb')
    rmgqc.wirerope = scene.addobj('/res/ct/wirerope.glb')
    rmgqc.spreader = scene.addobj('/res/ct/spreader.glb')

    rmgqc.origin = {-16, 0, 130} -- rmgqc初始位置
    rmgqc.pos = 0
    rmgqc.level = {}
    rmgqc.level.agv = 2.1 + 2.42
    rmgqc.shipposx = -30
    rmgqc.ship = {} -- 对应的船
    rmgqc.iox = 0
    rmgqc.tasksequence = {} -- 初始化任务队列
    rmgqc.speed = 5 -- 移动速度
    rmgqc.zspeed = 2 -- 车移动速度
    rmgqc.attached = nil -- 抓取的集装箱
    rmgqc.stash = nil -- io物品暂存
    rmgqc.agvqueue = {} -- agv服务队列
    rmgqc.queuelen = 11 -- 服务队列长度（额外）
    
    rmgqc.posbay = {} -- 船对应的bay位
    for i = 1, 8 do -- 初始化船bay位
        rmgqc.posbay[i] = (5 - i) * 6.06
    end

    -- 初始化集装箱船高度
    for i = 1, 4 do
        rmgqc.level[i] = 11.29 + i * 2.42
    end
    rmgqc.toplevel = #rmgqc.level

    rmgqc.spreaderpos = {0, 0, 0}
    -- 初始化位置
    rmgqc.wirerope:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2] + 1.1, rmgqc.origin[3])
    rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - (rmgqc.origin[2]), 1)
    rmgqc.spreader:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc.trolley:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc:setpos(rmgqc.origin[1], rmgqc.origin[2], rmgqc.origin[3])
    print("初始化：spreader z = ", rmgqc.origin[3])

    function rmgqc:registeragv(agv)
        -- 初始化agv
        agv.arrived = false -- 设置到达标识
        agv.targetcontainer = rmgqc.ship:getidlepos() -- 设置目标集装箱位置（船上空余位置）
        agv.targetbay = agv.targetcontainer[1]
        local transfered = agv.worktype ~= nil -- 表示agv的来源是否来自所有权转移，如果是则不需要重复添加到执行队列
        agv.worktype = "rmgqc"
        agv.operator = rmgqc
        agv.datamodel = rmgqc.ship

        -- 为agv添加任务
        agv:addtask({"move2", {agv.datamodel.summon[1], agv.datamodel.summon[3]}})
        agv:addtask({"move2", {
            occupy = 1
        }}) -- 移动到第一个车位

        -- 为岸桥添加任务
        rmgqc:lift2agv(agv.targetcontainer[1]) -- 将抓住的集装箱移动到agv上
        rmgqc:addtask({"waitagv"}) -- 等待agv到达
        rmgqc:attachcontainer(table.unpack(agv.targetcontainer)) -- 将集装箱移动到指定位置

        table.insert(rmgqc.agvqueue, agv) -- 加入agv队列
        for i = 1, agv.datamodel.agvspan do
            agv.datamodel.parkingspace[i].occupied = agv.datamodel.parkingspace[i].occupied + 1 -- 停车位占用数+1
        end
        if not transfered then
            table.insert(actionobj, agv) -- 加入动作队列
            print("agv已加入动作队列")
        end
    end

    -- 放箱子
    function rmgqc:detach(row, col, level)
        rmgqc.ship.containers[row][col][level] = rmgqc.attached
        rmgqc.attached = nil
    end

    -- 抓箱子
    function rmgqc:attach()
        rmgqc.attached = rmgqc.agvqueue[1].container
        rmgqc.agvqueue[1].container = nil
        table.remove(rmgqc.agvqueue, 1)
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
                param[i + 7] = param[i + 7] + ds[i] -- 累计移动
            end
            ds[3] = param.speed[3] * dt -- rmg向量速度*时间

            if not param[12] then -- bay方向没有到达目标                
                if (param[5] + ds[3]) / (param[3] - param[4]) > 1 then -- 首次到达目标
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
                        rmgqc:spreadermove2(param[1], param[2], 0)
                        param[13] = true
                        break
                    end
                end
                rmgqc:spreadermove2(param[8], param[9], 0) -- 设置到累计移动值
            end

            if param[12] and param[13] then
                rmgqc:spreadermove2(param[1], param[2], 0)
                rmgqc:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmgqc.agvqueue[1] == nil then
                print("rmgqc: rmgqc.agvqueue[1]=nil")
            end
            if rmgqc.agvqueue[1] ~= nil and rmgqc.agvqueue[1].arrived then -- agv到达
                rmgqc:deltask()
            end
        elseif taskname == "attach" then -- {"attach", {ship.row,ship.col,ship.level}}
            rmgqc:attach()
            rmgqc:deltask()
        elseif taskname == "detach" then -- {"detach", nil}
            rmgqc:detach(param[1], param[2], param[3])
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
                               rmgqc.zspeed * ((param[3] - rmgqc.pos) / math.abs(param[3] - rmgqc.pos))} -- speed[3]:速度乘方向
            end

            if not param[12] then -- bay方向没有到达目标
                dt = math.min(dt, math.abs((param[3] - param[4] - param[5]) / param.speed[3]))
            end
            if not param[13] then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param[i + 5] ~= 0 then -- 只要分方向移动，就计算最大步进
                        dt = math.min(dt, (param[i] - param[i + 7]) / param.speed[i]) -- 根据move2判断条件
                    end
                end
            end
        end
        return dt
    end

    -- 添加任务
    function rmgqc:addtask(obj)
        table.insert(rmgqc.tasksequence, obj)
    end

    -- 删除任务
    function rmgqc:deltask()
        table.remove(rmgqc.tasksequence, 1)

        if (rmgqc.tasksequence[1] ~= nil and rmgqc.tasksequence[1][1] == "attach") then
            print("[rmgqc] task executing: ", rmgqc.tasksequence[1][1], " at ", coroutine.qtime())
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
        local z = rmgqc.posbay[bay] -- 通过车移动解决z

        return {x, y, z}
    end

    -- 添加任务，将抓住的集装箱移动到agv上
    function rmgqc:lift2agv(bay)
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel)}) -- 移动集装箱到agv对应列
    end

    -- 添加任务，将集装箱移动到船上
    function rmgqc:attachcontainer(bay, col, level)
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, -1, 1)}) -- 抓取agv上的箱子
        rmgqc:addtask({"attach"}) -- 放下指定箱
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, -1, rmgqc.toplevel)}) -- 吊具提升到移动层
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, col, rmgqc.toplevel)}) -- 移动爪子到指定位置
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, col, level)}) -- 移动爪子到指定位置
        rmgqc:addtask({"detach", {bay, col, level}}) -- 抓取指定箱
        rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, col, rmgqc.toplevel)}) -- 爪子抬起到移动层
    end

    return rmgqc
end