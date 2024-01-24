function RMGQC(config)
    -- 参数设置
    -- config: anchorPoint, actionObjs, road, stack
    if config == nil then
        config = {}
    end

    require('crane')
    local rmgqc = Crane(config)

    -- 基本参数设置
    rmgqc.type = 'rmgqc'
    -- 模型参数设置
    local body = scene.addobj('/res/ct/rmqc.glb')
    local trolley = scene.addobj('/res/ct/trolley_rmqc.glb')
    local wirerope = scene.addobj('/res/ct/wirerope.glb')
    local spreader = scene.addobj('/res/ct/spreader.glb')
    rmgqc.id = body.id
    rmgqc.agvHeight = 2.1
    -- 绑定参数设置
    rmgqc.stack = config.stack or nil -- 绑定的stack

    -- 绑定其他对象
    -- rmgqc重写bindStack函数
    function rmgqc:bindStack(stack)
        if rmgqc.road == nil then
            print(debug.traceback('[' .. rmgqc.type .. rmgqc.id .. '] bindStack()错误，rmgqc需要先绑定道路'))
        end

        -- 进行绑定（对应rmg的绑定在依赖注入后执行）
        rmgqc.stack = stack
        stack.operator = rmgqc

        local bayPos = {} -- bay的第一行坐标{x,z}
        for i = 1, stack.bay do
            bayPos[i] = {stack.containerPositions[1][i][1][1], stack.containerPositions[1][i][1][3]}
            -- 显示baypos位置
            scene.addobj('points', {
                vertices = {bayPos[i][1], 0, bayPos[i][2]},
                color = 'blue',
                size = 5
            })
        end

        -- 投影
        rmgqc.stack.parkingSpaces = {}
        for i = 1, #bayPos do
            rmgqc.stack.parkingSpaces[i] = {}
            rmgqc.stack.parkingSpaces[i].relativeDist = rmgqc.road:getVectorRelativeDist(bayPos[i][1], bayPos[i][2],
                math.cos(stack.rot - math.pi / 2), math.sin(stack.rot - math.pi / 2) * -1)
            -- print('cy debug: parking space', i, ' relative distance = ', rmgqc.stack.parkingSpaces[i].relativeDist)
        end

        -- 生成停车位并计算iox
        for k, v in ipairs(rmgqc.stack.parkingSpaces) do
            local x, y, z = rmgqc.road:getRelativePosition(v.relativeDist)

            -- 计算iox
            rmgqc.stack.parkingSpaces[k].iox = math.sqrt((x - bayPos[k][1]) ^ 2 + (z - bayPos[k][2]) ^ 2)
            -- print('cy debug: parking space', k, ' iox = ', rmgqc.stack.parkingSpaces[k].iox)
        end
    end

    --- 显示绑定道路对应的停车位点（debug用）
    function rmgqc:showBindingPoint()
        -- 显示rmgqc.stack.parkingSpaces的位置
        for k, v in ipairs(rmgqc.stack.parkingSpaces) do
            local x, y, z = rmgqc.road:getRelativePosition(v.relativeDist)

            -- 显示位置
            scene.addobj('points', {
                vertices = {x, y, z},
                color = 'red',
                size = 5
            })
            local pointLabel = scene.addobj('label', {
                text = 'no.' .. k
            })
            pointLabel:setpos(x, y, z)

            -- print('rmgqc debug: parking space', k, ' ,iox = ', rmgqc.stack.parkingSpaces[k].iox, ' ,Position=', x, y, z) -- debug
        end
    end

    -- 动作函数
    -- 移动至某坐标
    function rmgqc:setpos(x, y, z)
        -- 设置位置
        rmgqc.pos = {x, y, z}

        if rmgqc.anchorPoint ~= nil then
            rmgqc.anchorPoint[3] = z -- 只更新锚点的z坐标
        end

        body:setpos(rmgqc.anchorPoint[1], 0, rmgqc.pos[3])
        trolley:setpos(rmgqc.pos[1], 0, rmgqc.pos[3])
        wirerope:setpos(rmgqc.pos[1], rmgqc.pos[2] + 2.42 + 1.1, rmgqc.pos[3])
        wirerope:setscale(1, (26.54 + 1.32 - 1.1) - (rmgqc.pos[2] + 2.42), 1)
        spreader:setpos(rmgqc.pos[1], rmgqc.pos[2] + 2.42, rmgqc.pos[3])

        -- 移动集装箱
        if rmgqc.attached ~= nil then
            rmgqc.attached:setpos(table.unpack(rmgqc.pos))
        end
    end

    -- 初始化Agent
    function rmgqc:init()
        -- 初始化位置
        if config.anchorPoint ~= nil then
            rmgqc:setpos(table.unpack(config.anchorPoint))
        end
        if config.actionObjs ~= nil then
            table.insert(config.actionObjs, rmgqc)
        end
        -- 确定泊位位置，用于确定stack的位置
        rmgqc.berthPosition = {rmgqc.anchorPoint[1] - 30, rmgqc.anchorPoint[2], rmgqc.anchorPoint[3]}

        -- 对象绑定
        -- rmgqc要求先绑定road，再绑定stack
        if config.road ~= nil then
            rmgqc:bindRoad(config.road)
        end
        if config.stack ~= nil then
            rmgqc:bindStack(config.stack)
        end
    end
    rmgqc:init()

    return rmgqc
end
