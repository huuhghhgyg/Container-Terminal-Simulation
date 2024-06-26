--- 节点
--- @class Node
--- @param point table 节点坐标{x,y,z}
--- @param nodeList table 节点列表
--- @param params table 可选参数列表
function Node(point, nodeList, params)
    -- 处理可选参数
    if params == nil then
        params = {}
    end

    local node = {
        center = point, -- 中心点
        radius = params.radius or 5, -- 半径
        connectedRoads = {}, -- 连接的道路{roadId=.., rotY=..}，访问节点的时候可以通过roadId转到道路
        occupied = nil, -- 是否被占用
        vec0 = {0, 0, 1}, -- 正方向向量（agv的默认方向）
        agv = nil, -- 占用节点的agv对象
    }

    -- 注册节点
    table.insert(nodeList, node)
    node.id = #nodeList -- 设置id

    --- 将指定id的道路连接到本节点，本节点作为其起点
    --- @class Road road 道路对象
    --- @class Node destNode 终点节点
    function node:connectRoad(road, destNode)
        -- 计算旋转角度
        local deltaRadian = math.atan(table.unpack(road.vec)) - math.atan(table.unpack(self.vec0))

        -- 添加连接的道路
        table.insert(node.connectedRoads, {
            roadId = road.id,
            roty = deltaRadian
        })
        road.fromNode = self -- 将本节点对象作为道路的终点
        road.toNode = destNode-- 将终点节点对象作为道路的终点
    end

    --- 根据本节点和输入的终点节点创建一条道路
    --- @class Node destNode 终点节点
    --- @param roadList table 道路列表
    --- @return Road road 道路对象
    function node:createRoad(destNode, roadList)
        local c1, c2 = self.center, destNode.center
        local vector = {c2[1] - c1[1], c2[2] - c1[2], c2[3] - c1[3]}
        local length = math.sqrt(vector[1] ^ 2 + vector[2] ^ 2 + vector[3] ^ 2)
        local vecE = {vector[1] / length, vector[2] / length, vector[3] / length}

        local p1 = {c1[1] + vecE[1] * self.radius, c1[2] + vecE[2] * self.radius, c1[3] + vecE[3] * self.radius}
        local p2 = {c2[1] - vecE[1] * destNode.radius, c2[2] - vecE[2] * destNode.radius,
                    c2[3] - vecE[3] * destNode.radius}

        local road = Road(p1, p2, roadList) -- 根据Road.lua，id已经在road.id里面

        -- 加入Node的connectedRoad里面
        node:connectRoad(road, destNode)

        return road
    end

    -- 绘制节点
    scene.addobj('points', {
        vertices = node.center,
        color = 'orange',
        size = 8
    })
    -- local label = scene.addobj('label', {
    --     text = '('..node.center[1]..','..node.center[3]..')'
    -- })
    -- label:setpos(table.unpack(node.center))

    return node
end