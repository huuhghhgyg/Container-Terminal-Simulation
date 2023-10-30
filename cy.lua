function CY(p1, p2, level)
    local cy = {
        clength = 6.06,
        cwidth = 2.44,
        cheight = 2.42,
        cspan = 0.6,
        containerPositions = {}, -- 堆场各集装箱位置坐标列表(bay,row,level)
        containers = {}, -- 集装箱对象列表(使用相对坐标索引)
        parkingSpaces = {}, -- 停车位对象(使用bay位置索引)
        origin = {(p1[1] + p2[1]) / 2, 0, (p1[2] + p2[2]) / 2}, -- 参照点
        anchorPoint = {p1[1], 0, p1[2]}, -- 锚点
        containerUrls = {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
                         '/res/ct/container_yellow.glb'},
        rotdeg = 0, -- 旋转角度
        bindingRoad = nil -- 绑定的道路
    }

    local pdx = (p2[1] - p1[1]) / math.abs(p1[1] - p2[1]) -- x方向向量
    local pdy = (p2[2] - p1[2]) / math.abs(p1[2] - p2[2]) -- y方向向量

    -- 计算属性
    cy.dir = {pdx, pdy} -- 方向
    cy.width, cy.length = math.abs(p1[1] - p2[1]), math.abs(p1[2] - p2[2])
    cy.row = math.floor((cy.width + cy.cspan) / (cy.cwidth + cy.cspan)) -- 行数
    cy.col = math.floor((cy.length + cy.cspan) / (cy.clength + cy.cspan)) -- 列数
    cy.marginx = (cy.width + cy.cspan - (cy.cwidth + cy.cspan) * cy.row) / 2 -- 横向外边距
    cy.rotradian = cy.rotdeg * math.pi / 180 -- 旋转弧度

    -- 集装箱层数
    cy.levels = {} -- 层数y坐标集合
    cy.level = level
    for i = 1, level + 2 do
        cy.levels[i] = cy.cheight * (i - 1)
    end

    -- 初始化集装箱对象表
    for i = 1, cy.col do
        cy.containerPositions[i] = {} -- 初始化
        cy.containers[i] = {}
        for j = 1, cy.row do
            cy.containerPositions[i][j] = {}
            cy.containers[i][j] = {}
            for k = 1, cy.level do
                -- 初始化集装箱位置
                cy.containerPositions[i][j][k] = {p1[1] + pdx *
                    (cy.marginx + (j - 1) * (cy.cwidth + cy.cspan) + cy.cwidth / 2), cy.origin[2] + cy.levels[k],
                                                  p1[2] + pdy * ((i - 1) * (cy.clength + cy.cspan) + cy.clength / 2)}
                -- 初始化集装箱对象列表
                cy.containers[i][j][k] = nil
            end
        end
    end

    -- 绘制cy范围
    scene.addobj('polyline', {
        vertices = {p1[1], 0, p1[2], p2[1], 0, p1[2], p2[1], 0, p2[2], p1[1], 0, p2[2], p1[1], 0, p1[2]},
        color = 'green'
    })

    -- 绑定道路，并初始化队列
    function cy:bindRoad(road)
        -- 遍历bay坐标，进行投影
        local bayPos = {} -- bay的第一行坐标{x,z}
        for i = 1, cy.col do
            bayPos[i] = {cy.containerPositions[i][cy.row][1][1], cy.containerPositions[i][cy.row][1][3]}
        end

        -- 投影
        cy.parkingSpaces = {}
        for i = 1, #bayPos do
            cy.parkingSpaces[i] = {}
            cy.parkingSpaces[i].relativeDist = road:getVectorRelativeDist(bayPos[i][1], bayPos[i][2],
                math.cos(cy.rotradian - math.pi / 2), math.sin(cy.rotradian - math.pi / 2) * -1)
            -- print('cy debug: parking space', i, ' relative distance = ', cy.parkingSpaces[i].relativeDist)
        end

        -- 生成停车位并计算iox
        for k, v in ipairs(cy.parkingSpaces) do
            local x, y, z = road:getRelativePosition(v.relativeDist)

            -- 计算iox
            cy.parkingSpaces[k].iox = -1 * math.sqrt((x - bayPos[k][1]) ^ 2 + (z - bayPos[k][2]) ^ 2)
            -- print('cy debug: parking space', k, ' iox = ', cy.parkingSpaces[k].iox)
        end

        cy.bindingRoad = road
    end

    --- 显示绑定道路对应的停车位点（debug用）
    function cy:showBindingPoint()
        -- 显示cy.parkingSpaces的位置
        for k, v in ipairs(cy.parkingSpaces) do
            local x, y, z = cy.bindingRoad:getRelativePosition(v.relativeDist)

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

            -- print('cy debug: parking space', k, ' iox = ', cy.parkingSpaces[k].iox)
        end
    end

    -- 将堆场所有可用位置填充集装箱
    function cy:fillAllContainerPositions()
        for i = 1, cy.col do
            for j = 1, cy.row do
                for k = 1, cy.level do
                    cy:fillWithContainer(i, j, k)
                end
            end
        end
    end

    --- 根据sum随机生成每个(cy.bay,cy.row)位置的集装箱数量
    ---@param sum number 生成的集装箱总数
    function cy:fillRandomContainerPositions(sum)
        -- 初始化
        local containerNum = {}
        for i = 1, cy.col do
            containerNum[i] = {}
            for j = 1, cy.row do
                containerNum[i][j] = 0
            end
        end

        -- 随机生成
        for n = 1, sum do
            local bay = math.random(cy.col)
            local row = math.random(cy.row)
            containerNum[bay][row] = containerNum[bay][row] + 1
        end

        -- 填充
        for i = 1, cy.col do
            for j = 1, cy.row do
                for k = 1, cy.level do
                    -- 如果层数小于当前(bay,row)生成的层数，则放置集装箱，否则不放置
                    if k <= containerNum[i][j] then
                        cy:fillWithContainer(i, j, k)
                    end
                end
            end
        end
    end

    -- 在指定的(bay, row, level)位置生成集装箱
    function cy:fillWithContainer(bay, row, level)
        local url = cy.containerUrls[math.random(1, #cy.containerUrls)] -- 随机选择集装箱颜色
        local containerPos = cy.containerPositions[bay][row][level] -- 获取集装箱位置

        cy.containers[bay][row][level] = scene.addobj(url) -- 添加集装箱
        cy.containers[bay][row][level]:setpos(table.unpack(containerPos))
    end

    return cy
end
