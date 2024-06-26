function RMG(config)
    -- 参数设置
    if config == nil then
        config = {}
    end

    require('crane')
    local rmg = Crane(config)

    -- 基本参数设置
    rmg.type = 'rmg'
    -- 模型参数设置
    local body = scene.addobj('/res/ct/rmg.glb')
    local trolley = scene.addobj('/res/ct/trolley.glb')
    local spreader = scene.addobj('/res/ct/spreader.glb')
    local wirerope = scene.addobj('/res/ct/wirerope.glb')
    rmg.id = body.id
    rmg.agvHeight = 2.1

    -- 动作函数
    -- 瞬移或整体移动的函数（非正常工作状态）
    function rmg:setpos(x, y, z)
        -- 设置位置
        rmg.pos = {x, y, z}

        if rmg.anchorPoint ~= nil then
            rmg.anchorPoint[3] = z -- 只更新锚点的z坐标
        end

        body:setpos(rmg.anchorPoint[1], 0, rmg.pos[3]) -- 设置车的位置（z方向可移动）
        trolley:setpos(rmg.pos[1], 0, rmg.pos[3]) -- 设置trolley的位置
        wirerope:setscale(1, 17.57 - rmg.pos[2] - 2.42, 1) -- trolly离地面高度17.57，wirerope长宽设为1
        wirerope:setpos(rmg.pos[1], rmg.pos[2] + 2.42 + 1.15, rmg.pos[3] + 0) -- spreader高度1.1
        spreader:setpos(rmg.pos[1] - 0.01, rmg.pos[2] + 2.42 + 0.05, rmg.pos[3] + 0.012)

        -- 移动集装箱
        if rmg.attached ~= nil then
            rmg.attached:setpos(table.unpack(rmg.pos))
        end
    end

    -- 初始化Agent
    function rmg:init()
        -- 绑定堆场
        if config.stack ~= nil then
            rmg:bindStack(config.stack) -- crane:bindStack()中自带初始化位置
        end
        if config.actionObjs ~= nil then
            table.insert(config.actionObjs, rmg)
        end
    end
    rmg:init()

    return rmg
end
