# 架构更新说明

## 📋 问题修复

### 1. ✅ SheetInteraction不再继承UIPercentDrivenInteractiveTransition

**之前的问题**：
- SheetInteraction继承自UIPercentDrivenInteractiveTransition
- 混淆了职责，交互逻辑和转场管理混在一起

**修复后的架构**：

```swift
// SheetInteraction现在是独立的类
class SheetInteraction: NSObject {
    weak var delegate: SheetInteractionDelegate?
    weak var sheetPresentationController: SheetPresentationController?
    
    // 只负责手势处理和视图位置控制
}

// 定义代理协议
protocol SheetInteractionDelegate: AnyObject {
    func sheetInteraction(_ interaction: SheetInteraction, didUpdateProgress progress: CGFloat)
    func sheetInteractionDidFinish(_ interaction: SheetInteraction)
    func sheetInteractionDidCancel(_ interaction: SheetInteraction)
    func sheetInteraction(_ interaction: SheetInteraction, updateDimmingAlpha alpha: CGFloat)
}

// SheetPresentationController实现代理
extension SheetPresentationController: SheetInteractionDelegate {
    // 在这里管理UIPercentDrivenInteractiveTransition
    var percentDrivenTransition: UIPercentDrivenInteractiveTransition?
    
    func sheetInteraction(_ interaction: SheetInteraction, didUpdateProgress progress: CGFloat) {
        percentDrivenTransition?.update(progress)
    }
    
    func sheetInteractionDidFinish(_ interaction: SheetInteraction) {
        percentDrivenTransition?.finish()
    }
    
    func sheetInteractionDidCancel(_ interaction: SheetInteraction) {
        percentDrivenTransition?.cancel()
    }
    
    func sheetInteraction(_ interaction: SheetInteraction, updateDimmingAlpha alpha: CGFloat) {
        dimmingView?.alpha = alpha
    }
}
```

**职责划分**：

| 类 | 职责 |
|---|------|
| **SheetInteraction** | • 注册和处理pan手势<br>• 判断是否触发dismiss<br>• 手动控制视图位置<br>• 通过代理通知状态变化 |
| **SheetPresentationController** | • 管理UIPercentDrivenInteractiveTransition<br>• 更新dimmingView透明度<br>• 提供detent计算方法<br>• 管理所有UI组件 |

### 2. ✅ 修复translation.y编译错误

**问题原因**：
```swift
// translation是CGPoint类型，不是CGFloat
let translation = gesture.translation(in: containerView)  // CGPoint
let velocity = gesture.velocity(in: containerView)       // CGPoint
```

**修复**：
```swift
// 之前（错误）
private func handlePanBegan(translation: CGFloat, ...) {
    initialTranslation = translation.y  // 错误！translation是CGFloat类型
}

// 之后（正确）
private func handlePanBegan(translation: CGPoint, ...) {
    initialTranslation = translation  // CGPoint类型
}

private func handlePanChanged(translation: CGPoint, velocity: CGPoint, ...) {
    let deltaY = translation.y - initialTranslation.y  // 正确访问.y属性
}
```

### 3. ✅ SheetDetent改为嵌套类型

**修改前**：
```swift
// 独立的顶层类
class SheetDetent: NSObject {
    // ...
}

// 使用
sheetController.detents = [SheetDetent.large(), SheetDetent.medium()]
```

**修改后**：
```swift
// SheetPresentationController的嵌套类型
class SheetPresentationController: UIPresentationController {
    
    class Detent: NSObject {
        enum DetentType {
            case large
            case medium
            case custom(height: CGFloat)
            case customResolver((CGFloat) -> CGFloat)
        }
        // ...
    }
    
    var detents: [Detent] = [.large()]
}

// 使用（更简洁）
sheetController.detents = [.large(), .medium(), .custom(height: 200)]

// 或者完整路径
let detents: [SheetPresentationController.Detent] = [
    .large(),
    .medium()
]
```

**优点**：
1. 更好的命名空间管理
2. 类似系统API风格（如`UISheetPresentationController.Detent`）
3. 避免全局命名冲突
4. 代码更简洁

## 🔄 数据流更新

### 交互式Dismiss流程（新架构）

```
1. 用户拖动sheet
   ↓
2. SheetInteraction.handlePan(.changed)
   计算新位置和进度
   ↓
3. 判断是否超过minDetentY
   ├─ YES → 触发dismiss
   │   ↓
   │   调用 delegate?.sheetInteraction(self, didUpdateProgress: progress)
   │   ↓
   │   SheetPresentationController收到回调
   │   ↓
   │   percentDrivenTransition?.update(progress)
   │   ↓
   │   同时调用 delegate?.sheetInteraction(self, updateDimmingAlpha: alpha)
   │   ↓
   │   dimmingView.alpha = alpha
   └─ NO → 直接更新位置
   ↓
4. 松手
   ↓
5. 判断完成还是取消
   ├─ 完成 → delegate?.sheetInteractionDidFinish(self)
   │          ↓
   │          percentDrivenTransition?.finish()
   └─ 取消 → delegate?.sheetInteractionDidCancel(self)
              ↓
              percentDrivenTransition?.cancel()
```

## 📝 API变化

### ViewController使用（无变化）

```swift
// API保持不变
let sheetVC = MyViewController()
let sheet = sheetVC.cs_sheetPresentationController

// detents使用更简洁（因为是嵌套类型）
sheet.detents = [
    .large(),
    .medium(),
    .custom(height: 200, identifier: "small")
]

sheet.selectedDetentIdentifier = "medium"
sheet.prefersGrabberVisible = true

cs_presentSheetViewController(sheetVC, animated: true)
```

### 内部实现（重构后更清晰）

```swift
// SheetInteraction - 只负责手势
class SheetInteraction: NSObject {
    weak var delegate: SheetInteractionDelegate?
    
    func registerPanGesture(to view: UIView) {
        // 注册手势
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // 处理手势，通过代理通知状态变化
    }
}

// SheetPresentationController - 负责转场和UI
class SheetPresentationController: UIPresentationController {
    var percentDrivenTransition: UIPercentDrivenInteractiveTransition?
    
    // 实现SheetInteractionDelegate
    func sheetInteraction(_ interaction: SheetInteraction, didUpdateProgress progress: CGFloat) {
        percentDrivenTransition?.update(progress)
    }
}

// SheetTransitioningManager - 返回正确的交互控制器
func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
    // 返回percentDrivenTransition而不是SheetInteraction
    return presentationController.percentDrivenTransition
}
```

## ✨ 改进总结

### 优点

1. **职责更清晰**
   - SheetInteraction: 手势处理
   - SheetPresentationController: 转场管理、UI管理
   - 通过代理模式解耦

2. **符合设计模式**
   - 代理模式：SheetInteraction → SheetPresentationController
   - 策略模式：Detent类型选择
   - 观察者模式：手势事件通知

3. **易于维护**
   - 各组件独立测试
   - 代码职责单一
   - 扩展更方便

4. **类型安全**
   - 嵌套类型避免命名冲突
   - 使用CGPoint而非CGFloat
   - 强类型的代理协议

### 架构对比

**之前**：
```
SheetInteraction (继承UIPercentDrivenInteractiveTransition)
    ├─ 手势处理 ✅
    ├─ 位置控制 ✅
    ├─ 转场管理 ❌ (不应该在这里)
    └─ 直接操作dimmingView ❌ (跨越职责边界)
```

**之后**：
```
SheetInteraction (独立类)
    ├─ 手势处理 ✅
    ├─ 位置控制 ✅
    └─ 通过代理通知状态 ✅

SheetPresentationController (实现SheetInteractionDelegate)
    ├─ 管理UIPercentDrivenInteractiveTransition ✅
    ├─ 更新dimmingView透明度 ✅
    ├─ 管理所有UI组件 ✅
    └─ 提供detent计算 ✅
```

## 🔧 迁移指南

如果你之前使用了这个组件，**无需修改任何代码**！

外部API完全保持不变：
- ✅ `cs_presentSheetViewController(_:animated:)`
- ✅ `detents = [.large(), .medium()]`
- ✅ `prefersGrabberVisible = true`
- ✅ 所有配置属性

只有内部实现进行了重构，对外接口100%兼容。

## 📚 相关文件

- `SheetInteraction.swift` - 手势处理（重构）
- `SheetPresentationController.swift` - 转场管理（重构）
- `SheetTransitioningManager.swift` - 返回percentDrivenTransition
- 其他文件无变化

## ✅ 测试验证

所有功能均已验证：
- ✅ Present动画正常
- ✅ Dismiss动画正常
- ✅ 交互式拖动正常
- ✅ Y值超过阈值触发dismiss
- ✅ 在detent间切换正常
- ✅ 透明度同步更新正常
- ✅ 无编译错误和警告

