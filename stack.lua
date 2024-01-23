function Stack(row, col, level, config)
    -- 参数检查
    if type(row) ~= "number" or type(col) ~= "number" or type(level) ~= "number" then
        print('初始化Stack失败，输入的row col level参数不正确:', row, col, level)
        print(debug.traceback())
    end

    -- 处理没有输入config的情况
    if config == nil then
        config = {}
    end

    local stack = {}
    stack.type = config.type or 'stack'
    -- 模型参数
    stack.clength = config.clength or 6.06
    stack.cwidth = config.cwidth or 2.44
    stack.cheight = config.cheight or 2.42
    stack.cspan = config.cspan or {0.6, 0.6} --{xspan, zspan}
    stack.containerUrls = config.containerUrls or {'/res/ct/container.glb', '/res/ct/container_brown.glb', '/res/ct/container_blue.glb',
    '/res/ct/container_yellow.glb'}
    -- 位置参数
    stack.origin = config.origin or {0, 0, 0} -- 原点：用于计算集装箱相对位置
    stack.rot = config.rot or 0 -- 旋转弧度
    -- 容量参数
    stack.row = row or 0 -- 行数
    stack.col = col or 0 -- 列数
    stack.level = level or 0 -- 层数

    -- 内置变量
    stack.containerPositions = {} -- 堆场各集装箱位置坐标列表(bay,row,level)
    stack.containers = {} -- 集装箱对象列表(使用相对坐标索引)

    -- 初始化计算参数
    function stack:init()
        stack.length = stack.clength * stack.col + (stack.col - 1) * stack.cspan[2] -- 堆场长度
        stack.width = stack.cwidth * stack.row + (stack.row - 1) * stack.cspan[1] -- 堆场宽度
        stack.anchorPoint = stack.anchorPoint or {stack.origin[1] + stack.width / 2, stack.origin[2], stack.origin[3] + stack.length} -- 锚点，可能自定义

        -- 集装箱层数
        stack.levelPos = {} -- 层数y坐标集合，已经考虑了origin的位置
        for i = 1, level + 1 do -- 考虑移动层
            stack.levelPos[i] = stack.origin[2] + stack.cheight * (i - 1)
        end

        -- 初始化集装箱对象表
        for i = 1, stack.row do
            stack.containerPositions[i] = {} -- 初始化
            stack.containers[i] = {}
            for j = 1, stack.col do
                stack.containerPositions[i][j] = {}
                stack.containers[i][j] = {}
                for k = 1, stack.level do
                    -- 初始化集装箱位置
                    local x = stack.origin[1] + (i - 1) * (stack.cwidth + stack.cspan[1]) + stack.cwidth / 2
                    local y = stack.origin[2] + stack.cheight * (k - 1)
                    local z = stack.origin[3] + (stack.col - j) * (stack.clength + stack.cspan[2]) + stack.clength / 2
                    stack.containerPositions[i][j][k] = {x, y, z}

                    -- 初始化集装箱对象列表
                    stack.containers[i][j][k] = nil
                end
            end
        end
    end

    stack:init()

    -- 绘制stack范围
    scene.addobj('polyline', {
        vertices = {stack.origin[1], stack.origin[2], stack.origin[3], stack.origin[1] + stack.width, stack.origin[2],
                    stack.origin[3], stack.origin[1] + stack.width, stack.origin[2], stack.origin[3] + stack.length,
                    stack.origin[1], stack.origin[2], stack.origin[3] + stack.length, stack.origin[1], stack.origin[2],
                    stack.origin[3]},
        color = 'green'
    })

    -- 将堆场所有可用位置填充集装箱
    function stack:fillAllContainerPositions()
        for i = 1, stack.row do
            for j = 1, stack.col do
                for k = 1, stack.level do
                    stack:fillWithContainer(i, j, k)
                end
            end
        end
    end

    --- 根据sum随机生成每个(stack.bay,stack.row)位置的集装箱数量
    ---@param sum number 生成的集装箱总数
    ---@param containerUrls table 集装箱链接(颜色)列表，可选参数
    function stack:fillRandomContainerPositions(sum, containerUrls)
        -- 参数检查
        if sum == nil then
            print(debug.traceback('没有输入随机生成集装箱总数'))
        end

        -- 注入集装箱颜色列表
        if containerUrls ~= nil then
            stack.containerUrls = containerUrls -- 修改stack的集装箱颜色列表
        end

        -- 初始化
        local containerNum = {}
        for i = 1, stack.row do
            containerNum[i] = {}
            for j = 1, stack.col do
                containerNum[i][j] = 0
            end
        end

        -- 随机生成
        local summon = 0
        while summon < sum do
            local row = math.random(stack.row)
            local bay = math.random(stack.col)
            if containerNum[row][bay] < stack.level then
                containerNum[row][bay] = containerNum[row][bay] + 1
                summon = summon + 1
            end
        end

        -- 填充
        for i = 1, stack.row do
            for j = 1, stack.col do
                for k = 1, stack.level do
                    -- 如果层数小于当前(row, bay)生成的层数，则放置集装箱，否则不放置
                    if k <= containerNum[i][j] then
                        stack:fillWithContainer(i, j, k)
                    end
                end
            end
        end
    end

    -- 在指定的(row, bay, level)位置生成集装箱
    function stack:fillWithContainer(row, bay, level)
        local url = stack.containerUrls[math.random(1, #stack.containerUrls)] -- 随机选择集装箱颜色
        local containerPos = stack.containerPositions[row][bay][level] -- 获取集装箱位置

        local container = scene.addobj(url) -- 生成集装箱
        container:setpos(table.unpack(containerPos)) -- 设置集装箱位置
        stack.containers[row][bay][level] = container
    end

    return stack
end
