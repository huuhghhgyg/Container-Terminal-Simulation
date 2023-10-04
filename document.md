# 移动对象接口

## maxstep()
用于计算本对象在本次任务内能够推进的的最大剩余时间数。如果不进行这个判断，可能导致推进到这个任务已经结束的某个时间点，但是本任务却仍然没有结束。

目前，由于`maxstep()`首先被执行，因此需要判断是否需要在这个函数中进行一些初始化操作。（可能需要优化）

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
- `param.speed` 各个方向的分速度，也用于判断是否已经初始化

# Road
- agvs: 用于道路控制的、包含agv对象和道路相关信息的列表
  - agv: agv对象
  - id: 道路为此agv分配的id
  - distance: agv在道路上已移动的距离（可以作为初始位置设置）
  - targetDistance: agv在道路上移动的目标距离
- agvId: 已为agv分配的id，同`agvs.id`
- agvLeaveNum: 已离开此道路（删除）的agv数量
- road.vec: 道路方向向量(x,y,z)
- road.length: 道路长度
- road.vecE: 道路单位向量(x,y,z)

## 其他
当需要根据`agvId`访问`road.agv`中的指定项时，应减去`agvLeaveNum`，以获得列表中的正确索引，如`roadAgvId-agvLeaveNum`