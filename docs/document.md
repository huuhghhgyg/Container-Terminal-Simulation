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
Road对象会向agv注入`road`和`roadAgvId`两个属性，分别为道路对象和道路上对应的agvid。

所有权：现在Agv都在道路上，因此可以从道路中获取Agv。**问题:**需不需要建立一个Controller，用于管理Agv？这样就可以对所有Agv直接进行操作了。

一个CY只能绑定一个Road对象。

## 字段
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
- road.id: 道路id，用于在道路列表中索引道路

## 函数
- registerAgv(agv, params): 向道路注册agv。可以设置agv的初始位置
- removeAgv(agvId): 从道路移除agv，根据指定的agvid
- getAgvAhead(agvId): 获取指定id的agv前方的agv
- setAgvPos(dt, agvId): 根据
- maxstep(agvId): (interface)用于判断最大步进

## 其他
当需要根据`agvId`访问`road.agv`中的指定项时，应减去`agvLeaveNum`，以获得列表中的正确索引，如`roadAgvId-agvLeaveNum`

# RMG
## 字段

> 新增的字段在前面

- outerActionObjs: 外部动作对象列表。也就是控制器中的`actionObjs`，这样就可以使rmg访问到外部动作对象了。（**问题:**现在Agv都在道路上，都可以通过道路访问到，是否还需要这个？如果使用`actionObjs`，如何区别其中不同类型的对象）

# Controller
主要负责仿真的推进，对各个动作对象进行管理。主要功能是遍历动作对象，执行各个对象的任务。

## 字段
- ActionObjs: 动作对象列表，包含所有动作对象。Controller会通过`executeTask()`函数执行对象中的命令。
- simv: 仿真速度

# RoadMap 实现路线
agv和road都放在Controller里面，由Controller进行管理。对于agv的操作，Controller遍历所有agv，转到每个agv的road中进行操作。

1. 如何实现流转？如Crane对象可以内建agv列表对其进行引用，然后进行操作。

# CY
一个CY只能绑定一个Road对象，通过`cy.roadId`记录。

## 函数
- bindRoad(roadId): 绑定道路，将道路id记录到`cy.roadId`中，并将停车位的位置记录到`cy.parkingspaces`的`roadDistance`中

## 字段
cy.parkingspaces: 停车位列表，包含停车位的坐标、停车位相对道路的距离、对应的bay `{pos,roadDistance,bay}`

## params.old
通过新增`bindRoad`函数,可能删除以下字段:
- cy.queuelen: 纯排队长度(当时为了让足够多的agv排队而设置的冗余长度)
- cy.summon: 生成agv的点,和`cy.queuelen`一起使用
- cy.exit: 离开agv的点,之前由于元胞自动机模型设置为最后一个停车位,但现在不是了
- cy.agvspan: agv占用元胞的个数,现在不需要了,已经在road里面预定义
- cy.parkingSpaces
  - relativeDist: 道路的相对距离
  - iox: 该停车位对应的iox距离（锚点线到停车位的距离）