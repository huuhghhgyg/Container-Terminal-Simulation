
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
        containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                         '/res/ct/container_yellow.glb'}
    }

    local pdx = (p2[1] - p1[1]) / math.abs(p1[1] - p2[1])
    local pdy = (p2[2] - p1[2]) / math.abs(p1[2] - p2[2])

    -- 计算属性
    cy.dir = {pdx, pdy} -- 方向
    cy.width, cy.length = math.abs(p1[1] - p2[1]), math.abs(p1[2] - p2[2])
    cy.col = math.floor((cy.width + cy.cspan) / (cy.cwidth + cy.cspan)) -- 列数
    cy.row = math.floor((cy.length + cy.cspan) / (cy.clength + cy.cspan)) -- 行数
    cy.marginx = (cy.width + cy.cspan - (cy.cwidth + cy.cspan) * cy.col) / 2 -- 横向外边距

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
                local url = cy.containerUrls[math.random(1, #cy.containerUrls)] -- 随机选择集装箱颜色
                cy.containers[i][j][k] = scene.addobj(url) -- 添加集装箱
                cy.containers[i][j][k]:setpos(cy.pos[i][j][k][1], cy.pos[i][j][k][2], cy.pos[i][j][k][3])
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
            cy.parkingspace[i].pos = {cy.origin[1] + iox, 0, cy.origin[3] + cy.pos[cy.row - i + 1][1][1][3]} -- x,y,z
            cy.parkingspace[i].bay = cy.row - i + 1
        end

        local lastbaypos = cy.parkingspace[1].pos -- 记录最后一个添加的位置

        -- 队列停车位
        for i = 1, cy.queuelen do
            local pos = {lastbaypos[1], 0, lastbaypos[3] - i * (cy.clength + cy.cspan)}
            table.insert(cy.parkingspace, 1, {
                occupied = 0,
                pos = pos
            }) -- 无对应bay
        end

        cy.summon = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[1].pos[3]}
        cy.exit = {cy.parkingspace[1].pos[1], 0, cy.parkingspace[#cy.parkingspace].pos[3] + 20} -- 设置离开位置
    end

    return cy
end