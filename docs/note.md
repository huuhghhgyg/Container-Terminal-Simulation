# Might be useful

根据两点计算旋转弧度的公式（可能有用）

```lua
cy.rotradian = math.atan2(p2[2] - p1[2], p2[1] - p1[1])
```

## 文件管理
publish按钮的右键是share，可以将文件上传。使用`os.upload`可以将文件从远程拉取到web的虚拟磁盘中。
```lua
os.upload('https://mixwind-1.github.io/test.txt') -- 将内容上传到虚拟磁盘中
```

## debug
常用debug函数
```lua
debug.watch('x') -- 观察变量x的值（表也可以）
debug.debug()
debug.debug(false) -- 退出debug模式
```

堆栈跟踪
```lua
function myFunction()
    -- 某些代码逻辑
    print(debug.traceback("Stack trace"))
    -- 其他代码逻辑
end

function anotherFunction()
    myFunction()
end

anotherFunction()
```

其他debug命令
https://www.runoob.com/lua/lua-debug.html

Lua版本：5.4

# 常见错误
```lua
agv:addtask('moveon', {road=,}) -- 参数键值列表，记得param加大括号
agv:addtask('onnode', {node, fromRoad, toRoad}) -- 参数列表，顺序参数，记得param加大括号
```

## table
表之间的等值判断使用地址进行判断
使用if判断table变量的时候，只要table不是nil则返回true