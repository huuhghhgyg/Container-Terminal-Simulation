# AGV

## 任务

### move2
```lua
{"move2", x, z, [occupied=bool, vectorDistanceXZ={dx, dz}, movedXZ={mx, mz}, originXZ={ox, oz}]}
```

#### 参数列表
- `param[1], param[2]` 目标位置(x,z)，默认y=0且所有设备均在初始平面
- `occupy` 元胞自动机排队模型中元胞位置是否占用
- `param.vectorDistanceXZ` xz方向向量距离（原函数 3，4）
- `param.movedXZ` xz方向已经移动的距离（原函数 5，6）
- `param.originXZ` xz方向初始位置（原函数 7，8）
- `param.initialized` 是否已经初始化