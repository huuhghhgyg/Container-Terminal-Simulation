local obj = {
    methods = {}, -- 方法列表{[name]=function}
    lastrun = nil
}

function obj:executeMethod(name, params)
    if obj.methods[name] == nil then
        return 'method not found'
    end

    local result
    if params == nil then
        result = obj.methods[name]()
    else
        result = obj.methods[name](table.unpack(params))
    end
    obj.lastrun = { name = name, result = result }
end

-- 注入方法
local function message(str)
    print(str)
    return 'value'
end
print(message)
obj.methods['message'] = message

obj:executeMethod('message', 'hello world')
print('lastrun (name=' , obj.lastrun.name , '; result=' , obj.lastrun.result , ')')

-- 再次注入
local sum = function(a, b)
    return a + b
end
obj.methods['sum'] = sum
obj:executeMethod('sum', { 1, 2 })
print('lastrun (name=' , obj.lastrun.name , '; result=' , obj.lastrun.result , ')')

-- 覆盖方法
obj.methods['message'] = function()
    print(':P')
end

obj:executeMethod('message')
print('lastrun (name=' , obj.lastrun.name , '; result=' , obj.lastrun.result , ')')
