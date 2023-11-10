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
- road.fromNode: 道路起点Node节点对象
- road.toNode: 道路终点Node节点对象。用于检测占用状态

## 函数
- registerAgv(agv, params): 向道路注册agv。可以设置agv的初始位置
- removeAgv(agvId): 从道路移除agv，根据指定的agvid
- getAgvAhead(agvId): 获取指定id的agv前方的agv
- setAgvPos(dt, agvId): 设置指定id的agv在道路上的位置(需要提前对dt进行maxstep验证)
- setAgvDistance(distance, agvId): 设置指定id的agv在道路上的距离
- maxstep(agvId): (interface)用于判断最大步进
- register(): 向道路列表中注册道路，返回注册id
- getRelativeDist(x, z): 根据向量，获取点在道路对向量上投影的距离
- getRelativePosition(dist): 根据距离，获取道路上的点的位置

## 其他
当需要根据`agvId`访问`road.agv`中的指定项时，应减去`agvLeaveNum`，以获得列表中的正确索引，如`roadAgvId-agvLeaveNum`