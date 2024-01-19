# 总体待办事项
- [x] 排队车辆延迟问题
- [x] 将各组件提取模块
- [x] 多场桥排队线路
- [x] 提取ship和cy的父类stack
- [x] 提取crane作为RMG和RMGQC的父类
- [ ] 统一位置称呼为row, col, level
- [ ] 码头堆场整体自动布局

## AGV
- [x] [move2任务param参数](./components/agv.md#move2)规划及落实
- [x] 车辆转弯

## RMG
- [x] 需要修改，作业中直接把rmgqc设置为rmg的下一个了，现实中可能不太合理，可能需要一个调度器

# 当前任务 RoadMap
- [x] 移动闭塞排队，创建道路对象，修改AGV排队代码（方便后续道路的设计）
- [x] 对象原点应该在靠近(x,y,z)=(0,0,0)的位置，而不是在中心位置。方便后续进行旋转(已经通过`anchorPoint`解决,`origin`负责对象对齐)
- [x] AGV道路注册应该放到moveon任务中进行
- [x] 新建一个Controller负责道路规划

## Agent交互
- [x] 解释maxstep return 0，maxstep return -1，maxstep return maxstep的区别

# Bug修复
- [x] 怀疑waitoperator任务会导致时间推进不准确问题
- [x] 港口测试得到推进时间结果不同的问题（已经测试相同情况下相同仿真速度、不同仿真速度）

# 分支开发
- 旋转支持
- agv道路阻塞探测并保证时间推进准确