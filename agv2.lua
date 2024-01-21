function AGV(config)
    -- 处理参数
    if config == nil then
        config = {}
    end
    
    local agv = Agent(config)

    -- 属性
    agv.type = 'agv'
    -- agv.tasks
    -- agv.tasksequence
    agv.model = scene.addobj("/res/ct/agv.glb")
    agv.id = agv.model.id

    function agv:init(config)
        local speed = config.speed or 10 -- 速度
        agv.speed = {speed, speed, speed}
        agv.rot = config.rot or 0 -- 以y为轴的旋转弧度，默认方向为0
        agv.container = config.container or nil -- 集装箱
        agv.height = config.height or 2.10 -- agv平台高度
        agv.road = config.road or nil -- 相对应road:registerAgv中设置agv的road属性
        agv.state = nil -- 状态，设为正常状态
        agv.targetContainerPos = nil -- 目标集装箱位置{row, col, level}
    end

    -- 绑定对象
    function agv:bindCrane(targetStack, targetContainer)
        agv.stack = targetStack -- 目标stack
        agv.operator = targetStack.operator -- 目标operator
        agv.targetContainerPos = targetContainer -- 目标集装箱{row, col, level}
        agv.arrived = false -- ?是否到达目标
    end

    -- 动作函数
    function agv:setpos(x, y, z)
        agv.model:setpos(x, y, z)
    end

    function agv:move2(x, y, z)
        agv:setpos(x, y, z)
        agv:setrot(0, agv.rot, 0)

        if agv.container ~= nil then
            agv.container:setpos(x, y + agv.height, z)
            agv.container:setrot(0, agv.rot, 0)
        end
    end

    agv:init(config)
    return agv
end
