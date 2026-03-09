# SheetPresentation 快速参考

## 🎯 核心概念

### SheetInteraction（手势交互）
```swift
class SheetInteraction: NSObject {
    weak var delegate: SheetInteractionDelegate?  // 代理：SheetPresentationController
    
    func registerPanGesture(to view: UIView)  // 注册手势
}
```

**职责**：
- ✅ 注册pan手势到sheetPresentedView
- ✅ 处理手势的began/changed/ended状态
- ✅ 判断是否触发dismiss（基于Y位置）
- ✅ 手动控制视图位置（直接修改frame.origin.y）
- ✅ 通过代理通知状态变化

**不负责**：
- ❌ 管理UIPercentDrivenInteractiveTransition
- ❌ 直接操作dimmingView
- ❌ 创建UI组件

### SheetPresentationController（展示控制器）
```swift
class SheetPresentationController: UIPresentationController, SheetInteractionDelegate {
    // 嵌套类型
    class Detent: NSObject { ... }
    
    var detents: [Detent]
    var percentDrivenTransition: UIPercentDrivenInteractiveTransition?
    var sheetInteraction: SheetInteraction?
    var dimmingView: SheetDimmingView?
    var sheetPresentedView: SheetPresentedView?
}
```

**职责**：
- ✅ 管理所有UI组件
- ✅ 管理UIPercentDrivenInteractiveTransition
- ✅ 实现SheetInteractionDelegate
- ✅ 计算detent位置
- ✅ 更新dimmingView透明度

## 📊 架构图

```
┌─────────────────────────────────────────┐
│       SheetInteraction                   │
│  (手势处理 & 位置控制)                    │
│                                          │
│  + registerPanGesture(to:)              │
│  + handlePan(_:)                        │
│  - updateSheetPosition(_:...)           │
└─────────────────────────────────────────┘
              │
              │ delegate
              ↓
┌─────────────────────────────────────────┐
│   SheetPresentationController            │
│  (转场管理 & UI管理)                      │
│                                          │
│  + percentDrivenTransition              │
│  + sheetInteraction                     │
│  + dimmingView                          │
│  + sheetPresentedView                   │
│  + detents: [Detent]                    │
│                                          │
│  实现 SheetInteractionDelegate:          │
│  - didUpdateProgress(_:)                │
│  - didFinish()                          │
│  - didCancel()                          │
│  - updateDimmingAlpha(_:)               │
└─────────────────────────────────────────┘
```

## 🔄 关键流程

### 1. Present流程
```swift
cs_presentSheetViewController(vc, animated: true)
  ↓
SheetTransitioningManager.presentationController(...)
  ↓ 返回
SheetPresentationController
  ↓
presentationTransitionWillBegin()
  ├─ 创建 dimmingView
  ├─ 创建 sheetPresentedView
  ├─ 创建 sheetInteraction
  └─ sheetInteraction.registerPanGesture(to: sheetView)
  ↓
SheetTransitionAnimator.animatePresentation(...)
  ├─ sheet从底部滑入
  └─ dimmingView透明度 0 → backgroundAlpha
```

### 2. 交互式Dismiss流程
```swift
用户拖动 → handlePan(.changed)
  ↓
newY > minDetentY?
  ├─ YES → 触发dismiss
  │   ↓
  │   delegate.sheetInteraction(self, didUpdateProgress: progress)
  │   ↓
  │   percentDrivenTransition?.update(progress)
  │   +
  │   delegate.sheetInteraction(self, updateDimmingAlpha: alpha)
  │   ↓
  │   dimmingView.alpha = alpha
  └─ NO → 在detent间移动
  ↓
松手 → handlePan(.ended)
  ↓
shouldDismiss?
  ├─ YES → delegate.sheetInteractionDidFinish(self)
  │        ↓
  │        percentDrivenTransition?.finish()
  └─ NO → delegate.sheetInteractionDidCancel(self)
           ↓
           percentDrivenTransition?.cancel()
```

### 3. 转场触发判断
```swift
let minDetentY = presentationController.getMinDetentY()  // 最小的Y = 最大的高度

if currentY > minDetentY {
    // Y值大于最短高度 → 触发dismiss转场
    dismiss(animated: true)
} else {
    // Y值小于等于最短高度 → 在detent间切换
    animateToNearestDetent(...)
}
```

## 💻 使用示例

### 基本用法
```swift
let sheetVC = MyViewController()
let sheet = sheetVC.cs_sheetPresentationController

sheet.detents = [.large(), .medium(), .custom(height: 200)]
sheet.selectedDetentIdentifier = "medium"
sheet.prefersGrabberVisible = true

cs_presentSheetViewController(sheetVC, animated: true)
```

### Detent配置
```swift
// 1. 预定义高度
sheet.detents = [
    .large(),   // containerHeight - 50
    .medium()   // containerHeight * 0.5
]

// 2. 固定高度
sheet.detents = [
    .custom(height: 200, identifier: "small"),
    .custom(height: 400, identifier: "medium")
]

// 3. 动态计算
sheet.detents = [
    .custom(identifier: "dynamic") { containerHeight in
        return containerHeight * 0.3
    }
]
```

### UI配置
```swift
sheet.preferredCornerRadius = 16           // 圆角
sheet.prefersGrabberVisible = true         // 显示抓取条
sheet.prefersShadowVisible = false         // 阴影
sheet.backgroundAlpha = 0.5                // 背景透明度
sheet.sheetContentBackgroundColor = .white // 内容背景
```

### 交互配置
```swift
sheet.allowsTapBackgroundToDismiss = true  // 点击背景dismiss
sheet.allowsDragToDismiss = true           // 允许拖拽dismiss
sheet.springDamping = 0.75                 // 弹簧阻尼（0-1）
sheet.minVerticalVelocityToTriggerDismiss = 800  // 速度阈值
```

## 🔑 关键点

### 1. 代理模式
```swift
protocol SheetInteractionDelegate: AnyObject {
    func sheetInteraction(_ interaction: SheetInteraction, didUpdateProgress progress: CGFloat)
    func sheetInteractionDidFinish(_ interaction: SheetInteraction)
    func sheetInteractionDidCancel(_ interaction: SheetInteraction)
    func sheetInteraction(_ interaction: SheetInteraction, updateDimmingAlpha alpha: CGFloat)
}

// SheetPresentationController实现代理
extension SheetPresentationController: SheetInteractionDelegate {
    func sheetInteraction(_ interaction: SheetInteraction, didUpdateProgress progress: CGFloat) {
        if percentDrivenTransition == nil {
            percentDrivenTransition = UIPercentDrivenInteractiveTransition()
        }
        percentDrivenTransition?.update(progress)
    }
    
    func sheetInteractionDidFinish(_ interaction: SheetInteraction) {
        percentDrivenTransition?.finish()
    }
    
    func sheetInteractionDidCancel(_ interaction: SheetInteraction) {
        percentDrivenTransition?.cancel()
        percentDrivenTransition = nil
    }
    
    func sheetInteraction(_ interaction: SheetInteraction, updateDimmingAlpha alpha: CGFloat) {
        dimmingView?.alpha = alpha
    }
}
```

### 2. 嵌套类型
```swift
// Detent是SheetPresentationController的嵌套类型
class SheetPresentationController: UIPresentationController {
    class Detent: NSObject {
        // ...
    }
    
    var detents: [Detent] = [.large()]
}

// 使用时可以省略类型前缀
sheetController.detents = [.large(), .medium()]

// 或者使用完整路径
let detents: [SheetPresentationController.Detent] = [.large()]
```

### 3. 手动位置控制
```swift
// 在SheetInteraction中直接修改frame
private func updateSheetPosition(_ y: CGFloat, presentedView: SheetPresentedView, 
                                 progress: CGFloat, presentationController: SheetPresentationController) {
    // 手动设置Y位置
    presentedView.frame.origin.y = y
    
    // 通过代理更新透明度
    let alpha = presentationController.backgroundAlpha * (1 - progress)
    delegate?.sheetInteraction(self, updateDimmingAlpha: alpha)
}
```

## 📦 文件清单

| 文件 | 行数 | 作用 |
|-----|-----|------|
| SheetInteraction.swift | 241 | 手势处理和位置控制 ⭐️ |
| SheetPresentationController.swift | 417 | 转场管理和UI管理 ⭐️ |
| SheetTransitionAnimator.swift | 131 | 转场动画 |
| SheetTransitioningManager.swift | 39 | 转场协调 |
| SheetPresentedView.swift | 108 | 视图包装器 |
| SheetDimmingView.swift | 51 | 背景遮罩 |
| SheetGrabber.swift | 44 | 抓取条 |
| UIViewController+SheetPresentation.swift | 49 | 便捷方法 |

## 🎯 核心改进

### 之前的问题
- ❌ SheetInteraction继承UIPercentDrivenInteractiveTransition
- ❌ 职责混乱
- ❌ translation.y编译错误

### 修复后
- ✅ SheetInteraction是独立类，通过代理与Controller通信
- ✅ 职责清晰：Interaction负责手势，Controller负责转场
- ✅ 使用CGPoint类型，正确访问.y属性
- ✅ Detent是嵌套类型，类似系统API

## 🚀 优势

1. **架构清晰** - 代理模式解耦
2. **职责单一** - 每个类只做一件事
3. **易于测试** - 组件相对独立
4. **类型安全** - 嵌套类型避免冲突
5. **符合规范** - 遵循iOS开发最佳实践

---

> 完整文档：README.md, USAGE.md, ARCHITECTURE.md

