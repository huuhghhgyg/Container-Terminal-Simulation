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
                ship.containers[bay][col][level] = nil
                ship.pos[bay][col][level] = {ship.origin[1] + 2.44 * (5 - col),
                                             ship.origin[2] + 11.29 + (level - 1) * 2.42,
                                             rmgqc.origin[3] + rmgqc.posbay[bay]}
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
            ship.parkingspace[i].pos = {rmgqc.origin[1], 0, ship.pos[ship.bays - i + 1][1][1][3]} -- x,y,z
            ship.parkingspace[i].bay = ship.bays - i + 1
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