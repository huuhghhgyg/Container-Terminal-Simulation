-- {row=,bay=,level=}
function Ship(config)
    if config == nil then
        config = {}
    end

    -- 设置导入参数
    config.row = config.row or 9
    config.bay = config.bay or 8
    config.level = config.level or 2
    config.cspan = config.cspan or {0, 0.5} -- 集装箱长度，集装箱bay间距
    config.anchorPoint = config.anchorPoint or {0, 0, 0} -- 锚点：用于计算Crane Attach位置。后面计算
    config.modelDelta = config.modelDelta or {-4.5 * 2.44, 11.29, 22} -- 模型偏移量
    config.origin = {config.anchorPoint[1] + config.modelDelta[1], config.anchorPoint[2] + config.modelDelta[2],
                     config.anchorPoint[3]} -- 不计算z，z用于计算ship模型中心位置

    require('stack')
    local ship = Stack(config.row, config.bay, config.level, config)
    ship.model = scene.addobj('/res/ct/ship.glb') -- 添加模型

    -- 参数
    ship.type = 'ship'
    ship.operator = nil -- 操作器（ship对应rmgqc）
    ship.bayPosition = {} -- bay位相对坐标，用于计算船上集装箱位置和绑定停车位
    
    -- 计算参数
    ship.bay = ship.col -- bay数(映射为col)
    ship.modelDelta = config.modelDelta -- 模型偏移量
    ship.anchorPoint = config.anchorPoint or {0, 0, 0} -- 锚点，可能覆盖，因此重新赋值

    -- 初始化bay位置
    for bay = 1, ship.bay do
        ship.bayPosition[bay] = ship.containerPositions[1][bay][1][3]
    end

    -- 设置setpos函数
    function ship:setpos(x, y, z)
        ship.model:setpos(ship.anchorPoint[1], ship.anchorPoint[2], ship.anchorPoint[3] + ship.modelDelta[3])
        -- debug
        print("ship origin:", ship.origin[1], ",", ship.origin[2], ",", ship.origin[3]) -- debug
        print("ship anchorPoint:", ship.anchorPoint[1], ",", ship.anchorPoint[2], ",", ship.anchorPoint[3]) -- debug
        local originPt = scene.addobj('points', {
            vertices = ship.origin,
            color = 'red',
            size = 8
        })
        local labelOrigin = scene.addobj('label', {
            text = 'ship.origin'
        })
        labelOrigin:setpos(table.unpack(ship.origin))
        local anchorPt = scene.addobj('points', {
            vertices = ship.anchorPoint,
            color = 'blue',
            size = 8
        })
        local labelAnchor = scene.addobj('label', {
            text = 'ship.anchorPoint'
        })
        labelAnchor:setpos(table.unpack(ship.anchorPoint))
    end
    ship:setpos(table.unpack(ship.anchorPoint))

    -- 返回空余位置编号(old)
    function ship:getIdlePosition()
        for level = 1, ship.level do
            for row = 1, ship.row do
                for bay = 1, ship.bay do
                    if ship.containers[row][bay][level] == nil then
                        ship.containers[row][bay][level] = {}
                        return {row, bay, level}
                    end
                end
            end
        end

        return nil -- 没找到
    end

    return ship
end
