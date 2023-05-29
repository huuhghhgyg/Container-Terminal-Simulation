scene.setenv({
    grid = 'plane'
})
-- local obj = scene.addobj('/res/ct/container.glb')

-- 程序控制
local runcommand = true

-- 参数设置
local simv = 5 -- 仿真速度
local actionobj = {} -- 动作队列声明
local agvSummonSpan = 46 -- agv生成间隔

function RMG(cy)
    -- 初始化对象
    local rmg = scene.addobj('/res/ct/rmg.glb')
    local trolley = scene.addobj('/res/ct/trolley.glb')
    local spreader = scene.addobj('/res/ct/spreader.glb')
    local wirerope = scene.addobj('/res/ct/wirerope.glb')

    -- 参数设置
    rmg.type = "rmg" -- 对象种类标识(interface)
    rmg.cy = cy -- 初始化对应堆场
    rmg.cy.rmg = rmg -- 堆场对应rmg
    rmg.level = {}
    for i = 1, #cy.levels do
        rmg.level[i] = cy.levels[i] + cy.cheight
    end
    rmg.toplevel = #rmg.level -- 最高层(吊具行走层)
    rmg.level.agv = 2.1 -- agv高度
    rmg.spreaderpos = {0, rmg.level[2], 0} -- 初始位置(x,y)
    rmg.pos = 0 -- 初始位置(x,y,z)
    rmg.tasksequence = {} -- 初始化任务队列
    rmg.iox = -16 -- 进出口x坐标
    rmg.speed = 4 -- 移动速度
    rmg.zspeed = 2 -- 车移动速度
    rmg.attached = nil -- 抓取的集装箱
    rmg.stash = nil -- io物品暂存
    rmg.agvqueue = {} -- agv服务队列
    rmg.bay = nil

    cy:initqueue(rmg.iox) -- 初始化停车队列

    -- 初始化位置
    rmg.origin = cy.origin -- 原点
    rmg:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置车的位置
    trolley:setpos(rmg.origin[1], rmg.origin[2], rmg.origin[3]) -- 设置trolley的位置
    wirerope:setscale(1, rmg.origin[2] + 17.57 - rmg.spreaderpos[2], 1) -- trolly离地面高度17.57，wirerope长宽设为1
    wirerope:setpos(rmg.origin[1] + rmg.spreaderpos[1], rmg.origin[2] + 1.15 + rmg.spreaderpos[2], rmg.origin[3] + 0) -- spreader高度1.1
    spreader:setpos(rmg.origin[1] - 0.01 + rmg.spreaderpos[1], rmg.origin[2] + rmg.spreaderpos[2] + 0.05,
        rmg.origin[3] + 0.012)
    -- trolley:setpos(0,0,0)

    rmg.trolley = trolley
    rmg.spreader = spreader
    rmg.wirerope = wirerope

    -- 函数
    -- 注册agv
    function rmg:registeragv(agv)
        local targetcontainer = agv.targetcontainer -- 获取目标集装箱
        agv.worktype = "rmg" -- 正在为rmg工作
        table.insert(rmg.agvqueue, agv) -- 加入agv队列
        for i = 1, rmg.cy.agvspan do
            rmg.cy.parkingspace[i].occupied = rmg.cy.parkingspace[i].occupied + 1 -- 停车位占用数+1
        end
        table.insert(actionobj, agv) -- 加入动作队列

        rmg:attachcontainer(table.unpack(targetcontainer)) -- 抓取集装箱
        rmg:addtask({"waitagv"}) -- 等待agv到达
        rmg:lift2agv(targetcontainer[1], targetcontainer[2]) -- 将抓住的集装箱移动到agv上
    end

    -- 抓箱子
    function rmg:attach(row, col, level)
        rmg.attached = rmg.cy.containers[row][col][level]
        rmg.cy.containers[row][col][level] = nil
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
                    -- rmg:deltask()
                    rmg:move(param[3] - param[4] - param[5])
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
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmg.agvqueue[1] == nil then
                -- rmg:deltask()
                print("rmg: rmg.agvqueue[1]=nil, #rmg.agvqueue=", #rmg.agvqueue)
            end
            -- print("rmg: waiting agv")
            if rmg.agvqueue[1] ~= nil and rmg.agvqueue[1].arrived then -- agv到达
                table.remove(rmg.agvqueue, 1) -- 移除等待的agv
                rmg:deltask()
            end
        elseif taskname == "attach" then -- {"attach", {cy.row,cy.col,cy.level}}
            rmg:attach(param[1], param[2], param[3])
            rmg.bay = param[1]
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
        if taskname == "move2" then
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
                               rmg.zspeed * ((param[3] - rmg.pos) / math.abs(param[3] - rmg.pos))} -- speed[3]:速度乘方向
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
    function rmg:addtask(obj)
        table.insert(rmg.tasksequence, obj)
        -- print("rmg:addtask(): ", rmg.tasksequence[#rmg.tasksequence][1], ", task count:", #rmg.tasksequence)
    end

    -- 删除任务
    function rmg:deltask()
        -- print("rmg:deltask(): ", rmg.tasksequence[1][1], ", task count:", #rmg.tasksequence)
        table.remove(rmg.tasksequence, 1)

        if (rmg.tasksequence[1] ~= nil and rmg.tasksequence[1][1] == "detach") then
            print("[rmg] task executing: ", rmg.tasksequence[1][1])
        end
    end

    -- 获取爪子移动坐标（x,y)
    function rmg:getcontainercoord(bay, col, level)
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

    -- 添加任务，抓取指定位置的集装箱
    function rmg:attachcontainer(bay, col, level)
        -- todo: 考虑翻箱
        rmg:addtask({"move2", rmg:getcontainercoord(bay, col, rmg.toplevel)}) -- 移动爪子到指定位置
        rmg:addtask({"move2", rmg:getcontainercoord(bay, col, level)}) -- 移动爪子到指定位置
        rmg:addtask({"attach", {bay, col, level}}) -- 抓取指定箱
    end

    -- 添加任务，将attached的集装箱放到agv上
    function rmg:lift2agv(bay, col)
        rmg:addtask({"move2", rmg:getcontainercoord(bay, col, rmg.toplevel)}) -- 将集装箱从目标向上提升
        rmg:addtask({"move2", rmg:getcontainercoord(bay, -1, rmg.toplevel)}) -- 移动集装箱到agv对应列
        rmg:addtask({"move2", rmg:getcontainercoord(bay, -1, 1)}) -- 放下箱子到agv上
        rmg:addtask({"detach"}) -- 放下指定箱
        rmg:addtask({"move2", rmg:getcontainercoord(bay, -1, rmg.toplevel)}) -- 吊具提升到移动层
    end

    return rmg
end

function AGV(targetcy, targetcontainer) -- 目标堆场，目标集装箱{bay, col, level}
    local agv = scene.addobj("/res/ct/agv.glb")
    agv.type = "agv"
    agv.speed = 10
    agv.datamodel = targetcy -- 目标堆场(数据模型)
    agv.operator = targetcy.rmg -- 目标场桥(操作器)
    agv.targetcontainer = targetcontainer -- 目标集装箱{bay, col, level}
    agv.targetbay = targetcontainer[1] -- 目标bay
    agv.tasksequence = {} -- 初始化任务队列
    agv.container = nil -- 初始化集装箱
    agv.height = 2.10 -- agv平台高度
    agv.arrived = false -- 是否到达目标
    agv.operator:registeragv(agv)

    function agv:move2(x, y, z)
        agv:setpos(x, y, z)
        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
        end
    end

    function agv:movenexttask(currentoccupy) -- 添加下一个任务准备移动，无返回值。只有当当前车位的任务完成后才应调用
        local nextoccupy = currentoccupy + 1

        -- -- debug 
        -- agv.datamodel:getstate()
        -- print("waitagv param.occpy=", currentoccupy, "currentoccupy+2=", currentoccupy + 2,
        --     " #agv.datamodel.parkingspace=", #agv.datamodel.parkingspace)

        -- 判断下一个位置
        -- print("agv:movenexttask\t(occupy: ", currentoccupy, ")=============================")
        -- print("nextoccupy:", nextoccupy, "\t#agv.datamodel.parkingspace:", #agv.datamodel.parkingspace,"\t#agv.operator.agvqueue = ",#agv.operator.agvqueue)
        if nextoccupy > #agv.datamodel.parkingspace then -- 下一个位置是exit
            -- print("[agv] 下一个位置是exit")
            agv:addtask({"move2", {
                occupy = currentoccupy
            }}) -- 不需要设置occupy，直接设置目标位置
            -- if agv.operator.nextstep == nil then --如果没有下一个站点，直接移动到exit
            --     agv:addtask({"move2",{agv.datamodel.exit[1],agv.datamodel.exit[3]}})
            --     print("agv直接移动到exit, #agv.operator.agvqueue = ", #agv.operator.agvqueue)
            -- else
            if agv.operator.nextstep ~= nil then -- 如果没有下一个站点，直接移动到exit
                -- print("onboard toward: ", agv.operator.nextstep)
                agv:addtask({"onboard", {agv.operator.nextstep}})
            end
            -- print("#agv.tasksequence=",#agv.tasksequence) --debug

            return -- 不需要判断，直接返回流程
        end

        -- print("添加waitagv和move2(occupy: ", currentoccupy, ")")
        -- 等待下一个占用释放并移动
        agv:addtask({"waitagv", {
            occupy = currentoccupy
        }}) -- 等待占用释放
        agv:addtask({"move2", {
            occupy = currentoccupy
        }}) -- 设置移动

        -- 判断下一个是否到达目标
        if agv.datamodel.parkingspace[nextoccupy].bay == agv.targetbay then -- 到达目标
            -- print("下一个occupy为agv目标，添加waitrmg和attach(occupy: ", nextoccupy, ")")
            agv.arrived = true -- 设置agv到达目标标识
            if agv.worktype == "rmg" then -- 为rmg工作
                agv:addtask({"waitrmg", {
                    occupy = nextoccupy
                }})
                agv:addtask({"attach", {
                    occupy = nextoccupy
                }})
            else -- 为rmgqc工作
                agv:addtask({"waitrmgqc", {
                    occupy = nextoccupy
                }})
            end
        end

        -- print("#agv.tasksequence=",#agv.tasksequence) --debug
    end

    function agv:attach()
        agv.container = agv.operator.stash
        agv.operator.stash = nil
    end

    function agv:executeTask(dt) -- 执行任务 task: {任务名称,{参数}}
        if agv.tasksequence[1] == nil then
            return
        end

        local task = agv.tasksequence[1]
        local taskname, param = task[1], task[2]
        -- print("[agv] executeTask: ",taskname)
        if taskname == "move2" then -- {"move2",x,z,[occupy=1]} 移动到指定位置 {x,z, 向量距离*2(3,4), moved*2(5,6), 初始位置*2(7,8)},occupy:当前占用道路位置
            if param.speed == nil then
                agv:maxstep()
            end

            local ds = {param.speed[1] * dt, param.speed[2] * dt} -- xz方向移动距离
            param[5], param[6] = param[5] + ds[1], param[6] + ds[2] -- xz方向已经移动的距离

            -- 判断是否到达
            for i = 1, 2 do
                if param[i + 2] ~= 0 and (param[i] - param[i + 6] - param[i + 4]) * param[i + 2] <= 0 then -- 如果分方向到达则视为到达
                    agv:move2(param[1], 0, param[2])
                    agv:deltask()

                    -- 如果有占用道路位置，则设置下一个占用
                    if param.occupy ~= nil then
                        -- 解除占用
                        agv.datamodel.parkingspace[param.occupy].occupied =
                            agv.datamodel.parkingspace[param.occupy].occupied - 1 -- 解除占用当前车位                            

                        if param.occupy < #agv.datamodel.parkingspace then
                            agv:movenexttask(param.occupy + 1)
                        end

                        -- print("occupy: ", param.occupy, "\tistargetbay():", agv:istargetbay(param.occupy),
                        --     "\toccupybay:", agv.datamodel.parkingspace[param.occupy].bay, "\ttargetbay:", agv.targetbay)
                        -- print("occupy is target bay: ", agv.targetbay)

                    end
                    return
                end
            end

            -- 设置步进移动
            agv:move2(param[7] + param[5], 0, param[8] + param[6])
        elseif taskname == "attach" then
            if agv.operator.stash ~= nil and agv.targetbay == agv.operator.bay or agv.targetbay==nil then
                agv:attach()
                print("[agv] attached container at ", coroutine.qtime())
                agv:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv",{occupy}} 等待前方agv移动 occupy:当前占用道路位置
            -- 如果前面是exit则不适用于使用此任务
            -- 检测前方占用，如果占用则等待；否则删除任务，根据条件添加move2
            local span = agv.datamodel.agvspan -- agv元胞间隔
            if param.occupy + span > #agv.datamodel.parkingspace or
                agv.datamodel.parkingspace[param.occupy + span].occupied == 0 then -- 前方1格无占用或者前方是exit
                agv:deltask()
                if param.occupy + span <= #agv.datamodel.parkingspace then
                    agv.datamodel.parkingspace[param.occupy + span].occupied =
                        agv.datamodel.parkingspace[param.occupy + span].occupied + 1 -- 占用下一个车位
                end

                -- -- debug 
                -- agv.datamodel:getstate()
                -- print("waitagv param.occpy=", param.occupy, "param.occupy+2=", param.occupy + 2,
                --     " #agv.datamodel.parkingspace=", #agv.datamodel.parkingspace)
            end
        elseif taskname == "waitrmg" then -- {"waitrmg",{occupy}} 等待rmg移动 occupy:当前占用道路位置
            -- 检测rmg.stash是否为空，如果为空则等待；否则进行所有权转移，并设置move2
            if agv.operator.stash ~= nil then
                agv:deltask()
            end
        elseif taskname == "waitrmgqc" then -- {"waitrmgqc",{occupy}} 等待rmg移动 occupy:当前占用道路位置
            if agv.container == nil then
                agv:deltask()
            end
        elseif taskname == "onboard" then
            -- table.remove(agv.operator.agvqueue,1)
            -- print("agv:onboard")
            param[1]:registeragv(agv)
            agv:deltask()
        end
    end

    -- 判断是否目标bay
    function agv:istargetbay(occupy)
        if agv.datamodel.parkingspace[occupy] == nil then
            return false
        end
        return agv.datamodel.parkingspace[occupy].bay == agv.targetbay
    end

    -- 添加任务
    function agv:addtask(obj)
        table.insert(agv.tasksequence, obj)
        -- print("agv:addtask(): ", agv.tasksequence[#agv.tasksequence][1], ", task count:", #agv.tasksequence)
    end

    -- 删除任务
    function agv:deltask()
        -- print("agv:deltask(): ", agv.tasksequence[1][1], ", task count:", #agv.tasksequence)
        table.remove(agv.tasksequence, 1)

        if (agv.tasksequence[1] ~= nil and agv.tasksequence[1][1] == "attach") then
            print("[agv] task executing: ", agv.tasksequence[1][1])
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
                -- print("agv初始化, x,z=",param[1],",",param[2])
                if param.occupy ~= nil then -- 占用车位要求判断
                    -- print("agv初始化，occupy=",param.occupy)
                    -- 设置目标位置
                    if param.occupy == #agv.datamodel.parkingspace then -- 判断当前占用是否为最后一个
                        param[1], param[2] = agv.datamodel.exit[1], agv.datamodel.exit[3] -- 直接设置为出口
                        -- print("agv：当前占用为最后一个，目标设为exit:(",param[1],",",param[2],"), param.occupy=",param.occupy,", #agv.datamodel.parkingspace=",#agv.datamodel.parkingspace)
                    else
                        -- print("agv move2: param.occupy=",param.occupy)
                        param[1], param[2] = agv.datamodel.parkingspace[param.occupy + 1].pos[1],
                            agv.datamodel.parkingspace[param.occupy + 1].pos[3] -- 设置目标xz坐标
                    end
                    -- print("agv移动目标", " currentoccupy=", param.occupy, " x,z=", param[1], param[2])
                end
                -- print("agv初始化最终结果, x,z=",param[1],",",param[2])

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

    -- 初始化agv

    -- initialize
    agv:setpos(table.unpack(agv.datamodel.summon))
    agv:addtask({"waitagv", {
        occupy = 1
    }}) -- 等待第一个车位
    agv:addtask({"move2", {
        occupy = 1
    }}) -- 移动到第一个车位

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
        queuelen = 16, -- 服务队列长度（额外）
        summon = {}, -- 车生成点
        exit = {}, -- 车出口
        agvspan = 2, -- agv间距
        containerUrls = {'/res/ct/container.glb','/res/ct/container_brown.glb','/res/ct/container_blue.glb','/res/ct/container_yellow.glb'}
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
                local url = cy.containerUrls[math.random(1,#cy.containerUrls)] -- 随机选择集装箱颜色
                cy.containers[i][j][k] = scene.addobj(url) -- 添加集装箱
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

            -- 停车位点
            -- local sign = scene.addobj("box")
            -- sign:setpos(table.unpack(cy.parkingspace[i].pos))
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

            -- 停车位点
            -- local sign = scene.addobj("box")
            -- sign:setpos(table.unpack(cy.parkingspace[1].pos))
        end

        cy.summon = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[1].pos[3]}
        cy.exit = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[#cy.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    -- unit test debug
    function cy:getstate()
        for i = 1, #cy.parkingspace do
            print("parkingspace[", i, "] = ", cy.parkingspace[i].pos[3], " bay = ", cy.parkingspace[i].bay,
                " occupied = ", cy.parkingspace[i].occupied)
        end
    end

    return cy
end

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
    -- wirerope:setpos(0,1.1,0)
    -- wirerope:setscale(1,26.54+0.34,1)

    -- 初始化位置
    rmgqc.wirerope:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2] + 1.1, rmgqc.origin[3])
    rmgqc.wirerope:setscale(1, (26.54 + 1.32 - 1.1) - (rmgqc.origin[2]), 1)
    rmgqc.spreader:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc.trolley:setpos(rmgqc.origin[1] + 0, rmgqc.origin[2], rmgqc.origin[3])
    rmgqc:setpos(rmgqc.origin[1], rmgqc.origin[2], rmgqc.origin[3])
    print("初始化：spreader z = ", rmgqc.origin[3])

    function rmgqc:registeragv(agv)
        -- print("rmgqc:registeragv")
        -- 初始化agv
        agv.arrived = false -- 设置到达标识
        agv.targetcontainer = rmgqc.ship:getidlepos() -- 设置目标集装箱位置（船上空余位置）
        agv.targetbay = agv.targetcontainer[1]
        local transfered = agv.worktype ~= nil -- 表示agv的来源是否来自所有权转移，如果是则不需要重复添加到执行队列
        agv.worktype = "rmgqc"
        agv.operator = rmgqc
        agv.datamodel = rmgqc.ship
        -- print("agv初始化完毕")

        -- 为agv添加任务
        agv:addtask({"move2", {agv.datamodel.summon[1], agv.datamodel.summon[3]}})
        -- print("rmgqc summon at: (",agv.datamodel.summon[1],",",agv.datamodel.summon[2],",",agv.datamodel.summon[3],")")
        agv:addtask({"move2", {
            occupy = 1
        }}) -- 移动到第一个车位

        -- 为岸桥添加任务
        rmgqc:lift2agv(agv.targetcontainer[1]) -- 将抓住的集装箱移动到agv上
        rmgqc:addtask({"waitagv"}) -- 等待agv到达
        rmgqc:attachcontainer(table.unpack(agv.targetcontainer)) -- 将集装箱移动到指定位置
        -- print("岸桥添加任务完毕")

        table.insert(rmgqc.agvqueue, agv) -- 加入agv队列
        -- print("agv插入队列，#agvqueue=",#rmgqc.agvqueue)
        -- print("agvdatamodel.agvspan=",agv.datamodel.agvspan)
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
        -- print("#rmgqc.agvqueue=",#rmgqc.agvqueue)
        rmgqc.attached = rmgqc.agvqueue[1].container
        -- print("rmgqc.attached=",rmgqc.attached)
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
                rmgqc:spreadermove2(param[1], param[2], 0)
                rmgqc:deltask()
            end
        elseif taskname == "waitagv" then -- {"waitagv", nil}
            if rmgqc.agvqueue[1] == nil then
                -- rmgqc:deltask()
                print("rmgqc: rmgqc.agvqueue[1]=nil")
            end
            if rmgqc.agvqueue[1] ~= nil and rmgqc.agvqueue[1].arrived then -- agv到达
                -- table.remove(rmgqc.agvqueue, 1) -- 移除等待的agv
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
                               rmgqc.zspeed * ((param[3] - rmgqc.pos) / math.abs(param[3] - rmgqc.pos))} -- speed[3]:速度乘方向
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
        -- print("rmgqc.origin[1]=",rmgqc.origin[1]," rmgqc.iox=",rmgqc.iox," x=",x)
        local z = rmgqc.posbay[bay] -- 通过车移动解决z

        -- print("go (", bay, ",", level, ",", col, ")->(x", x, ",y", y, ",z", z, ")")
        return {x, y, z}
    end

    -- 添加任务，将抓住的集装箱移动到agv上
    function rmgqc:lift2agv(bay)
        -- rmgqc:addtask({"move2", rmgqc:getcontainercoord(bay, col, rmgqc.toplevel)}) -- 将集装箱从目标向上提升
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

function SHIP(rmgqc)
    -- 初始化船
    local ship = scene.addobj('/res/ct/ship.glb')

    ship.origin = {rmgqc.origin[1] + rmgqc.shipposx, rmgqc.origin[2], rmgqc.origin[3]}
    ship:setpos(ship.origin[1], ship.origin[2], rmgqc.origin[3])
    print("ship origin:", ship.origin[1], ",", ship.origin[2], ",", ship.origin[3])

    ship.bays = 8
    ship.cols = 9
    ship.level = 2
    ship.clength, ship.cspan = 6.06, 0
    ship.agvspan = 2 -- agv占用元胞数量（元胞长度）

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
                ship.pos[bay][col][level] = {ship.origin[1] + 2.44 * (5 - col),
                                             ship.origin[2] + 11.29 + (level - 1) * 2.42,
                                             rmgqc.origin[3] + rmgqc.posbay[bay]}
                -- container:setpos(table.unpack(ship.pos[bay][col][level]))
            end
        end
    end
    rmgqc.ship = ship

    function ship:initqueue() -- 初始化队列(ship.parkingspace) iox出入位置x相对坐标
        -- 停车队列(iox)
        ship.parkingspace = {} -- 属性：occupied:停车位占用情况，pos:停车位坐标，bay:对应堆场bay位

        -- 停车位
        for i = 1, ship.bays do
            ship.parkingspace[i] = {} -- 初始化
            ship.parkingspace[i].occupied = 0 -- 0:空闲，1:临时占用，2:作业占用
            print("ship.origin=", ship.origin[1], ",", ship.origin[2], ",", ship.origin[3])
            ship.parkingspace[i].pos = {rmgqc.origin[1], 0, ship.pos[ship.bays - i + 1][1][1][3]} -- x,y,z
            ship.parkingspace[i].bay = ship.bays - i + 1

            -- 停车位点
            -- local sign = scene.addobj("box")
            -- sign:setpos(table.unpack(ship.parkingspace[i].pos))
        end

        local lastbaypos = ship.parkingspace[1].pos -- 记录最后一个添加的位置

        -- bay外停车位
        for i = 1, rmgqc.queuelen do
            local pos = {lastbaypos[1], 0, lastbaypos[3] - i * (ship.clength + ship.cspan)}
            table.insert(ship.parkingspace, 1, {
                occupied = 0,
                pos = pos
            }) -- 无对应bay
            -- print("队列位置=", ship.queuelen - i + 1, " pos={", pos[1], ",", pos[2], ",", pos[3], "}")

            -- 停车位点
            -- local sign = scene.addobj("box")
            -- sign:setpos(table.unpack(ship.parkingspace[1].pos))
        end

        ship.summon = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[1].pos[3]}
        ship.exit = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[#ship.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    -- 返回空余位置编号
    function ship:getidlepos()
        for level = 1, ship.level do
            for bay = 1, ship.bays do
                for col = 1, ship.cols do
                    if ship.containers[bay][col][level] == nil then
                        ship.containers[bay][col][level] = {}
                        return {bay, col, level}
                    end
                end
            end
        end

        return nil -- 没找到
    end

    return ship
end

-- 创建堆场
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)
-- local cy2 = CY({19.66 / 2, 150 / 2}, {-19.66 / 2, 65 / 2}, 3)

-- 分配堆场给场桥
local rmg = RMG(cy)
-- local rmg2 = RMG(cy2)
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

-- print("cy.origin = ", cy.origin[1], ",", cy.origin[2])
-- print("rmg.origin = ", rmg.origin[1], ",", rmg.origin[2])

-- 添加任务 rmg1
-- rmg:addtask({"move2", rmg:getcontainercoord(2, 3, 4)}) -- 移动爪子到指定位置
-- -- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -1)}) -- 移动爪子到指定高度
-- rmg:addtask({"move2", rmg:getcontainercoord(2, 3, 3)}) -- 移动爪子到指定位置
-- rmg:addtask({"attach", {2, 3, 3}}) -- 抓取指定箱
-- -- rmg:addtask({"movespread", rmg:getcontainerdelta(0, 2)}) -- 移动爪子到指定高度
-- rmg:addtask({"move2", rmg:getcontainercoord(2, 3, 5)}) -- 移动爪子到指定位置
-- rmg:addtask({"move2", rmg:getcontainercoord(2, -1, 5)}) -- 移动爪子到指定位置
-- rmg:addtask({"move2", rmg:getcontainercoord(2, -1, 1)}) -- 放下箱子
-- -- rmg:addtask({"movespread", rmg:getcontainerdelta(0, -2)}) -- 移动爪子到指定高度
-- rmg:addtask({"detach"}) -- 放下指定箱

-- -- new task
-- rmg:attachcontainer(2, 3, 3)
-- rmg:addtask({"waitagv"})
-- rmg:lift2agv(2, 3)

-- local agv = AGV(cy, {1, 3, 3})
-- local agv2 = AGV(cy, {2, 4, 3})
-- local agv3 = AGV(cy, {1, 4, 3})
-- local agv4 = AGV(cy, {3, 4, 3})

-- agv:addtask({"move2", {0, 10}})
-- agv:addtask({"move2", {10, 10}})
-- agv:addtask({"move2", {10, 0}})
-- agv:addtask({"move2", {0, 0}})

-- 存在任务序列的对象列表
-- local actionobj = {rmg, rmg2, agv}
-- local actionobj = {rmg}

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

    local tArriveSpan = math.random(agvSummonSpan) + 1 -- 平均到达间隔120s
    coroutine.queue(tArriveSpan, generateagv)

    -- 随机抽取一个位置，生成agv
    local pos = availablepos[math.random(#availablepos)]
    cy.containers[pos[1]][pos[2]][pos[3]].reserved = true -- 标记为已经被预定
    local agv = AGV(cy, pos)
    print("[agv] summoned at: ", coroutine.qtime())
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
            -- print("recycle() triggered")
            recycle(obj)
            table.remove(actionobj, i)
            break -- 假设每次同时只能到达一个，因此可以中止
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

-- 生成agv
generateagv()
