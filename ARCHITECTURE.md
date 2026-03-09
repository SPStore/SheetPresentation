# SheetPresentation 架构设计

## 📐 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                         使用层 (Usage Layer)                      │
│                                                                  │
│  ViewController.cs_presentSheetViewController(_:animated:)       │
│                              ↓                                   │
│                    SheetViewController                           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                     转场管理层 (Transition Layer)                │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │      SheetTransitioningManager (UIViewControllerTransitioningDelegate)    │
│  │                                                           │  │
│  │  presentationController(forPresented:)  ←─────────┐      │  │
│  │  animationController(forPresented:)               │      │  │
│  │  animationController(forDismissed:)               │      │  │
│  │  interactionController(forDismissal:)             │      │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
         │                  │                  │
         ↓                  ↓                  ↓
┌────────────────┐ ┌────────────────┐ ┌────────────────────────┐
│ Presentation   │ │   Animation    │ │     Interaction        │
│    Controller  │ │    Animator    │ │     Controller         │
│                │ │                │ │                        │
│ SheetPresenta- │ │ SheetTransi-   │ │ SheetInteraction       │
│ tionController │ │ tionAnimator   │ │                        │
└────────────────┘ └────────────────┘ └────────────────────────┘
```

## 🏗️ 分层架构详解

### 第一层：使用层 (Usage Layer)
```swift
// 用户代码
ViewController
    ↓ 调用
cs_presentSheetViewController(_:animated:)
```

**职责**：
- 提供简单的API接口
- 隐藏内部复杂性
- 管理关联对象

### 第二层：转场管理层 (Transition Management Layer)
```
SheetTransitioningManager (协调者)
    ├─ 返回 PresentationController
    ├─ 返回 AnimatedTransitioning
    └─ 返回 InteractiveTransitioning
```

**职责**：
- 实现UIViewControllerTransitioningDelegate
- 协调各个组件的工作
- 决定使用哪个动画器和交互控制器

### 第三层：核心实现层 (Core Implementation Layer)

#### 3.1 SheetPresentationController (展示控制器)
```
UIPresentationController
    ↓ 继承
SheetPresentationController
    ├─ 管理配置属性（30+个）
    ├─ 创建和管理UI组件
    ├─ 计算frame和detent
    └─ 处理presentation生命周期
```

**核心属性**：
- `detents`: 多段高度配置
- `dimmingView`: 背景遮罩
- `sheetPresentedView`: sheet容器
- `sheetInteraction`: 交互控制器

**核心方法**：
- `presentationTransitionWillBegin()`: 创建UI
- `frameOfPresentedViewInContainerView`: 计算位置
- `getMinDetentY()`: 获取最小Y（触发转场的阈值）
- `getNearestDetentY(for:velocity:)`: 计算最近的detent

#### 3.2 SheetTransitionAnimator (动画器)
```
UIViewControllerAnimatedTransitioning
    ↓ 实现
SheetTransitionAnimator
    ├─ animatePresentation (present动画)
    └─ animateDismissal (dismiss动画)
```

**动画内容**：
- Present: 从底部滑入 + 背景渐显
- Dismiss: 向底部滑出 + 背景渐隐
- 使用spring动画

#### 3.3 SheetInteraction (交互控制器) ⭐️核心
```
UIPercentDrivenInteractiveTransition
    ↓ 继承
SheetInteraction
    ├─ 注册和管理pan手势
    ├─ 判断是否触发转场
    ├─ 手动控制视图位置
    └─ 处理交互式转场
```

**核心流程**：
```
handlePan(_:)
    ├─ .began → 记录初始状态
    ├─ .changed → handlePanChanged
    │       ├─ 计算新位置
    │       ├─ 判断 newY > minDetentY?
    │       │   ├─ YES → 触发dismiss + update(progress)
    │       │   └─ NO → 在detent间移动
    │       └─ updateSheetPosition (手动更新frame和alpha)
    └─ .ended → handlePanEnded
            ├─ 判断完成还是取消
            ├─ finish() 或 cancel()
            └─ 执行完成动画
```

### 第四层：UI组件层 (UI Component Layer)

```
┌─────────────────────────────────────────────────────┐
│                  containerView                       │
│  ┌────────────────────────────────────────────┐    │
│  │          SheetDimmingView                   │    │
│  │         (背景遮罩，点击dismiss)              │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │        SheetPresentedView                   │    │
│  │  ┌──────────────────────────────────────┐  │    │
│  │  │     SheetGrabber (抓取条)             │  │    │
│  │  └──────────────────────────────────────┘  │    │
│  │  ┌──────────────────────────────────────┐  │    │
│  │  │     ContentView (用户内容)            │  │    │
│  │  │                                       │  │    │
│  │  └──────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

#### UI组件说明：
1. **SheetDimmingView**: 半透明背景，支持点击dismiss
2. **SheetPresentedView**: sheet容器，提供圆角、阴影
3. **SheetGrabber**: 顶部指示器，扩大点击区域
4. **ContentView**: 用户提供的实际内容

## 🔄 数据流和控制流

### Present流程
```
1. 用户调用
   cs_presentSheetViewController(_:animated:)
       ↓
2. 设置transitioningDelegate
   viewController.transitioningDelegate = SheetTransitioningManager
       ↓
3. UIKit回调
   presentationController(forPresented:)
       ↓ 返回
   SheetPresentationController
       ↓
4. presentationTransitionWillBegin()
   创建：dimmingView, sheetPresentedView, sheetInteraction
   注册：sheetInteraction.registerPanGesture(to: sheetView)
       ↓
5. UIKit回调
   animationController(forPresented:)
       ↓ 返回
   SheetTransitionAnimator(isPresenting: true)
       ↓
6. animateTransition(using:)
   执行present动画
```

### 交互式Dismiss流程
```
1. 用户拖动sheet
   Pan Gesture Recognized
       ↓
2. SheetInteraction.handlePan(.changed)
       ↓
3. 计算位置
   newY = initialY + translation
       ↓
4. 判断是否超过阈值
   if newY > minDetentY
       ↓ YES
5. 触发dismiss
   presentedViewController.dismiss(animated: true)
       ↓
6. UIKit回调
   interactionController(forDismissal:)
       ↓ 返回
   SheetInteraction (因为 isInteracting == true)
       ↓
7. 继续拖动
   update(progress)  // UIPercentDrivenInteractiveTransition方法
   updateSheetPosition()  // 手动更新位置和透明度
       ↓
8. 松手
   handlePan(.ended)
       ↓
9. 判断完成或取消
   shouldDismiss?
       ├─ YES → finish() + animateDismissCompletion()
       └─ NO → cancel() + animateToNearestDetent()
```

### 在Detent间切换流程
```
1. 用户拖动sheet (newY <= minDetentY)
       ↓
2. SheetInteraction.handlePan(.changed)
   不触发dismiss，只更新位置
   updateSheetPosition(newY)
       ↓
3. 松手
   handlePan(.ended)
       ↓
4. 计算最近的detent
   nearestY = getNearestDetentY(for: currentY, velocity: velocity)
       ↓
5. 动画到目标位置
   animateToNearestDetent()
```

## 🎯 关键设计模式

### 1. 代理模式 (Delegate Pattern)
```
SheetTransitioningManager
    实现 → UIViewControllerTransitioningDelegate
    协调 → PresentationController, Animator, Interaction
```

### 2. 策略模式 (Strategy Pattern)
```
SheetDetent
    ├─ .large() → 返回 containerHeight - 50
    ├─ .medium() → 返回 containerHeight * 0.5
    ├─ .custom(height:) → 返回固定值
    └─ .custom(resolver:) → 执行闭包计算
```

### 3. 观察者模式 (Observer Pattern)
```
UIPanGestureRecognizer
    观察 → 用户手势
    通知 → SheetInteraction.handlePan(_:)
```

### 4. 外观模式 (Facade Pattern)
```
cs_presentSheetViewController(_:animated:)
    隐藏 → 复杂的转场配置过程
    提供 → 简单的API接口
```

## 🔐 职责分离

### SheetPresentationController 职责
✅ 管理配置属性
✅ 创建和管理UI组件
✅ 计算frame和detent位置
✅ 处理presentation生命周期
❌ 不处理手势
❌ 不直接执行动画

### SheetInteraction 职责
✅ 注册和管理手势
✅ 判断是否触发转场
✅ 手动控制视图位置和透明度
✅ 管理交互式转场进度
❌ 不管理配置
❌ 不创建UI

### SheetTransitionAnimator 职责
✅ 执行非交互式转场动画
✅ 处理present和dismiss动画
✅ 支持动画取消
❌ 不处理手势
❌ 不判断转场触发

### SheetTransitioningManager 职责
✅ 协调各组件
✅ 返回正确的controller/animator/interaction
✅ 判断是否需要交互控制器
❌ 不执行具体逻辑

## 📊 依赖关系图

```
UIViewController+SheetPresentation
    ↓ 创建
SheetTransitioningManager
    ↓ 返回
┌──────────────────────────┐
│ SheetPresentationController │ ←─── 被Animator和Interaction引用
│    ├─ sheetPresentedView    │
│    ├─ dimmingView           │
│    └─ sheetInteraction      │
└──────────────────────────┘
    ↓ 包含
┌──────────────────────────┐
│   SheetInteraction        │
│   (注册手势到presentedView) │
└──────────────────────────┘
```

**关键关系**：
- `SheetPresentationController` 创建并持有 `SheetInteraction`
- `SheetInteraction` 弱引用 `SheetPresentationController`（避免循环引用）
- `SheetTransitionAnimator` 弱引用 `SheetPresentationController`
- 所有组件都通过 `SheetTransitioningManager` 协调

## 🎨 核心算法

### 1. Detent位置计算
```swift
// 输入：detent类型，容器高度
// 输出：Y坐标

func resolvedHeight(containerHeight: CGFloat) -> CGFloat {
    switch type {
    case .large:
        return containerHeight - 50
    case .medium:
        return containerHeight * 0.5
    case .custom(let height):
        return height
    case .customResolver(let resolver):
        return resolver(containerHeight)
    }
}

// Y坐标 = 容器高度 - sheet高度
let yPosition = containerHeight - resolvedHeight
```

### 2. 转场触发判断
```swift
// 输入：当前Y位置，所有detent的Y位置
// 输出：是否触发dismiss

let minDetentY = detentYPositions.values.min()  // 最小的Y = 最大的高度

if currentY > minDetentY {
    // 超过最短高度，触发dismiss
    trigger dismiss
} else {
    // 在detent范围内，切换detent
    move between detents
}
```

### 3. 最近Detent选择
```swift
// 输入：当前Y，速度
// 输出：最近的detent Y坐标

if abs(velocity) > 300 {
    // 速度大时根据方向选择
    if velocity > 0 {
        // 向下 → 选更大的Y（更小的高度）
        return sortedY.first(where: { $0 > currentY })
    } else {
        // 向上 → 选更小的Y（更大的高度）
        return sortedY.last(where: { $0 < currentY })
    }
} else {
    // 速度小时选距离最近的
    return sortedY.min(by: { abs($0 - currentY) < abs($1 - currentY) })
}
```

### 4. 进度计算
```swift
// 输入：当前Y，最小detent Y，容器高度
// 输出：0-1的进度值

let dismissDistance = containerHeight - minDetentY
let progress = (currentY - minDetentY) / dismissDistance
let clampedProgress = min(max(progress, 0), 1)
```

## 🔧 扩展点

### 1. 新增Detent类型
```swift
// 在SheetDetent中添加新的case
case safeArea  // 根据安全区域计算
case keyboard  // 根据键盘高度计算
```

### 2. ScrollView联动
```swift
// 已预留接口
var synchronousScrollingScrollView: UIScrollView?

// 可以在SheetInteraction中监听ScrollView
// 实现滑动联动效果
```

### 3. 自定义动画
```swift
// 可以子类化SheetTransitionAnimator
class CustomAnimator: SheetTransitionAnimator {
    override func animatePresentation(...) {
        // 自定义动画效果
    }
}
```

## 🎯 总结

这个架构的优点：
1. ✅ **职责清晰**：每个类只负责一件事
2. ✅ **易于测试**：各组件相对独立
3. ✅ **易于扩展**：预留了多个扩展点
4. ✅ **符合iOS规范**：遵循UIKit的转场架构
5. ✅ **内存安全**：正确使用weak引用
6. ✅ **代码复用**：统一的动画方法

关键创新点：
- ⭐️ 手势驱动的位置控制（而非动画驱动）
- ⭐️ 智能的转场触发判断（基于Y位置阈值）
- ⭐️ 统一的交互式和非交互式动画
- ⭐️ 灵活的Detent配置系统

