function CY(row, col, level, config)
    if config == nil then
        config = {}
    end

    require('stack')
    local cy = Stack(row, col, level, config)

    -- 属性
    cy.type = 'cy'
    cy.parkingSpaces = {} -- 停车位对象(使用bay位置索引)
    cy.bindingRoad = nil -- 绑定的道路

    -- 绑定道路，并初始化队列
    function cy:bindRoad(road)
        -- 遍历bay坐标，进行投影
        local bayPos = {} -- bay的第一行坐标{x,z}
        for i = 1, cy.col do
            bayPos[i] = {cy.containerPositions[1][i][1][1], cy.containerPositions[1][i][1][3]}
            -- -- 显示baypos位置
            -- scene.addobj('points', {
            --     vertices = {bayPos[i][1], 0, bayPos[i][2]},
            --     color = 'blue',
            --     size = 5
            -- })
        end

        -- 投影
        cy.parkingSpaces = {}
        for i = 1, #bayPos do
            cy.parkingSpaces[i] = {}
            cy.parkingSpaces[i].relativeDist = road:getVectorRelativeDist(bayPos[i][1], bayPos[i][2],
                math.cos(cy.rot - math.pi / 2), math.sin(cy.rot - math.pi / 2) * -1)
            -- print('cy debug: parking space', i, ' relative distance = ', cy.parkingSpaces[i].relativeDist)
        end

        -- 生成停车位并计算iox
        for k, v in ipairs(cy.parkingSpaces) do
            local x, y, z = road:getRelativePosition(v.relativeDist)

            -- 计算iox
            cy.parkingSpaces[k].iox = -1 * math.sqrt((x - bayPos[k][1]) ^ 2 + (z - bayPos[k][2]) ^ 2) -- 由于位置关系，x轴方向取反
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

    return cy
end
