# Might be useful

根据两点计算旋转弧度的公式（可能有用）

```lua
cy.rotradian = math.atan2(p2[2] - p1[2], p2[1] - p1[1])
```

## debug

```lua
debug.watch('x') -- 观察变量x的值（表也可以）
debug.debug()
debug.debug(false) -- 退出debug模式
```

其他debug命令
https://www.runoob.com/lua/lua-debug.html

Lua版本：5.4