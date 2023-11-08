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
        table.insert(node1.toNodesId, node2.id) -- node1中的去向节点ID列表中添加node2的id
        table.insert(node2.fromNodesId, node1.id) -- node2中的来源节点ID列表中添加node1的id

        return node1:createRoad(node2, controller.Roads)
    end

    function controller:createNetwork()

    end

    return controller
end
