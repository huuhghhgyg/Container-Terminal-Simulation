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
    rmg.level = {2.42, 2.42 * 2, 2.42 * 3, 2.42 * 4}
    rmg.spreaderpos = {0, rmg.level[2], 0} -- 初始位置(x,y)
    rmg.pos = 0 -- 初始位置(x,y,z)
    rmg.cy = cy -- 初始化对应堆场
    rmg.tasksequence = {} -- 初始化任务队列
    rmg.finishedTask = 0 -- 任务数量
    rmg.iox = -16 -- 进出口x坐标
    rmg.speed = 4 -- 移动速度
    rmg.attached = nil
    rmg.stash = nil -- io物品暂存

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
    function rmg:attach(row, col)
        -- print("cy container[", row, ",", col, "] =", rmg.cy.containers[row][col])
        -- print("rmg attached =", rmg.attached)
        -- print("rmg attach cy container[", row, ",", col, "]")
        rmg.attached = rmg.cy.containers[row][col]
        rmg.cy.containers[row][col] = nil
        -- print("rmg attached =", rmg.attached)
        -- print("cy container[", row, ",", col, "] =", rmg.cy.containers[row][col])
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
        rmg:spreadermove(x - rmg.spreaderpos[1], y - rmg.spreaderpos[2],
            z - rmg.spreaderpos[3])
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
        if taskname == "movespread" then -- {"movespread",{x,y,z}}
            -- print("execute movespread")
            local d = param -- 导入距离

            if d[4] == nil then -- 没有执行记录，创建
                for i = 1, 3 do
                    if d[i] == 0 then -- 无移动，向量设为0
                        d[i + 3] = 0
                    else
                        d[i + 3] = d[i] / math.abs(d[i]) -- 计算向量(4~6)
                    end
                    d[i + 6] = 0 -- 已移动距离(7~9)
                    d[i + 9] = rmg.spreaderpos[i] -- 初始位置(10~12)
                    -- print("d[", i, "]=", d[i], " d[", i + 3, "]=", d[i + 3], "d[", i + 6, "]=", d[i + 6], " d[", i + 9, "]=", d[i + 9])
                end
            end

            -- 计算各方向分速度
            local l = math.sqrt(d[4] ^ 2 + d[5] ^ 2 + d[6] ^ 2)
            local speed = {d[4] / l * rmg.speed, d[5] / l * rmg.speed, d[6] / l * rmg.speed} -- 向量*速度

            -- 计算移动值
            local ds = {}
            for i = 1, 3 do
                ds[i] = speed[i] * dt -- speed已经包括方向
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
        elseif taskname == "movespreadto" then -- {"movespreadto",{x,y,z}}
            -- print("execute movespreadto")
            local target = param

            if target[4] == nil then -- 没有执行记录，创建
                print("movespreadto param: ", target[1], ",", target[2], ",", target[3])
                for i = 1, 3 do
                    target[i + 6] = rmg.spreaderpos[i] -- 当前位置
                    target[i + 9] = rmg.spreaderpos[i] -- 初始位置
                    if target[i] - target[i + 9] == 0 then -- 目标距离差为0，向量设为0
                        target[i + 3] = 0
                    else
                        target[i + 3] = target[i] - target[i + 9] -- 计算初始向量
                    end
                end
                -- print("target[i+3]=",target[4],",",target[5],",",target[6])
            end
            -- print("target = ",target[1],",",target[2],",",target[3])

            -- 计算各方向分速度
            local l = math.sqrt(target[4] ^ 2 + target[5] ^ 2 + target[6] ^ 2)
            local speed = {target[4] / l * rmg.speed, target[5] / l * rmg.speed, target[6] / l * rmg.speed}
            local ds = {}
            -- 计算移动值
            for i = 1, 3 do
                ds[i] = speed[i] * dt -- dt移动
                -- print("ds[",i,"]=",ds[i])
                target[i + 6] = target[i + 6] + ds[i] -- 累计移动
            end
            -- print("ds=",ds[1],",",ds[2],",",ds[3])

            -- 判断是否到达目标
            -- print("判断是否达到目标")
            for i = 1, 3 do
                -- print("target[", i, "]=", target[i], "target[", i, "] - target[", i + 6, "]=",
                --     target[i] - target[i + 6], " target[", i + 6, "]/target[", i, "]=", target[i + 6] / target[i])
                if target[i + 3] ~= 0 and (target[i] - target[i + 6]) * target[i + 3] <= 0 then -- 分方向到达目标
                    -- print("movespreadto reached target: ", target[1], ",", target[2], ",", target[3])
                    rmg:deltask()
                    rmg:spreadermove2(target[1], target[2], target[3])
                    return
                end
            end

            -- print("spreadermoveto:",target[7],",",target[8],",",target[9])
            rmg:spreadermove2(target[7], target[8], target[9]) -- 设置到累计移动值
        elseif taskname == "moveto" then -- {"moveto", {pos}} 移动到bay
            -- print("execute moveto")
            local d = param
            if d[2] == nil then
                d[2] = rmg.pos -- 初始位置
                d[3] = 0 -- 已经移动的距离
            end

            if d[3] >= d[1] then -- 到达目标
                rmg:deltask()
                rmg:move(d[1] - d[3])
                return
            end

            local ds = rmg.speed * dt * (d[1] / math.abs(d[1]))
            d[3] = d[3] + ds
            rmg:move(ds)
        elseif taskname == "attach" then -- {"attach", {cy.row,cy.col}}
            rmg:attach(param[1], param[2])
            rmg:deltask()
        elseif taskname == "detach" then -- {"detach", nil}
            rmg:detach()
            rmg:deltask()
        end
    end

    function rmg:addtask(obj)
        table.insert(rmg.tasksequence, obj)
        print("rmg:addtask(): ", rmg.tasksequence[#rmg.tasksequence][1], ", task count:", #rmg.tasksequence)
        -- print("finished task=", rmg.finishedTask)
    end

    function rmg:deltask()
        print("rmg:deltask(): ", rmg.tasksequence[1][1], ", task count:", #rmg.tasksequence)
        table.remove(rmg.tasksequence, 1)
        rmg.finishedTask = rmg.finishedTask + 1
        -- print("rmg:deltask():finished task:", rmg.finishedTask)

        if (rmg.tasksequence[1] ~= nil) then
            print("task executing: ", rmg.tasksequence[1][1])
        end
    end

    -- 获取爪子移动坐标（x,y)
    function rmg:getcontainercoord(bay,level,col)
        local x
        if col == -1 then
            x = rmg.iox
        else
            x = cy.pos[bay][col][1] - rmg.origin[1]
        end
        -- print("rmg.origin[1]=",rmg.origin[1]," rmg.iox=",rmg.iox," x=",x)
        local y = rmg.level[level] - rmg.origin[2]
        local z = 0 --通过车移动解决z

        return {x,y,z}
    end

    function rmg:getcontainerdelta(dcol, dlevel)
        local dx = dcol*(cy.cwidth+cy.cspan)
        local dy = dlevel*rmg.level[1]
        local dz = 0 --通过车移动解决z

        return {dx,dy,dz}
    end

    -- 获取车移动坐标（z）
    function rmg:getlen(bay)
        return {cy.pos[bay][1][2] - cy.origin[3]}
    end

    return rmg
end

function CY(p1, p2, levels)
    local cy = {
        clength = 6.06,
        cwidth = 2.44,
        cspan = 0.6,
        pos = {}, -- 初始化
        containers = {}, -- 集装箱对象(相对坐标)
        origin = {(p1[1] + p2[1]) / 2, 0, (p1[2] + p2[2]) / 2} -- 参照点
    }
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
    cy.dir = {pdx, pdy}
    cy.width, cy.length = math.abs(p1[1] - p2[1]), math.abs(p1[2] - p2[2])
    -- print("cy.length = ",cy.length," cy.width = ",cy.width, "cwidth, clength = ",cy.cwidth,",",cy.clength)
    cy.col = math.floor((cy.width + cy.cspan) / (cy.cwidth + cy.cspan)) -- 列数
    cy.row = math.floor((cy.length + cy.cspan) / (cy.clength + cy.cspan)) -- 行数
    cy.marginx = (cy.width + cy.cspan - (cy.cwidth + cy.cspan) * cy.col) / 2 -- 横向外边距
    -- print("cy row,col = ",cy.row, ",",cy.col," xmargin = ",cy.marginx, " cspan = ",cy.cspan)

    for i = 1, cy.row do
        cy.pos[i] = {} -- 初始化
        cy.containers[i] = {}
        for j = 1, cy.col do
            cy.pos[i][j] = {p1[1] + pdx * (cy.marginx + (j - 1) * (cy.cwidth + cy.cspan) + cy.cwidth / 2),
                            p1[2] + pdy * ((i - 1) * (cy.clength + cy.cspan) + cy.clength / 2)}
            cy.containers[i][j] = scene.addobj('/res/ct/container.glb')
            cy.containers[i][j]:setpos(cy.pos[i][j][1], 0, cy.pos[i][j][2])
            -- print("container[",i,",",j,"]=(",cy.pos[i][j][1],",",cy.pos[i][j][2],")")
        end
    end

    return cy
end

-- 创建堆场
local cy = CY({19.66 / 2, 51.49 / 2}, {-19.66 / 2, -51.49 / 2}, 3)
-- local cy = CY({-2 / 2, 20 / 2}, {-30 / 2, 50 / 2}, 3) --位置测试

-- 分配堆场给场桥
local rmg = RMG(cy)

print("cy.origin = ", cy.origin[1], ",", cy.origin[2])
print("rmg.origin = ", rmg.origin[1], ",", rmg.origin[2])

-- 添加任务
rmg:addtask({"moveto", rmg:getlen(2)}) -- 移动到指定箱位置
-- print("cy目标真实位置:",cy.pos[2][4][2]," cy目标相对位置:",cy.pos[2][4][2]-cy.origin[3])
rmg:addtask({"movespreadto", rmg:getcontainercoord(2,2,3)}) -- 移动爪子到指定箱位置
rmg:addtask({"movespread", rmg:getcontainerdelta(0,-1)}) -- 移动爪子到指定高度
rmg:addtask({"attach", {2, 3}}) -- 抓取指定箱
rmg:addtask({"movespread", rmg:getcontainerdelta(0,2)}) -- 移动爪子到指定高度
rmg:addtask({"movespreadto", rmg:getcontainercoord(0,3,-1)}) -- 移动爪子到指定位置
rmg:addtask({"movespread", rmg:getcontainerdelta(0,-2)}) -- 移动爪子到指定高度
rmg:addtask({"detach"}) -- 放下指定箱
rmg:addtask({"movespreadto", {0, rmg.level[2], 0}}) -- 移动爪子到指定位置

local t = os.clock()
local dt = 0
while scene.render() and #rmg.tasksequence > 0 do
    dt = os.clock() - t
    t = os.clock()
    -- print(dt)
    -- print("#rmg.tasksequence:", #rmg.tasksequence)
    rmg:executeTask(dt)

    if rmg.stash ~= nil then
        delete(rmg.stash)
        rmg.stash = nil
    end
end

print("rmg.attached:", rmg.attached)
print("rmg.stash:", rmg.stash)

scene.render()
