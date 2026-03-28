# SheetPresentation 架构设计

## 整体架构图

```
┌────────────────────────────────────────────────────────────────────┐
│                        使用层 (Usage Layer)                         │
│                                                                    │
│  viewController.cs.presentSheetViewController(_:animated:)         │
│                              ↓                                     │
│          viewController.cs.sheetPresentationController             │
└────────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────────┐
│                    转场管理层 (Transition Layer)                     │
│                                                                    │
│  SheetTransitioningManager (UIViewControllerTransitioningDelegate) │
│  presentationController / animationController / interaction        │
│  beginInteraction / updateInteraction / finish / cancel            │
└────────────────────────────────────────────────────────────────────┘
         │                  │
         ↓                  ↓
┌────────────────┐ ┌────────────────┐
│ Presentation   │ │   Animation    │
│   Controller   │ │    Animator    │
│                │ │                │
│ SheetPresenta- │ │ SheetTransi-   │
│ tionController │ │ tionAnimator   │
└────────────────┘ └────────────────┘
         │
         ↓ 持有（UIInteraction）
┌────────────────────────┐
│   SheetInteraction     │
│  (UIInteraction)       │
│  pan + screenEdge pan  │
│  scrollView 联动        │
└────────────────────────┘
```

## 🏗️ 分层架构详解

### 第一层：使用层 (Usage Layer)

```swift
// 用户代码
viewController.cs.presentSheetViewController(_:animated:)

// 配置属性
viewController.cs.sheetPresentationController.detents = [.medium(), .large()]
```

**职责**：
- 通过 `CSWrapper` 命名空间提供简洁 API
- 隐藏内部复杂性
- 通过关联对象管理 `SheetTransitioningManager` 的生命周期

### 第二层：转场管理层 (Transition Management Layer)

```
SheetTransitioningManager (协调者)
    ├─ 返回 PresentationController
    ├─ 返回 AnimatedTransitioning（支持自定义）
    ├─ 返回 InteractiveTransitioning
    └─ 内置 UIPercentDrivenInteractiveTransition 管理
```

**职责**：
- 实现 `UIViewControllerTransitioningDelegate`
- 协调各组件工作
- 管理交互式转场进度（`beginInteraction` / `updateInteraction` / `finishInteraction` / `cancelInteraction`）
- 支持通过 `SheetPresentationControllerTransitionAnimating` 注入自定义非交互转场动画

### 第三层：核心实现层 (Core Implementation Layer)

#### 3.1 SheetPresentationController（展示控制器）

```
UIPresentationController
    ↓ 继承
SheetPresentationController
    ├─ 配置属性（SheetConfiguration 聚合）
    ├─ 布局计算（委托给 SheetLayoutInfo）
    ├─ 创建和管理 UI 组件
    ├─ 实现 SheetInteractionDelegate
    ├─ 管理交互式 dismiss（pan / screenEdge 两路）
    └─ 处理 presentation 生命周期
```

**核心属性**：
- `detents`: 多段高度配置
- `selectedDetentIdentifier`: 当前激活的 detent
- `dimmingView`: 背景遮罩
- `dropShadowView`: sheet 容器（`presentedView` 重写为此）
- `sheetInteraction`: 交互控制器（通过 `UIInteraction` 安装）
- `layoutInfo`: 布局计算器（`SheetLayoutInfo`）
- `configuration`: 行为配置（`SheetConfiguration`）

**核心方法**：
- `presentationTransitionWillBegin()`: 创建 UI、初始化布局
- `frameOfPresentedViewInContainerView`: 委托给 `layoutInfo` 计算
- `updatePresentedViewFrame(forYPosition:)`: 统一更新 sheet 位置
- `beginInteractiveDismiss()`: 触发交互式 dismiss
- `completeInteractiveTransition(finish:velocity:)`: 完成或取消交互式 dismiss

**两路交互式 dismiss**：
- `interactiveDismissSource == .pan`：拖拽越过最小 detent，sheet 帧手动驱动
- `interactiveDismissSource == .screenEdge`：侧滑返回，`UIPercentDrivenInteractiveTransition` 全程驱动

#### 3.2 SheetTransitionAnimator（动画器）

```
NSObject + UIViewControllerAnimatedTransitioning
    ↓ 实现
SheetTransitionAnimator
    ├─ animatePresentation（present 动画）
    └─ animateDismissal
          ├─ interactionDismiss（交互式，含 pan 占位 / screenEdge 真实动画 两分支）
          └─ nonInteractiveDismiss（非交互式）
```

**动画内容**：
- Present: 从底部滑入 + 背景渐显
- 非交互式 Dismiss: 向底部滑出 + 背景渐隐，spring 动画
- 交互式 Dismiss (screenEdge): 真实 sheet frame + dimming 动画，由 `UIPercentDrivenInteractiveTransition` 驱动
- 交互式 Dismiss (pan): 占位 alpha 动画（供 PDRIT 捕获），sheet 帧由控制器手动更新

`performAnimation(animations:completion:)` 为公开方法，供控制器内部在 finish 后补播剩余 dismiss 动画。

#### 3.3 SheetInteraction（交互控制器）⭐️ 核心

```
NSObject + UIInteraction
    ↓ 实现
SheetInteraction
    ├─ panGestureRecognizer（主平移手势）
    ├─ screenEdgePanGestureRecognizer（侧滑返回手势，可关闭）
    ├─ ScrollView 联动（观测 scrollView.panGestureRecognizer）
    ├─ 阻尼计算（下拉最小 detent / 上拉 overpull）
    └─ 通过 SheetInteractionDelegate 回调控制器
```

**核心流程**：

```
handlePan(_:) / handleObservedScrollPan(_:)
    ├─ .began → 通知 didBeginDragging
    ├─ .changed →
    │     applyDisplacementToSheet
    │         ├─ 计算阻尼系数（downward / overpull）
    │         ├─ 计算 newY（带边界 clamp）
    │         └─ delegate?.sheetInteraction(_:didChangeOffset:)
    └─ .ended →
          delegate?.sheetInteraction(_:draggingEndedWithVelocity:)

handleScreenEdgePan(_:)
    ├─ .began → delegate?.sheetInteractionDidBeginScreenEdgeInteraction
    ├─ .changed → delegate?.sheetInteraction(_:screenEdgeDidChangeProgress:)
    └─ .ended → delegate?.sheetInteraction(_:screenEdgeEndedWithVelocity:)
```

**ScrollView 联动策略**：
- 通过 `UIGestureRecognizerDelegate.shouldReceive(touch:)` 自动检测触摸下方的纵向 `UIScrollView`
- 观测其 `panGestureRecognizer`，通过"锁顶"机制（`lockToTop`）在 sheet 与 scrollView 之间平滑切换驱动权
- 前补偿 + 后补偿消除 sheet/scrollView 接力瞬间的位移漂移

#### 3.4 SheetLayoutInfo（布局计算器）

```
NSObject
    ↓
SheetLayoutInfo
    ├─ 管理 containerBounds / safeAreaInsets / traitCollection / detents / prefersFloatingStyle
    ├─ invalidateDetents()：重算所有 detent 的 Y 坐标
    ├─ frameOfPresentedView(at:)
    ├─ floatingPresentedLayout(at:)（浮动样式）
    ├─ nearestLandingTarget(to:allowsDismiss:)
    └─ dimmingProgress(at:)
```

从 `SheetPresentationController` 拆出，单独承载所有几何计算，使主控制器专注于生命周期与交互逻辑。

### 第四层：UI 组件层 (UI Component Layer)

```
┌─────────────────────────────────────────────────────┐
│                  containerView                       │
│  ┌────────────────────────────────────────────┐    │
│  │          SheetDimmingView                   │    │
│  │         （背景遮罩，点击 dismiss）            │    │
│  └────────────────────────────────────────────┘    │
│                                                      │
│  ┌────────────────────────────────────────────┐    │
│  │        SheetDropShadowView  ← presentedView │    │
│  │  ┌──────────────────────────────────────┐  │    │
│  │  │   effectContainerView（UIVisualEffectView） │  │
│  │  │   ├─ contentView（用户内容）          │  │    │
│  │  │   └─ SheetGrabber（顶部手柄，可点击） │  │    │
│  │  └──────────────────────────────────────┘  │    │
│  └────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
```

#### UI 组件说明：

1. **SheetDimmingView**: 半透明黑色背景，点击触发 dismiss；alpha 随 sheet 拖拽进度变化
2. **SheetDropShadowView**: sheet 容器，提供圆角（iOS 26 使用 `UICornerConfiguration`）、阴影、背景模糊效果（`backgroundEffect: UIVisualEffect?`）；重写为 `presentedView`
3. **effectContainerView (UIVisualEffectView)**: 常驻背景效果容器，支持 nil（透明）/ systemMaterial / UIGlassEffect
4. **SheetGrabber**: 顶部手柄指示器（UIControl），扩大点击区域；点击触发 `toggleNextDetent()`
5. **contentView**: 挂载用户提供的 `presentedViewController.view`

## 🔄 数据流和控制流

### Present 流程

```
1. 用户调用
   viewController.cs.presentSheetViewController(_:animated:)
       ↓
2. 设置 transitioningDelegate
   viewControllerToPresent.transitioningDelegate = cs.transitioningManager
       ↓
3. UIKit 回调
   presentationController(forPresented:)
       ↓ 返回
   SheetPresentationController
       ↓
4. presentationTransitionWillBegin()
   refreshLayoutInfo → 计算 detent Y 坐标
   setupViews → 创建 dimmingView, dropShadowView, 安装 sheetInteraction
   syncDetentYPositionsToInteraction → 传入 SheetInteraction
       ↓
5. UIKit 回调
   animationController(forPresented:)
       ↓ 返回
   SheetTransitionAnimator(isPresenting: true)
       ↓
6. animateTransition(using:)
   执行 present 动画（从底部滑入）
```

### 交互式 Dismiss 流程（拖拽）

```
1. 用户拖动 sheet
   Pan Gesture / ScrollView Pan 识别
       ↓
2. SheetInteraction → delegate?.sheetInteraction(_:didChangeOffset:)
       ↓
3. SheetPresentationController.sheetInteraction(_:didChangeOffset:)
   updatePresentedViewFrame(forYPosition:)
   updateDimmingForPosition(_:)
       ↓
4. 若 yPosition > smallestDetentY && !isBeingDismissed
   beginInteractiveDismiss()
       ├─ transitioningManager?.beginInteraction()
       └─ presentedViewController.dismiss(animated: true)
       ↓
5. UIKit 回调
   interactionControllerForDismissal → UIPercentDrivenInteractiveTransition
       ↓
6. 继续拖拽
   transitioningManager?.updateInteraction(percent)
   updatePresentedViewFrame(forYPosition:)   // 手动驱动帧
       ↓
7. 松手
   draggingEndedWithVelocity
       ↓
8. 判断完成或取消
   isBelow && (isHighVelocity || isNearBottom)?
       ├─ YES → completeInteractiveTransition(finish: true)
       │         transitioningManager?.finishInteraction()
       │         performDismissAnimation(duration:)
       └─ NO  → completeInteractiveTransition(finish: false)
                 transitioningManager?.cancelInteraction()
                 resolveDragEnd(velocity:) → 吸附到最近 detent
```

### 交互式 Dismiss 流程（侧滑返回）

```
1. 用户从屏幕边缘侧滑
   screenEdgePanGestureRecognizer 识别
       ↓
2. SheetInteraction → sheetInteractionDidBeginScreenEdgeInteraction
       ↓
3. SheetPresentationController
   beginInteraction → transitioningManager?.beginInteraction()
   presentedViewController.dismiss(animated: true)
       ↓
4. 继续拖拽
   screenEdgeDidChangeProgress → transitioningManager?.updateInteraction(progress)
   （动画由 SheetTransitionAnimator.interactionDismiss 内部 UIView.animate 驱动）
       ↓
5. 松手
   screenEdgeEndedWithVelocity
       ↓
6. shouldFinishScreenEdgeInteraction(velocity:)
       ├─ finish → transitioningManager?.finishInteraction()
       └─ cancel → transitioningManager?.cancelInteraction()
```

### 在 Detent 间切换流程

```
1. 用户拖动 sheet（yPosition <= smallestDetentY）
       ↓
2. SheetInteraction → didChangeOffset
   未触发 dismiss，只更新位置和 dimmingAlpha
       ↓
3. 松手 → resolveDragEnd(velocity:)
       ↓
4. 高速？
   ├─ velocity.y < 0（向上）→ resolveHighVelocityDragUp
   ├─ velocity.y > 0（向下）→ resolveHighVelocityDragDown
   └─ 低速 → snapToNearest（layoutInfo.nearestLandingTarget）
       ↓
5. setSelectedDetent(_:animated: true) → animateToDetent
```

## 🎯 关键设计模式

### 1. 代理模式 (Delegate Pattern)
```
SheetTransitioningManager
    实现 → UIViewControllerTransitioningDelegate

SheetInteraction
    通知 → SheetInteractionDelegate（由 SheetPresentationController 实现）
```

### 2. 命名空间包装 (Namespace Wrapper)
```
CSWrapper<UIViewController>
    提供 → .cs.presentSheetViewController
    提供 → .cs.sheetPresentationController
    管理 → SheetTransitioningManager（关联对象）
```

### 3. 策略模式 (Strategy Pattern)
```
SheetPresentationController.Detent（类）
    ├─ .large()    → safeAreaTop 动态计算
    ├─ .medium()   → containerHeight × 0.5
    └─ .custom(identifier:resolver:) → 闭包，接收 ResolutionContext
```

### 4. 观察者模式 (Observer Pattern)
```
UIPanGestureRecognizer（主手势）
UIPanGestureRecognizer（screenEdge 手势）
UIScrollView.panGestureRecognizer（观测式，addTarget）
    → SheetInteraction.handleXxx
    → SheetInteractionDelegate 回调
```

### 5. 外观模式 (Facade Pattern)
```
cs.presentSheetViewController(_:animated:)
    隐藏 → 复杂的转场配置和关联对象管理
    提供 → 一行调用的简单接口
```

### 6. 自定义转场扩展点
```
SheetPresentationControllerTransitionAnimating（可选协议）
    animatorForPresentTransition → 自定义 present 动画
    animatorForDismissTransition → 自定义非交互 dismiss 动画
```

## 🔐 职责分离

### SheetPresentationController 职责
✅ 管理配置属性（代理给 SheetConfiguration）
✅ 创建和管理 UI 组件
✅ 实现 SheetInteractionDelegate，响应手势回调
✅ 驱动交互式 dismiss（两路：pan / screenEdge）
✅ 处理 presentation 生命周期
✅ detent 动画吸附决策
❌ 不直接处理手势识别逻辑
❌ 不执行几何计算（委托给 SheetLayoutInfo）
❌ 不管理 UIPercentDrivenInteractiveTransition（委托给 SheetTransitioningManager）

### SheetInteraction 职责
✅ 注册和管理手势（pan + screenEdge）
✅ ScrollView 联动检测与驱动权切换
✅ 阻尼系数计算
✅ 通过 delegate 回调位移和生命周期事件
❌ 不管理配置
❌ 不创建 UI
❌ 不做转场决策（交由 delegate 判断）

### SheetLayoutInfo 职责
✅ 计算所有 detent 的 Y 坐标
✅ 生成 presented view 的 frame（普通 / 浮动样式）
✅ 提供最近落点（detent 或 dismiss）查询
✅ 计算 dimming 渐变进度
❌ 不持有任何视图
❌ 不执行动画

### SheetTransitionAnimator 职责
✅ 执行非交互式转场动画（present / dismiss）
✅ 执行交互式 dismiss 动画（screenEdge 真实动画 / pan 占位动画）
✅ 提供 `performAnimation` 供外部复用
❌ 不处理手势
❌ 不判断转场触发

### SheetTransitioningManager 职责
✅ 实现 UIViewControllerTransitioningDelegate
✅ 协调 PresentationController / Animator / Interaction
✅ 管理 UIPercentDrivenInteractiveTransition 生命周期
✅ 支持注入自定义 Animator
❌ 不执行具体动画逻辑

## 📊 依赖关系图

```
UIViewController + cs (CSWrapper)
    ↓ 关联对象持有
SheetTransitioningManager
    ↓ weak 持有
SheetPresentationController
    ├─ (strong) SheetLayoutInfo
    ├─ (strong) SheetConfiguration
    ├─ (strong) SheetInteraction（UIInteraction 安装到 dropShadowView）
    ├─ (weak)   SheetDimmingView
    └─ (weak)   SheetDropShadowView
                 ├─ effectContainerView (UIVisualEffectView)
                 │      ├─ contentView
                 │      └─ SheetGrabber
                 └─ SheetInteraction（通过 UIInteraction）

SheetInteraction
    └─ (weak) delegate → SheetPresentationController

SheetTransitionAnimator
    └─ 通过 transitionContext 获取 SheetPresentationController（无强引用）
```

**关键引用规则**：
- `SheetTransitioningManager` weak 引用 `SheetPresentationController`（UIKit 在转场期间持有 PC，避免环引用）
- `SheetInteraction` weak 引用 `delegate`（避免循环引用）
- `SheetPresentationController` 持有 `SheetInteraction`，SheetInteraction 通过 UIInteraction 协议安装到视图

## 🎨 核心算法

### 1. Detent 位置计算

```swift
// 输入：resolver 闭包 + containerBounds + safeAreaInsets
// 输出：DetentEntry { identifier, yPosition, height }

let height = detent.resolvedValue(in: context) ?? detent.height
let baseY   = containerBounds.height - height
let y       = prefersFloatingStyle ? baseY - floatingStyleMargin(at: baseY) : baseY
```

### 2. 松手后落点决策

```swift
// 高速情况（abs(velocity.y) >= 800 pt/s）
if velocity.y < 0 {
    resolveHighVelocityDragUp(from: currentY)   // 向更大 detent 跃进
} else {
    resolveHighVelocityDragDown(from: currentY) // 向更小 detent 或 dismiss
}

// 低速情况
snapToNearest(from: currentY)
// → layoutInfo.nearestLandingTarget(to:allowsDismiss:)
//    比较各 detent 距离与 dismiss 距离，返回最近落点
```

### 3. 阻尼计算

```swift
// 通用衰减公式：initial / (1 + decay × overflow)，最低 minimum
// 向下拖超出最小 detent（shouldDismiss == false 时）
factor = max(0.18, 1.0 / (1.0 + 0.05 × overflow))

// 向上 overpull 超出最大 detent（prefersSheetPanOverpullWithDamping == true）
factor = max(0.04, 0.3 / (1.0 + 0.01 × overflow))
```

### 4. 交互式 Dismiss 进度

```swift
// pan 路径
let percent = (yPosition - smallestDetentY) / (containerHeight - smallestDetentY)

// screenEdge 路径
let effectiveTranslationX = isRTL ? -rawTranslationX : rawTranslationX
let progress = effectiveTranslationX / screenWidth
```

### 5. ScrollView 联动补偿

```swift
// 前补偿：扣除本帧 scrollView 已消费的位移
let effectiveDelta = previousContentOffsetY > topOffsetY
    ? deltaY - (previousContentOffsetY - topOffsetY)
    : deltaY

// 后补偿：sheet 无法上移时，溢出位移回填给 scrollView
let overflow = fingerMoved - sheetMoved
scrollView.setContentOffset(CGPoint(y: contentOffset.y + overflow), animated: false)
```

## 🔧 扩展点

### 1. 自定义 Detent

```swift
let myDetent = SheetPresentationController.Detent.custom(identifier: .init("myDetent")) { ctx in
    ctx.maximumDetentValue * 0.7
}
sheetPC.detents = [myDetent, .large()]
```

### 2. 自定义非交互转场动画

```swift
// delegate 实现 SheetPresentationControllerTransitionAnimating
func animatorForPresentTransition(_ pc: SheetPresentationController)
    -> UIViewControllerAnimatedTransitioning? {
    return MyCustomPresentAnimator()
}
```

### 3. 浮动样式（iOS 26+）

```swift
if #available(iOS 26, *) {
    sheetPC.prefersFloatingStyle = true
}
```

### 4. ScrollView 联动控制

```swift
sheetPC.allowsScrollViewToDriveSheet = false
sheetPC.requiresScrollingFromEdgeToDriveSheet = true
sheetPC.prefersScrollingExpandsWhenScrolledToEdge = false
```

### 5. 侧滑返回

```swift
sheetPC.isEdgePanGestureEnabled = true
sheetPC.edgePanTriggerDistance = 44
```

## 🎯 总结

### 架构优点

1. ✅ **职责清晰**：布局（SheetLayoutInfo）、手势（SheetInteraction）、动画（SheetTransitionAnimator）、协调（SheetTransitioningManager）各司其职
2. ✅ **易于扩展**：自定义 Detent、自定义转场动画、浮动样式均预留扩展点
3. ✅ **符合 iOS 规范**：遵循 UIKit 转场架构，`UIPresentationController` / `UIViewControllerAnimatedTransitioning` / `UIPercentDrivenInteractiveTransition`
4. ✅ **内存安全**：所有跨组件引用均为 weak，无循环引用
5. ✅ **ScrollView 无缝联动**：补偿机制消除 sheet/scrollView 接力漂移

### 关键创新点

- ⭐️ `SheetInteraction` 实现 `UIInteraction`（而非继承 PDRIT），手势与转场进度完全解耦
- ⭐️ 双路交互式 dismiss（pan 帧手动驱动 + screenEdge PDRIT 驱动），共享同一套状态机
- ⭐️ 松手决策四分支：高速上/高速下/低速吸附，覆盖全部手势结束场景
- ⭐️ ScrollView 锁顶 + 双向补偿，实现 sheet 与内容区的平滑接力
- ⭐️ `SheetLayoutInfo` 批量更新机制，多属性同时变更只触发一次重算
