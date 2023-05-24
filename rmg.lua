scene.setenv({
    grid = 'plane'
})
-- local obj = scene.addobj('/res/ct/container.glb')

function delete(obj)
    obj:setpos(999, 999, 999)
    obj = nil
end

function RMG(cy)
    -- 初始化对象
    local rmg = scene.addobj('/res/ct/rmg.glb')
    local trolley = scene.addobj('/res/ct/trolley.glb')
    local spreader = scene.addobj('/res/ct/spreader.glb')
    local wirerope = scene.addobj('/res/ct/wirerope.glb')

    -- 参数设置
    rmg.type = "rmg" --对象种类标识(interface)
    rmg.cy = cy -- 初始化对应堆场
    rmg.cy.rmg = rmg -- 堆场对应rmg
    rmg.level = {}
    for i = 1, #cy.levels do
        rmg.level[i] = cy.levels[i] + cy.cheight
    end
    rmg.level.agv = 2.1 -- agv高度
    rmg.spreaderpos = {0, rmg.level[2], 0} -- 初始位置(x,y)
    rmg.pos = 0 -- 初始位置(x,y,z)
    rmg.tasksequence = {} -- 初始化任务队列
    rmg.iox = -16 -- 进出口x坐标
    rmg.speed = 4 -- 移动速度
    rmg.attached = nil -- 抓取的集装箱
    rmg.stash = nil -- io物品暂存

    cy:initqueue(rmg.iox) -- 初始化停车队列

    -- 初始化位置
    rmg.origin = cy.origin -- 原点
    rmg:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置车的位置
    trolley:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置trolley的位置
    wirerope:setscale(1, rmg.origin[2] + 17.57 - rmg.spreaderpos[2], 1) -- trolly离地面高度17.57，wirerope长宽设为1
    wirerope:setpos(rmg.origin[1] + rmg.spreaderpos[1], rmg.origin[2] + 1.15 + rmg.spreaderpos[2], rmg.origin[3] + 0) -- spreader高度1.1
    spreader:setpos(rmg.origin[1] - 0.01 + rmg.spreaderpos[1], rmg.origin[2] + rmg.spreaderpos[2] + 0.05,
        rmg.origin[3] + .012)
    -- trolley:setpos(0,0,0)

    rmg.trolley = trolley
    rmg.spreader = spreader
    rmg.wirerope = wirerope

    -- 函数
    -- 抓箱子
    function rmg:attach(row, col, level)
        print("rmg attach(", row, ",", col, ",", level, ")=", rmg.cy.containers[row][col][level])
        rmg.attached = rmg.cy.containers[row][col][level]
        rmg.cy.containers[row][col][level] = nil
        print("rmg.cy.containers[", row, "][", col, "][", level, "]=", rmg.cy.containers[row][col][level])
        print("rmg.attached=", rmg.attached)
    end

    -- 放箱子
    function rmg:detach()
        rmg.stash = rmg.attached
        rmg.attached = nil
    end

    -- 爪子移动
    -- x移动：横向；y移动：上下；z移动(负方向)：纵向(微调,不常用)
    function rmg:spreadermove(dx, dy, dz)
        rmg.spreaderpos = {rmg.spreaderpos[1] + dx, rmg.spreaderpos[2] + dy, rmg.spreaderpos[3] + dz}
        local wx, wy, wz = rmg.wirerope:getpos()
        local sx, sy, sz = rmg.spreader:getpos()
        local tx, ty, tz = rmg.trolley:getpos()

        rmg.wirerope:setpos(wx + dx, wy + dy, wz - dz)
        rmg.wirerope:setscale(1, 17.57 - wy - dy, 1)
        rmg.trolley:setpos(tx + dx, ty, tz)
        rmg.spreader:setpos(sx + dx, sy + dy, sz - dz)

        -- 移动箱子
        if rmg.attached then
            local cx, cy, cz = rmg.attached:getpos()
            rmg.attached:setpos(cx + dx, cy + dy, cz - dz)
        end
    end

    -- 移动到指定位置
    function rmg:spreadermove2(x, y, z)
        rmg:spreadermove(x - rmg.spreaderpos[1], y - rmg.spreaderpos[2], z - rmg.spreaderpos[3])
    end

    -- 车移动(-z方向)
    function rmg:move(dist)
        rmg.pos = rmg.pos + dist
        local wx, wy, wz = rmg.wirerope:getpos()
        local sx, sy, sz = rmg.spreader:getpos()
        local tx, ty, tz = rmg.trolley:getpos()
        local rx, ry, rz = rmg:getpos()

        rmg.wirerope:setpos(wx, wy, wz + dist)
        rmg.spreader:setpos(sx, sy, sz + dist)
        rmg.trolley:setpos(tx, ty, tz + dist)
        rmg:setpos(rx, ry, rz + dist)

        -- 移动箱子
        if rmg.attached then
            local cx, cy, cz = rmg.attached:getpos()
            rmg.attached:setpos(cx, cy, cz + dist)
        end
    end

    -- task: {任务名称,{参数}}
    function rmg:executeTask(dt)
        if #rmg.tasksequence == 0 then
            return
        end

        local task = rmg.tasksequence[1]
        local taskname, param = task[1], task[2]
        if taskname == "movespread" then -- {"movespread",{x,y,z}} 各方向移动多少
            local d = param -- 导入距离

            -- 计算移动值
            local ds = {}
            for i = 1, 3 do
                ds[i] = param.speed[i] * dt -- speed已经包括方向
                d[i + 6] = d[i + 6] + ds[i]
                -- print("d[", i + 6, "]=", d[i + 6])
            end

            -- 判断是否到达目标
            for i = 1, 3 do
                -- print("d[", i, "]=", d[i], "d[",i+6,"]=",d[i+6]," d[", i + 6, "]/d[", i, "]=", d[i + 6] / d[i])
                if d[i] ~= 0 and d[i + 6] / d[i] >= 1 then -- 分方向到达目标
                    rmg:deltask()
                    rmg:spreadermove2(d[1] + d[10], d[2] + d[11], d[3] + d[12]) -- 直接设定到目标位置
                    return
                end
            end

            rmg:spreadermove(ds[1], ds[2], ds[3]) -- 移动差量
        elseif taskname == "move2" then -- 1:col(x), 2:height(y), 3:bay(z), [4:初始bay, 5:已移动bay距离,向量*2(6,7),当前位置*2(8,9),初始位置*2(10,11),到达(12,13)*2]
            local ds = {}
            -- 计算移动值
            for i = 1, 2 do
                ds[i] = param.speed[i] * dt -- dt移动
                -- print("ds[",i,"]=",ds[i])
                param[i + 7] = param[i + 7] + ds[i] -- 累计移动
            end
            ds[3] = param.speed[3] * dt -- rmg向量速度*时间

            if not param[12] then -- bay方向没有到达目标                
                if param[5] / (param[3] - param[4]) > 1 then -- 首次到达目标
                    -- rmg:deltask()
                    rmg:move(param[5] - param[3] + param[4])
                    param[12] = true
                else
                    param[5] = param[5] + ds[3] -- 已移动bay
                    rmg:move(ds[3])
                end
            end

            if not param[13] then -- 列方向没有到达目标
                for i = 1, 2 do
                    if param[i + 5] ~= 0 and (param[i] - param[i + 7]) * param[i + 5] <= 0 then -- 分方向到达目标
                        -- rmg:deltask()
                        rmg:spreadermove2(param[1], param[2], 0)
                        -- return
                        param[13] = true
                        break
                    end
                end
                rmg:spreadermove2(param[8], param[9], 0) -- 设置到累计移动值
            end

            if param[12] and param[13] then
                -- print("param 12 and 13:", param[12], ",", param[13])
                rmg:deltask()
            end

        elseif taskname == "attach" then -- {"attach", {cy.row,cy.col,cy.level}}
            rmg:attach(param[1], param[2], param[3])
            rmg:deltask()
        elseif taskname == "detach" then -- {"detach", nil}
            rmg:detach()
            rmg:deltask()
        end
    end

    -- interface:计算最大允许步进
    function rmg:maxstep()
        local dt = math.huge -- 初始化步进
        if rmg.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = rmg.tasksequence[1][1] -- 任务名称
        local param = rmg.tasksequence[1][2] -- 任务参数
        if taskname == "movespread" then
            -- print("maxstep: movespread")
            if param[4] == nil then -- 没有执行记录，创建
                for i = 1, 3 do
                    if param[i] == 0 then -- 无移动，向量设为0
                        param[i + 3] = 0
                    else
                        param[i + 3] = param[i] / math.abs(param[i]) -- 计算向量(4~6)
                    end
                    param[i + 6] = 0 -- 已移动距离(7~9)
                    param[i + 9] = rmg.spreaderpos[i] -- 初始位置(10~12)
                    -- print("d[", i, "]=", d[i], " d[", i + 3, "]=", d[i + 3], "d[", i + 6, "]=", d[i + 6], " d[", i + 9, "]=", d[i + 9])
                end

                -- 计算各方向分速度
                local l = math.sqrt(param[4] ^ 2 + param[5] ^ 2 + param[6] ^ 2)
                param.speed = {param[4] / l * rmg.speed, param[5] / l * rmg.speed, param[6] / l * rmg.speed} -- 向量*速度
            end

            for i = 1, 3 do
                if param[i] ~= 0 then -- 只要分方向移动，就计算最大步进
                    dt = math.min(dt, math.abs((param[i] - param[i + 6]) / param.speed[i])) -- 根据movespread判断条件
                end
            end
        elseif taskname == "move2" then
            -- print("maxstep: move2")
            if param[4] == nil then
                param[4] = rmg.pos -- 初始位置
                param[5] = 0 -- 已经移动的距离
                for i = 1, 2 do
                    param[i + 7] = rmg.spreaderpos[i] -- 当前位置(8,9)
                    param[i + 9] = rmg.spreaderpos[i] -- 初始位置(10,11)
                    if param[i] - param[i + 9] == 0 then -- 目标距离差为0，向量设为0
                        param[i + 5] = 0
                    else
                        param[i + 5] = param[i] - param[i + 9] -- 计算初始向量
                    end
                end
                param[12], param[13] = param[3] == param[4], false

                -- 计算各方向分速度
                local l = math.sqrt(param[6] ^ 2 + param[7] ^ 2)
                param.speed = {param[6] / l * rmg.speed, param[7] / l * rmg.speed,
                               rmg.speed * ((param[3] - rmg.pos) / math.abs(param[3] - rmg.pos))} -- speed[3]:速度乘方向
            end

            if not param[12] then -- bay方向没有到达目标
                dt = math.min(dt, math.abs((param[3] - param[4] - param[5]) / param.speed[3]))
                -- if dt < 0 then --debug
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
        elseif taskname == "attach" or taskname == "detach" then
            print("maxstep: attach or detach")
            dt = math.min(dt, 1) -- 假设装卸1秒
        end
        return dt
    end

    -- 添加任务
    function rmg:addtask(obj)
        table.insert(rmg.tasksequence, obj)
        print("rmg:addtask(): ", rmg.tasksequence[#rmg.tasksequence][1], ", task count:", #rmg.tasksequence)
    end

    -- 删除任务
    function rmg:deltask()
        print("rmg:deltask(): ", rmg.tasksequence[1][1], ", task count:", #rmg.tasksequence)
        table.remove(rmg.tasksequence, 1)

        if (rmg.tasksequence[1] ~= nil) then
            print("task executing: ", rmg.tasksequence[1][1])
        end
    end

    -- 获取爪子移动坐标（x,y)
    function rmg:getcontainercoord(bay, level, col)
        local x
        if col == -1 then
            x = rmg.iox
        else
            x = cy.pos[1][col][1][1] - rmg.origin[1]
        end

        local ry = 0 -- 相对高度
        if col == -1 and level == 1 then -- 如果是要放下，则设置到移动到agv上
            ry = ry + rmg.level.agv -- 加上agv高度
        end
        ry = ry + rmg.level[level] -- 加上层高
        local y = ry - rmg.origin[2]
        -- print("rmg.origin[1]=",rmg.origin[1]," rmg.iox=",rmg.iox," x=",x)
        local z = cy.pos[bay][1][1][3] - cy.origin[3] -- 通过车移动解决z

        -- print("go (", bay, ",", level, ",", col, ")->(x", x, ",y", y, ",z", z, ")")
        return {x, y, z}
    end

    -- 获取爪子移动坐标长度（x,y)
    function rmg:getcontainerdelta(dcol, dlevel)
        local dx = dcol * (cy.cwidth + cy.cspan)
        local dy = dlevel * rmg.level[1]
        local dz = 0 -- 通过车移动解决z

        -- print("原版爪移动delta：dx=", dx, " ,dy=", dy)
        return {dx, dy, dz}
    end

    -- 获取车移动坐标（z）
    function rmg:getlen(bay)
        -- print("原版车移动：", cy.pos[bay][1][2] - cy.origin[3])
        return {cy.pos[bay][1][1][3] - cy.origin[3]}
    end

    return rmg
end

function AGV(targetcy, targetbay)
    local agv = scene.addobj("/res/ct/agv.glb")
    agv.type = "agv"
    agv.speed = 10
    agv.targetCY = targetcy -- 目标堆场
    agv.targetbay = targetbay -- 目标bay
    agv.tasksequence = {} -- 初始化任务队列
    agv.container = nil -- 初始化集装箱
    agv.height = 2.10 -- agv平台高度

    function agv:move(dx, dz)
        local x, _, z = agv:getpos()
        x, z = x + dx, z + dz
        -- agv:setpos(x, 0, z)
        agv:move2(x, 0, z)
    end

    function agv:move2(x, y, z)
        agv:setpos(x, y, z)
        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
        end
    end

    function agv:movenexttask(currentoccupy) -- 添加下一个任务准备移动，无返回值
        local nextoccupy = currentoccupy + 1
        agv.targetCY.parkingspace[currentoccupy].occupied = agv.targetCY.parkingspace[currentoccupy].occupied - 1 -- 释放当前占用

        -- 判断是否到达目标
        if agv.targetCY.parkingspace[currentoccupy].bay == agv.targetbay then -- 到达目标
            print("agv到达目标，准备装卸")
            agv:addtask({"waitrmg", {
                occupy = currentoccupy
            }})
            agv:addtask({"attach", {
                occupy = currentoccupy
            }})
        end

        -- 判断下一个位置
        if nextoccupy > #agv.targetCY.parkingspace then -- 下一个位置是exit
            print("agv下一个位置是exit")
            agv:addtask({"move2", {agv.targetCY.exit[1], agv.targetCY.exit[3]}}) -- 不需要设置occupy，直接设置目标位置
        else
            agv:addtask({"waitagv", {
                occupy = currentoccupy
            }}) -- 等待占用释放
            agv:addtask({"move2", {
                occupy = currentoccupy
            }}) -- 设置移动
            agv.targetCY.parkingspace[nextoccupy].occupied = agv.targetCY.parkingspace[nextoccupy].occupied + 1 -- 占用下一个位置
        end
    end

    function agv:attach()
        agv.container = agv.targetCY.rmg.stash
        agv.targetCY.rmg.stash = nil
    end

    function agv:executeTask(dt) -- 执行任务 task: {任务名称,{参数}}
        if agv.tasksequence[1] == nil then
            return
        end

        local task = agv.tasksequence[1]
        local taskname, param = task[1], task[2]
        if taskname == "move2" then -- {"move2",x,z,[occupy=1]} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
            local ds = {param.speed[1] * dt, param.speed[2] * dt} -- xz方向移动距离
            param[5], param[6] = param[5] + ds[1], param[6] + ds[2] -- xz方向已经移动的距离

            -- 判断是否到达
            for i = 1, 2 do
                if param[i + 2] ~= 0 and (param[i] - param[i + 6] - param[i + 4]) * param[i + 2] <= 0 then -- 如果分方向到达则视为到达
                    agv:move2(param[1], 0, param[2])
                    agv:deltask()

                    -- 如果有占用道路位置，则设置下一个占用
                    if param.occupy ~= nil then
                        agv:movenexttask(param.occupy + 1)
                    end
                    return
                end
            end

            -- 设置步进移动
            agv:move2(param[7] + param[5], 0, param[8] + param[6])
        elseif taskname == "attach" then
            print("exec agv attach task, agv.targetCY.rmg.stash=", agv.targetCY.rmg.stash, " ,agv.container=", agv.container)
            if agv.targetCY.rmg.stash ~= nil then
                agv:attach()
                print("agv.contaienr=", agv.container)
                agv:deltask()
                -- agv:movenexttask(param.occupy)
            end
        elseif taskname == "waitagv" then -- {"waitagv",{occupy}} 等待前方agv移动 occupy:当前占用道路位置
            -- 如果前面是exit则不适用于使用此任务
            -- 检测前方占用，如果占用则等待；否则删除任务，根据条件添加move2
            if agv.targetCY.parkingspace[param.occupy + 1].agv == nil then
                agv:deltask()
                -- agv:movenexttask(param.occupy)
            end
        elseif taskname == "waitrmg" then -- {"waitrmg",{occupy}} 等待rmg移动 occupy:当前占用道路位置
            -- 检测rmg.stash是否为空，如果为空则等待；否则进行所有权转移，并设置move2
            if agv.targetCY.rmg.stash ~= nil then
                -- print("agv.targetCY.rmg.stash=",agv.targetCY.rmg.stash)
                agv:deltask()
                -- agv:movenexttask(param.occupy)
            end
        end
        -- todo:move2设置占用
    end

    -- 添加任务
    function agv:addtask(obj)
        table.insert(agv.tasksequence, obj)
        print("agv:addtask(): ", agv.tasksequence[#agv.tasksequence][1], ", task count:", #agv.tasksequence)
    end

    -- 删除任务
    function agv:deltask()
        print("agv:deltask(): ", agv.tasksequence[1][1], ", task count:", #agv.tasksequence)
        table.remove(agv.tasksequence, 1)

        if (agv.tasksequence[1] ~= nil) then
            print("task executing: ", agv.tasksequence[1][1])
        end
    end

    function agv:maxstep() -- 初始化和计算最大允许步进时间
        local dt = math.huge -- 初始化步进
        if agv.tasksequence[1] == nil then -- 对象无任务，直接返回0
            return dt
        end

        local taskname = agv.tasksequence[1][1] -- 任务名称
        local param = agv.tasksequence[1][2] -- 任务参数

        if taskname == "move2" then -- {"move2",x,z,[occupy=,]} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
            -- 初始判断
            if param[3] == nil then
                if param.occupy ~= nil then -- 占用车位要求判断
                    -- print("param.occpy=",param.occupy)
                    -- agv.targetCY.parkingspace[param.occupy].occupied = agv.targetCY.parkingspace[param.occupy].occupied - 1 -- 解除占用当前车位
                    -- if param.occupy + 1 <= #agv.targetCY.parkingspace then
                    --     agv.targetCY.parkingspace[param.occupy + 1].occupy = agv.targetCY.parkingspace[param.occupy + 1].occupy + 1 -- 占用下一个车位
                    -- end
                    -- 设置目标位置
                    param[1], param[2] = agv.targetCY.parkingspace[param.occupy + 1].pos[1],
                        agv.targetCY.parkingspace[param.occupy + 1].pos[3] -- 设置目标xz坐标
                    print("agv移动目标", " currentoccupy=", param.occupy, " x,z=", param[1], param[2])
                end

                local x, _, z = agv:getpos() -- 获取当前位置
                param[3] = param[1] - x -- x方向需要移动的距离
                param[4] = param[2] - z -- z方向需要移动的距离
                if param[3] == 0 and param[4] == 0 then
                    print("agv不需要移动", " currentoccupy=", param.occupy)
                    agv:deltask()
                    return
                end

                param[5], param[6] = 0, 0 -- xz方向已经移动的距离
                param[7], param[8] = x, z -- xz方向初始位置

                local l = math.sqrt(param[3] ^ 2 + param[4] ^ 2)
                param.speed = {param[3] / l * agv.speed, param[4] / l * agv.speed} -- xz向量速度分量
            end

            for i = 1, 2 do
                if param[i + 2] ~= 0 then -- 只要分方向移动，就计算最大步进
                    dt = math.min(dt, math.abs((param[i] - param[i + 6] - param[i + 4]) / param.speed[i]))
                end
            end
        end
        return dt
    end

    return agv
end

function CY(p1, p2, level)
    local cy = {
        clength = 6.06,
        cwidth = 2.44,
        cheight = 2.42,
        cspan = 0.6,
        pos = {}, -- 初始化
        containers = {}, -- 集装箱对象(相对坐标)
        parkingspace = {}, -- 停车位对象(相对坐标)
        origin = {(p1[1] + p2[1]) / 2, 0, (p1[2] + p2[2]) / 2}, -- 参照点
        queuelen = 6, -- 服务队列长度（额外）
        summon = {}, -- 车生成点
        exit = {} -- 车出口
    }

    -- 显示堆场锚点
    local p1obj = scene.addobj("points", {
        vertices = {p1[1], 0, p1[2]},
        color = "blue",
        size = 10
    })
    local p2obj = scene.addobj("points", {
        vertices = {p2[1], 0, p2[2]},
        color = "red",
        size = 10
    })

    -- print("#p2=",#p2," #p1=",#p1)
    local pdx = (p2[1] - p1[1]) / math.abs(p1[1] - p2[1])
    local pdy = (p2[2] - p1[2]) / math.abs(p1[2] - p2[2])

    -- 计算属性
    cy.dir = {pdx, pdy} -- 方向
    cy.width, cy.length = math.abs(p1[1] - p2[1]), math.abs(p1[2] - p2[2])
    -- print("cy.length = ",cy.length," cy.width = ",cy.width, "cwidth, clength = ",cy.cwidth,",",cy.clength)
    cy.col = math.floor((cy.width + cy.cspan) / (cy.cwidth + cy.cspan)) -- 列数
    cy.row = math.floor((cy.length + cy.cspan) / (cy.clength + cy.cspan)) -- 行数
    cy.marginx = (cy.width + cy.cspan - (cy.cwidth + cy.cspan) * cy.col) / 2 -- 横向外边距
    -- print("cy row,col = ",cy.row, ",",cy.col," xmargin = ",cy.marginx, " cspan = ",cy.cspan)

    -- 集装箱层数
    cy.levels = {} -- 层数y坐标集合
    cy.level = level
    for i = 1, level + 2 do
        cy.levels[i] = cy.cheight * (i - 1)
    end

    for i = 1, cy.row do
        cy.pos[i] = {} -- 初始化
        cy.containers[i] = {}
        for j = 1, cy.col do
            cy.pos[i][j] = {}
            cy.containers[i][j] = {}
            for k = 1, cy.level do
                cy.pos[i][j][k] = {p1[1] + pdx * (cy.marginx + (j - 1) * (cy.cwidth + cy.cspan) + cy.cwidth / 2),
                                   cy.origin[2] + cy.levels[k],
                                   p1[2] + pdy * ((i - 1) * (cy.clength + cy.cspan) + cy.clength / 2)}
                cy.containers[i][j][k] = scene.addobj('/res/ct/container.glb')
                cy.containers[i][j][k]:setpos(cy.pos[i][j][k][1], cy.pos[i][j][k][2], cy.pos[i][j][k][3])

                -- print("container[",i,",",j,"]=(",cy.pos[i][j][1],",",cy.pos[i][j][2],")")
            end
        end
    end

    function cy:initqueue(iox) -- 初始化队列(cy.parkingspace) iox出入位置x相对坐标
        -- 停车队列(iox)
        cy.parkingspace = {} -- 属性：occupied:停车位占用情况，pos:停车位坐标，bay:对应堆场bay位

        -- 停车位
        for i = 1, cy.row do
            cy.parkingspace[i] = {} -- 初始化
            cy.parkingspace[i].occupied = 0 -- 0:空闲，1:临时占用，2:作业占用
            -- print("cy.origin=",cy.origin[1],",",cy.origin[2])
            cy.parkingspace[i].pos = {cy.origin[1] + iox, 0, cy.origin[3] + cy.pos[cy.row - i + 1][1][1][3]} -- x,y,z
            cy.parkingspace[i].bay = cy.row - i + 1
            local sign = scene.addobj("box")
            sign:setpos(table.unpack(cy.parkingspace[i].pos))
        end

        local lastbaypos = cy.parkingspace[1].pos -- 记录最后一个添加的位置

        -- 队列停车位
        for i = 1, cy.queuelen do
            local pos = {lastbaypos[1], 0, lastbaypos[3] - i * (cy.clength + cy.cspan)}
            table.insert(cy.parkingspace, 1, {
                occupied = 0,
                pos = pos
            }) -- 无对应bay
            -- print("队列位置=", cy.queuelen - i + 1, " pos={", pos[1], ",", pos[2], ",", pos[3], "}")
            local sign = scene.addobj("box")
            sign:setpos(table.unpack(cy.parkingspace[1].pos))
        end

        -- unittest debug
        for i = 1, #cy.parkingspace do
            print("parkingspace[", i, "] = ", cy.parkingspace[i].pos[3], " bay = ", cy.parkingspace[i].bay)
        end

        cy.summon = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[1].pos[3]}
        cy.exit = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[#cy.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    return cy
end

-- 创建堆场
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)
-- local cy2 = CY({19.66 / 2, 150 / 2}, {-19.66 / 2, 65 / 2}, 3)

-- 分配堆场给场桥
local rmg = RMG(cy)
-- local rmg2 = RMG(cy2)

-- print("cy.origin = ", cy.origin[1], ",", cy.origin[2])
-- print("rmg.origin = ", rmg.origin[1], ",", rmg.origin[2])

-- 添加任务 rmg1
rmg:addtask({"move2", rmg:getcontainercoord(2, 4, 3)}) -- 移动爪子到指定位置
rmg:addtask({"movespread", rmg:getcontainerdelta(0, -1)}) -- 移动爪子到指定高度
rmg:addtask({"attach", {2, 3, 3}}) -- 抓取指定箱
rmg:addtask({"movespread", rmg:getcontainerdelta(0, 2)}) -- 移动爪子到指定高度
rmg:addtask({"move2", rmg:getcontainercoord(2, 5, -1)}) -- 移动爪子到指定位置
rmg:addtask({"move2", rmg:getcontainercoord(2, 1, -1)}) -- 放下箱子
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -2)}) -- 移动爪子到指定高度
rmg:addtask({"detach"}) -- 放下指定箱
-- rmg:addtask({"move2", rmg:getcontainercoord(3, 2, 1)}) -- 移动爪子到指定位置
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -1)}) -- 移动爪子到指定高度
-- rmg:addtask({"attach", {3, 1}}) -- 抓取指定箱
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, 2)}) -- 移动爪子到指定高度
-- rmg:addtask({"move2", rmg:getcontainercoord(3, 3, -1)}) -- 移动爪子到指定位置
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -2)}) -- 移动爪子到指定高度
-- rmg:addtask({"detach"}) -- 放下指定箱
-- rmg:addtask({"move2", rmg:getcontainercoord(5, 3, 4)}) -- 移动爪子到指定位置
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -2)}) -- 移动爪子到指定高度
-- rmg:addtask({"attach", {5, 4}}) -- 抓取指定箱
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, 2)}) -- 移动爪子到指定高度
-- rmg:addtask({"move2", rmg:getcontainercoord(5, 3, -1)}) -- 移动爪子到指定位置
-- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -2)}) -- 移动爪子到指定高度
-- rmg:addtask({"detach"}) -- 放下指定箱

-- -- 添加任务 rmg2
-- rmg2:addtask({"move2", rmg2:getcontainercoord(5, 2, 5)}) -- 移动爪子到指定位置
-- rmg2:addtask({"movespread", rmg2:getcontainerdelta(0, -1)}) -- 移动爪子到指定高度
-- rmg2:addtask({"attach", {5, 5}}) -- 抓取指定箱
-- rmg2:addtask({"movespread", rmg2:getcontainerdelta(0, 2)}) -- 移动爪子到指定高度
-- rmg2:addtask({"move2", rmg2:getcontainercoord(5, 2, -1)}) -- 移动爪子到指定位置
-- rmg2:addtask({"movespread", rmg2:getcontainerdelta(0, -1)}) -- 移动爪子到指定高度
-- rmg2:addtask({"detach"}) -- 放下指定箱
-- rmg2:addtask({"move2", rmg2:getcontainercoord(3, 3, 1)}) -- 移动爪子到指定位置

local agv = AGV(cy, 2)
agv:setpos(table.unpack(cy.summon))
agv:addtask({"move2", {
    occupy = 1
}})
-- agv:addtask({"move2", {0, 10}})
-- agv:addtask({"move2", {10, 10}})
-- agv:addtask({"move2", {10, 0}})
-- agv:addtask({"move2", {0, 0}})

-- 存在任务序列的对象列表
-- local actionobj = {rmg, rmg2, agv}
local actionobj = {rmg, agv}

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
        if obj.container~=nil then
            obj.container:delete()
        end
        obj:delete()
    end
end

-- 初始时间
local t = os.clock()
local dt = 0

function update()
    coroutine.queue(dt, update)

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
        if #obj.tasksequence==0 then
            recycle(obj)
        end
    end

    -- 绘图
    scene.render()

    -- 刷新时间间隔
    dt = os.clock() - t
    -- print("dt = ", dt, " maxstep = ", maxstep)
    dt = math.min(dt, maxstep)
    t = os.clock()
end

update()
