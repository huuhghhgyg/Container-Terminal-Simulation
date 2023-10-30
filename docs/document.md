# 移动对象接口

## maxstep()
用于计算本对象在本次任务内能够推进的的最大剩余时间数。如果不进行这个判断，可能导致推进到这个任务已经结束的某个时间点，但是本任务却仍然没有结束。

目前，由于`maxstep()`首先被执行，因此需要判断是否需要在这个函数中进行一些初始化操作。（可能需要优化）

# Watchdog 仿真推进器
```lua
WatchDog(simv, ActionObjs)
```
主要负责仿真的推进，对各个动作对象进行管理。主要功能是遍历动作对象，执行各个对象的任务。

参数：
- ActionObjs: 动作对象列表，包含所有动作对象。Controller会通过`executeTask()`函数执行对象中的命令。
- simv: 仿真速度

## 字段
- `t` 当前仿真时间
- `dt` 推进步长
- `runcommand` 是否继续运行（flag）

## 函数
- `update()` 仿真推进
- `recycle()` 回收已经完成任务的对象

# RoadMap 实现路线
agv和road都放在Controller里面，由Controller进行管理。对于agv的操作，Controller遍历所有agv，转到每个agv的road中进行操作。

1. 如何实现流转？如Crane对象可以内建agv列表对其进行引用，然后进行操作。

# CY
一个CY只能绑定一个Road对象，通过`cy.roadId`记录。

## 函数
- bindRoad(roadId): 绑定道路，将道路id记录到`cy.roadId`中，并将停车位的位置记录到`cy.parkingspaces`的`roadDistance`中
- showBindingPoint(): 显示绑定道路对应的停车位点（debug用）

## 字段
cy.parkingSpaces: 停车位列表，包含停车位的坐标、停车位相对道路的距离、对应的bay `{pos,roadDistance,bay}`。对应于旧代码的`cy.parkingspace`

containerPositions: 集装箱对应的位置。对应于旧代码的`cy.pos`

## params.old
通过新增`bindRoad`函数,可能删除以下字段:
- cy.queuelen: 纯排队长度(当时为了让足够多的agv排队而设置的冗余长度)
- cy.summon: 生成agv的点,和`cy.queuelen`一起使用
- cy.exit: 离开agv的点,之前由于元胞自动机模型设置为最后一个停车位,但现在不是了
- cy.agvspan: agv占用元胞的个数,现在不需要了,已经在road里面预定义
- cy.parkingSpaces
  - relativeDist: 道路的相对距离
  - iox: 该停车位对应的iox距离（锚点线到停车位的距离）

# 集装箱存取函数规划
几种可能的动作
- 将集装箱从agv移动到datamodel。直接向下抓取agv集装箱，吊具最终在datamodel上方。`lift2TargetPos`（内置等待）
- 将集装箱从datamodel移动到agv。直接向下抓取指定位置集装箱，吊具最终在agv上方。`lift2agv`（内置等待）
- 将吊具从agv移动到datamodel。吊具最终在datamodel上方。`move2TargetPos`
- 将吊具从datamodel移动到agv。吊具最终在agv上方。`move2Agv`