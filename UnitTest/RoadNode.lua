scene.setenv({
    grid = 'plane'
})

require('road')

local RoadList = {}

local NodeList = {} -- 节点列表

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
        radius = 5, -- 半径
        connectedRoad = {}, -- 连接的道路{roadId=.., deltaRadian=..}
        occupied = false, -- 是否被占用
        vec0 = {0, 0, 1} -- 正方向向量
    }

    -- 计算属性
    table.insert(nodeList, node)
    node.id = #nodeList

    --- 连接道路
    --- @param roadId number 道路id
    function node:connectRoad(roadId)
        -- 计算旋转角度
        local road = RoadList[roadId]
        local deltaRadian = math.atan(table.unpack(road.vec)) - math.atan(table.unpack(self.vec0))

        -- 添加连接的道路
        table.insert(node.connectedRoad, {
            roadId = roadId,
            deltaRadian = deltaRadian
        })
    end

    --- 根据本节点和输入的终点节点创建一条道路
    --- @class destNode Node 终点节点
    function node:createRoad(destNote)
        local c1, c2 = self.center, destNote.center
        local vector = {c2[1] - c1[1], c2[2] - c1[2], c2[3] - c1[3]}
        local length = math.sqrt(vector[1] ^ 2 + vector[2] ^ 2 + vector[3] ^ 2)
        local vecE = {vector[1] / length, vector[2] / length, vector[3] / length}

        local p1 = {c1[1] + vecE[1] * self.radius, c1[2] + vecE[2] * self.radius, c1[3] + vecE[3] * self.radius}
        local p2 = {c2[1] - vecE[1] * destNote.radius, c2[2] - vecE[2] * destNote.radius,
                    c2[3] - vecE[3] * destNote.radius}

        local road = Road(p1, p2, RoadList) -- 根据Road.lua，id已经在road.id里面

        -- 加入Node的connectedRoad里面
        node:connectRoad(road.id)

        return road
    end

    -- 绘制节点
    scene.addobj('points', {
        vertices = node.center,
        color = 'orange',
        size = 8
    })

    return node
end

local node1 = Node({-50, 0, 0}, NodeList)
local node2 = Node({0, 0, 0}, NodeList)
local node3 = Node({0, 0, 40}, NodeList)

-- 手动绘制道路并连接
-- local road1 = Road({0, 0, 10}, {0, 0, 30}, RoadList)
-- node3:connectRoad(road1.id)
-- local road2 = Road({10, 0, 40}, {30, 0, 40}, RoadList)

local roadAuto1 = node1:createRoad(node2)
local roadAuto2 = node2:createRoad(node3)
print('autogen road:', roadAuto1, ', roadId=', roadAuto1.id)

scene.render()
