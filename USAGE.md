# SheetPresentation 使用指南

## 概述

这是一个完全自定义的UISheetPresentationController实现，模仿系统的Sheet效果，并提供了更灵活的配置选项。

## 核心特性

### ✅ 已实现的功能

1. **平移手势交互**
   - 手势添加在sheetPresentedView上
   - 手势注册和处理逻辑都在SheetInteraction.swift中
   - 通过`register手势方法`将手势添加到view上

2. **手动控制视图位置**
   - sheetPresentedView的位置完全由pan手势控制
   - 透明度等属性也由手势同步更新
   - 转场只负责同步其他动画

3. **多段高度支持**
   - 支持large、medium和自定义高度
   - 当sheetPresentedView的Y值大于最短高度时触发dismiss转场
   - 小于最短高度时停止转场，在多个detent之间切换

4. **交互式与非交互式转场统一**
   - 非交互式转场在animator的block中处理透明度变化
   - 交互式松手后的动画与非交互式UIView动画保持一致
   - 移动过程中的逻辑统一封装

## 组件架构

### 核心类

1. **SheetPresentationController**
   - 继承自UIPresentationController
   - 管理sheet的展示和配置
   - 提供丰富的配置属性

2. **SheetInteraction**
   - 继承自UIPercentDrivenInteractiveTransition
   - 管理平移手势和交互式转场
   - 控制视图位置和透明度

3. **SheetTransitionAnimator**
   - 实现UIViewControllerAnimatedTransitioning
   - 处理present和dismiss的动画

4. **SheetTransitioningManager**
   - 实现UIViewControllerTransitioningDelegate
   - 协调各个组件的工作

5. **SheetPresentedView**
   - 包装展示的内容视图
   - 提供圆角、阴影、抓取条等UI元素

6. **SheetDimmingView**
   - 背景遮罩视图
   - 支持点击dismiss

7. **SheetGrabber**
   - 顶部指示器（抓取条）
   - 扩大点击区域

## 使用方法

### 基本用法

```swift
// 1. 创建要展示的视图控制器
let sheetVC = YourViewController()

// 2. 配置Sheet属性
let sheetController = sheetVC.cs_sheetPresentationController
sheetController.detents = [.large(), .medium()]
sheetController.prefersGrabberVisible = true

// 3. 展示
cs_presentSheetViewController(sheetVC, animated: true)
```

### Detents配置

```swift
// 预定义的高度
sheetController.detents = [
    .large(),                              // 接近全屏（距顶部50pt）
    .medium(),                             // 屏幕高度的50%
    .custom(height: 200, identifier: "small")  // 自定义固定高度
]

// 使用resolver动态计算高度
sheetController.detents = [
    .custom(identifier: "custom") { containerHeight in
        return containerHeight * 0.3
    }
]

// 指定初始高度
sheetController.selectedDetentIdentifier = "medium"
```

### UI配置

```swift
// 圆角
sheetController.preferredCornerRadius = 16

// 显示抓取条
sheetController.prefersGrabberVisible = true

// 显示阴影
sheetController.prefersShadowVisible = true

// 背景透明度
sheetController.backgroundAlpha = 0.5

// 内容背景色
sheetController.sheetContentBackgroundColor = .white
```

### 交互配置

```swift
// 允许点击背景dismiss
sheetController.allowsTapBackgroundToDismiss = true

// 允许拖拽dismiss
sheetController.allowsDragToDismiss = true

// 弹簧阻尼系数（0-1，越小弹性越大）
sheetController.springDamping = 0.75

// dismiss触发速度阈值
sheetController.minVerticalVelocityToTriggerDismiss = 800.0

// 触觉反馈
sheetController.isHapticFeedbackEnabled = true
```

## 工作原理

### 1. 手势处理流程

```
用户拖动 → SheetInteraction捕获手势
         ↓
    判断位置和速度
         ↓
  ┌──────┴──────┐
  ↓             ↓
Y > 最短高度   Y < 最短高度
  ↓             ↓
触发dismiss   在detent间移动
  ↓             ↓
交互式转场    手动更新位置
```

### 2. 转场协调

- **Present**: Animator控制sheet从下往上滑入，同时显示背景遮罩
- **Dismiss（非交互式）**: Animator控制sheet向下滑出，同时隐藏背景遮罩
- **Dismiss（交互式）**: Interaction控制位置，Animator在松手后完成剩余动画

### 3. 位置计算

```swift
// 多段高度按Y坐标排序
detentYPositions = [
    "large": 50,        // 距顶部50pt
    "medium": 400,      // 屏幕高度50%的位置
    "small": 600        // 固定200高度的位置
]

// 最小Y值 = 最大高度（large）
minDetentY = 50

// 当前Y > minDetentY时，触发dismiss
// 当前Y <= minDetentY时，在多个detent间切换
```

## 关键实现细节

### 1. SheetInteraction中的手势注册

```swift
func registerPanGesture(to view: UIView) {
    let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
    panGesture.delegate = self
    view.addGestureRecognizer(panGesture)
    panGestureRecognizer = panGesture
}
```

### 2. 手动控制视图位置和透明度

```swift
private func updateSheetPosition(_ y: CGFloat, presentedView: SheetPresentedView, 
                                 progress: CGFloat, presentationController: SheetPresentationController) {
    // 手动设置frame
    presentedView.frame.origin.y = y
    
    // 同步更新透明度
    if let dimmingView = presentationController.dimmingView {
        let targetAlpha = presentationController.backgroundAlpha
        dimmingView.alpha = targetAlpha * (1 - progress)
    }
}
```

### 3. 转场触发判断

```swift
// 在handlePanChanged中
let minDetentY = presentationController.getMinDetentY()

if newY > minDetentY {
    if !isInteracting && !shouldTriggerDismiss {
        // 开始交互式转场
        isInteracting = true
        shouldTriggerDismiss = true
        presentationController.presentedViewController.dismiss(animated: true)
    }
}
```

### 4. 动画统一封装

```swift
// 交互式和非交互式使用相同的动画方法
private func animateSheet(to targetY: CGFloat, ...) {
    UIView.animate(
        withDuration: 0.5,
        delay: 0,
        usingSpringWithDamping: damping,
        initialSpringVelocity: initialVelocity,
        options: [.curveEaseOut, .allowUserInteraction]
    ) {
        presentedView.frame.origin.y = targetY
        dimmingView.alpha = targetAlpha
    }
}
```

## 示例项目

查看`ViewController.swift`中的完整示例：

- `ViewController`: 主页面，包含Present按钮
- `DemoSheetViewController`: Sheet内容页，展示TableView和各种交互

运行项目即可体验完整功能！

## 注意事项

1. **手势冲突**: SheetInteraction已处理与ScrollView的手势冲突，优先响应垂直方向拖动
2. **内存管理**: 使用weak引用避免循环引用
3. **转场状态**: 确保在转场过程中正确管理isInteracting状态
4. **多线程**: 所有UI操作都在主线程进行

## 未来扩展

可以根据需要添加以下功能：

1. ✅ ScrollView联动（已预留接口）
2. ✅ 侧滑返回（已预留配置）
3. ✅ 穿透触摸事件（已预留配置）
4. 更多动画效果（如pageSheet样式）

## License

MIT License

