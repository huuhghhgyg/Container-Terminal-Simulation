function Ship(size, origin) -- size={bays,rows,levels}, originPt={x,y,z}
    -- 初始化船
    local ship = scene.addobj('/res/ct/ship.glb')

    -- 参数
    ship.type = 'ship'
    ship.containerConst = {6.06, 2.44, 2.42} -- 集装箱长宽高常数
    ship.bay = size[1] or 8
    ship.row = size[2] or 9
    ship.level = size[3] or 2
    ship.clength, ship.cbaygap = 6.06, 0.5 -- 集装箱长度，集装箱bay间距
    ship.origin = origin
    ship.containerPositions = {} -- 集装箱位置列表{bay, col, level}
    ship.containers = {}
    ship.bayPosition = {} -- bay位相对坐标，用于计算船上集装箱位置和绑定停车位
    ship.positionLevels = nil -- ship各位置集装箱层数
    ship.operator = nil -- 操作器（ship对应rmgqc）
    ship.containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                          '/res/ct/container_yellow.glb'}
    ship.rotdeg = 0 -- 旋转角度
    ship.rotradian = ship.rotdeg * math.pi / 180 -- 旋转弧度

    ship:setpos(ship.origin[1], ship.origin[2], ship.origin[3])
    print("ship origin:", ship.origin[1], ",", ship.origin[2], ",", ship.origin[3])

    -- 初始化bay位置
    local bayLength = ship.clength * ship.bay + ship.cbaygap * (ship.bay - 1)
    for bay = 1, ship.bay do
        ship.bayPosition[bay] = -28 + bayLength - (bay - 1) * (ship.clength + ship.cbaygap) -- 初始位置+bay位置+bay间距
    end

    -- 初始化集装箱位置和集装箱
    for bay = 1, ship.bay do
        ship.containerPositions[bay] = {}
        ship.containers[bay] = {}
        for row = 1, ship.row do
            ship.containerPositions[bay][row] = {}
            ship.containers[bay][row] = {}
            for level = 1, ship.level do
                ship.containers[bay][row][level] = nil
                ship.containerPositions[bay][row][level] =
                    {ship.origin[1] + 2.44 * (5 - row), -- 5为集装箱的中间行
                    ship.origin[2] + 11.29 + (level - 1) * 2.42, ship.origin[3] + ship.bayPosition[bay]}
            end
        end
    end

    -- 返回空余位置编号(old)
    function ship:getIdlePosition()
        for level = 1, ship.level do
            for bay = 1, ship.bay do
                for col = 1, ship.row do
                    if ship.containers[bay][col][level] == nil then
                        ship.containers[bay][col][level] = {}
                        return {bay, col, level}
                    end
                end
            end
        end

        return nil -- 没找到
    end

    -- 在指定的(bay, row, level)位置生成集装箱
    function ship:fillWithContainer(bay, row, level)
        local url = ship.containerUrls[math.random(1, #ship.containerUrls)] -- 随机选择集装箱颜色
        local containerPos = ship.containerPositions[bay][row][level] -- 获取集装箱位置

        ship.containers[bay][row][level] = scene.addobj(url) -- 添加集装箱
        ship.containers[bay][row][level]:setpos(table.unpack(containerPos))
    end

    -- 将船上所有可用位置填充集装箱
    function ship:fillAllContainerPositions()
        for i = 1, ship.bay do
            for j = 1, ship.row do
                for k = 1, ship.level do
                    ship:fillWithContainer(i, j, k)
                end
            end
        end
    end

    --- 根据sum随机生成每个(ship.bay,ship.row)位置的集装箱数量
    ---@param sum number 生成的集装箱总数
    ---@param containerUrls table 集装箱链接(颜色)列表，可选参数
    function ship:fillRandomContainerPositions(sum, containerUrls)
        -- 注入集装箱颜色列表
        if containerUrls ~= nil then
            ship.containerUrls = containerUrls -- 修改ship的集装箱颜色列表
        end

        -- 初始化
        local containerNum = {}
        for i = 1, ship.bay do
            containerNum[i] = {}
            for j = 1, ship.row do
                containerNum[i][j] = 0
            end
        end

        -- 随机生成
        for n = 1, sum do
            local bay = math.random(ship.bay)
            local row = math.random(ship.row)
            containerNum[bay][row] = containerNum[bay][row] + 1
        end

        -- 填充
        for i = 1, ship.bay do
            for j = 1, ship.row do
                for k = 1, ship.level do
                    -- 如果层数小于当前(bay,row)生成的层数，则放置集装箱，否则不放置
                    if k <= containerNum[i][j] then
                        ship:fillWithContainer(i, j, k)
                    end
                end
            end
        end
    end

    return ship
end
