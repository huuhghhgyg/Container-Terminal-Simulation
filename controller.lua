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

        -- 添加OD信息
        table.insert(node1.toNodesId, node2.id)   -- node1中的去向节点ID列表中添加node2的id
        table.insert(node2.fromNodesId, node1.id) -- node2中的来源节点ID列表中添加node1的id

        return node1:createRoad(node2, controller.Roads)
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

        return stp
    end

    return controller
end
