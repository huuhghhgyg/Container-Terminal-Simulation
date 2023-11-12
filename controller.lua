require('road')
require('node')

function Controller()
    local controller = {
        Roads = {},
        Nodes = {},
    }

    --- 通过两个点坐标创建一条直线道路
    ---@param position table 节点坐标位置{x,y,z}
    ---@param params table 可选参数列表，如{radius=10}
    ---@return Node
    function controller:addNode(position, params)
        local node = Node(position, controller.Nodes, params)
        -- 注入属性
        node.fromNodesId = {}
        node.toNodesId = {}
        node.fromRoads = {}
        node.toRoads = {}

        return node
    end

    --- 连接节点生成道路
    --- @param node1 Node
    --- @param node2 Node
    ---@return Road
    function controller:linkNode(node1, node2)
        -- 条件检测（如果影响性能可以考虑去掉）
        if node1.fromNodesId == nil or node1.toNodesId == nil then
            print('[controller] 警告：node', node1.id, '不是从Controller中创建的，没有fromNodesId或toNodesId属性')
        end
        if node2.fromNodesId == nil or node2.toNodesId == nil then
            print('[controller] 警告：node', node2.id, '不是从Controller中创建的，没有fromNodesId或toNodesId属性')
        end

        -- 向节点添加OD点信息
        table.insert(node1.toNodesId, node2.id)   -- node1中的去向节点ID列表中添加node2的id
        table.insert(node2.fromNodesId, node1.id) -- node2中的来源节点ID列表中添加node1的id

        -- 向节点添加连接道路信息
        local linkRoad = node1:createRoad(node2, controller.Roads) -- 创建道路
        table.insert(node1.toRoads, linkRoad)                      -- node1中的去向道路列表中添加linkRoad
        table.insert(node2.fromRoads, linkRoad)                    -- node2中的来源道路列表中添加linkRoad

        return linkRoad
    end

    function controller:shortestPath(fromNodeId, toNodeId)
        local stp = math.newmip() -- 创建线性规划问题

        -- 设置目标函数
        local functionCoeffs = {} -- 目标函数系数
        for roadId, road in ipairs(controller.Roads) do
            functionCoeffs[roadId] = road.length
        end
        stp:addrow(functionCoeffs, 'min') -- 添加目标函数行
        print('targetfunc:\n', table.unpack(functionCoeffs))

        -- 对每个点添加约束条件
        for nodeId, node in ipairs(controller.Nodes) do
            -- print('coeff of NodeId' .. nodeId)
            local constraintCoeffs = {} -- 约束条件系数
            for roadId, road in ipairs(controller.Roads) do
                if road.fromNode == node then
                    -- print('road', roadId, 'is fromNode', node.id)
                    constraintCoeffs[roadId] = 1 -- 出路径
                elseif road.toNode == node then
                    -- print('road', roadId, 'is toNode', node.id)
                    constraintCoeffs[roadId] = -1 -- 入路径
                else
                    constraintCoeffs[roadId] = 0  -- 不经过
                end
            end

            local b = 0 -- 初始化约束右端项
            -- 起始点判断
            if node.id == fromNodeId then
                b = 1  -- 始点净流量为1
            elseif node.id == toNodeId then
                b = -1 -- 终点净流量为-1
            end

            stp:addrow(constraintCoeffs, '==', b)
            -- print(table.unpack(constraintCoeffs), '==', b)
            local str = ''
            for k, v in ipairs(constraintCoeffs) do
                str = str .. v .. ' '
            end
            print(str, '==', b)
        end

        -- 添加01变量
        for roadId = 1, #controller.Roads do
            stp:addrow('c' .. roadId, 'bin')
            -- print('r' .. roadId, 'bin')
        end
        stp:solve()

        local throughRoadIds = {}
        print('目标函数值：', stp['obj'])
        for i = 1, #controller.Roads do
            if stp['c' .. i] == 1 then
                table.insert(throughRoadIds, i)
                print('through road' .. i .. '=', stp['c' .. i])
            end
        end

        return throughRoadIds
    end

    --- 对道路id序列进行排序，使得相邻的道路id在controller.Roads中相邻
    --- @param nodeId number 初始节点id
    --- @param roadIds table 道路id序列
    function controller:sortRoadIdSequence(nodeId, roadIds)
        local result = { roads = {}, nodes = {} } -- 初始化返回结果
        local currentNode = controller.Nodes[nodeId]
        local currentRoad = nil

        for i = 1, #roadIds - 1 do
            for j = 1, #roadIds do
                for k, toRoad in ipairs(currentNode.toRoads) do
                    if toRoad.id == roadIds[j] then
                        currentRoad = toRoad
                        break
                    end
                end
                if currentRoad ~= nil then
                    table.remove(roadIds, j)
                    table.insert(result.roads, currentRoad)
                    table.insert(result.nodes, currentNode)
                    -- 轮换节点
                    currentNode = currentRoad.toNode
                    currentRoad = nil -- 重置currentRoad
                    break
                end
            end
        end
        -- 最后一个就不用查询了，直接插入
        table.insert(result.roads, controller.Nodes[roadIds[1]])
        table.insert(result.nodes, currentNode)

        -- debug：打印结果
        local strRoadSeq = ''
        for i, road in ipairs(result.roads) do
            strRoadSeq = strRoadSeq .. road.id .. (i == #result.roads and '' or ',')
        end
        print('roadSeq:', strRoadSeq)

        local strRoadSeq = ''
        for i, node in ipairs(result.nodes) do
            strRoadSeq = strRoadSeq .. node.id .. (i == #result.nodes and '' or ',')
        end
        print('nodeSeq:', strRoadSeq)

        return result
    end

    return controller
end
