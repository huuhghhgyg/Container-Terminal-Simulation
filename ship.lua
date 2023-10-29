function Ship(size, origin) -- size={bays,rows,levels}, originPt={x,y,z}
    -- 初始化船
    local ship = scene.addobj('/res/ct/ship.glb')

    -- 参数
    ship.containerConst = {6.06, 2.44, 2.42} -- 集装箱长宽高常数
    ship.bay = size[1] or 8
    ship.row = size[2] or 9
    ship.level = size[3] or 2
    ship.clength, ship.cbaygap = 6.06, 0.5 -- 集装箱长度，集装箱bay间距
    ship.origin = origin
    ship.bayPosition = {} -- bay位相对坐标，用于计算船上集装箱位置和绑定停车位
    ship.containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                          '/res/ct/container_yellow.glb'}

    ship:setpos(ship.origin[1], ship.origin[2], ship.origin[3])
    print("ship origin:", ship.origin[1], ",", ship.origin[2], ",", ship.origin[3])

    -- 初始化bay位置
    local bayLength = ship.clength * ship.bay + ship.cbaygap * (ship.bay - 1)
    for bay = 1, ship.bay do
        ship.bayPosition[bay] = -28 + bayLength - (bay - 1) * (ship.clength + ship.cbaygap) -- 初始位置+bay位置+bay间距
    end

    -- 初始化集装箱位置和集装箱
    ship.containerPositions = {} -- 集装箱位置列表{bay, col, level}
    ship.containers = {}
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

    -- 将船绑定到场桥
    function ship:bindRMGQC(rmgqc)

    end

    function ship:initqueue() -- 初始化队列(ship.parkingspace) iox出入位置x相对坐标
        -- 停车队列(iox)
        ship.parkingspace = {} -- 属性：occupied:停车位占用情况，pos:停车位坐标，bay:对应堆场bay位

        -- 停车位
        for i = 1, ship.bay do
            ship.parkingspace[i] = {} -- 初始化
            ship.parkingspace[i].occupied = 0 -- 0:空闲，1:临时占用，2:作业占用
            ship.parkingspace[i].pos = {ship.origin[1], 0, ship.containerPositions[ship.bay - i + 1][1][1][3]} -- x,y,z
            ship.parkingspace[i].bay = ship.bay - i + 1
        end

        local lastbaypos = ship.parkingspace[1].pos -- 记录最后一个添加的位置

        -- bay外停车位
        for i = 1, rmgqc.queuelen do
            local pos = {lastbaypos[1], 0, lastbaypos[3] - i * (ship.clength + ship.cspan)}
            table.insert(ship.parkingspace, 1, {
                occupied = 0,
                pos = pos
            }) -- 无对应bay
        end

        ship.summon = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[1].pos[3]}
        ship.exit = {ship.parkingspace[1].pos[1], 0, ship.parkingspace[#ship.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    -- 返回空余位置编号
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

    return ship
end
