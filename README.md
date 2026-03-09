# SheetPresentation - 快速开始

## 🎯 这是什么？

一个完全自定义的iOS Sheet组件，仿照系统的`UISheetPresentationController`实现，支持：
- ✅ 多段高度（Detents）
- ✅ 手势交互拖拽
- ✅ 平滑的转场动画
- ✅ 丰富的自定义选项

## 📋 核心特性

### 1️⃣ 手势完全由SheetInteraction管理
```swift
// SheetInteraction负责：
- 注册和处理平移手势
- 手动控制视图位置
- 管理交互式转场
- 判断是否触发dismiss
```

### 2️⃣ 位置和透明度手动控制
```swift
// 在pan过程中直接修改frame和alpha
presentedView.frame.origin.y = newY
dimmingView.alpha = targetAlpha * (1 - progress)
```

### 3️⃣ 智能转场触发
```swift
// Y值 > 最短detent高度 → 触发dismiss转场
// Y值 ≤ 最短detent高度 → 在detent之间切换
if newY > minDetentY {
    dismiss(animated: true)  // 开始交互式转场
}
```

## 🚀 5分钟上手

### Step 1: 创建要展示的内容

```swift
class MySheetViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        // 添加你的内容...
    }
}
```

### Step 2: 配置Sheet属性

```swift
let sheetVC = MySheetViewController()
let sheet = sheetVC.cs_sheetPresentationController

// 设置多段高度
sheet.detents = [
    .large(),                              // 接近全屏
    .medium(),                             // 屏幕50%
    .custom(height: 200, identifier: "small")  // 自定义200pt
]

// 初始高度
sheet.selectedDetentIdentifier = "medium"

// UI配置
sheet.prefersGrabberVisible = true        // 显示顶部指示器
sheet.preferredCornerRadius = 16          // 圆角16pt
sheet.backgroundAlpha = 0.5               // 背景透明度

// 交互配置
sheet.springDamping = 0.75                // 弹簧阻尼
sheet.allowsTapBackgroundToDismiss = true // 点击背景dismiss
```

### Step 3: 展示Sheet

```swift
self.cs_presentSheetViewController(sheetVC, animated: true)
```

就这么简单！🎉

## 📱 运行Demo

1. 打开 `SheetPresentationDemo.xcodeproj`
2. 运行项目（Cmd+R）
3. 点击"Present Sheet"按钮
4. 尝试拖动Sheet：
   - 向上拖 → 展开到更大的高度
   - 向下拖 → 收缩到更小的高度
   - 快速向下滑 → dismiss
   - 拖到底部 → dismiss

## 🎨 常用配置

### 基础配置
```swift
sheet.detents = [.large(), .medium()]              // 高度选项
sheet.selectedDetentIdentifier = "large"           // 初始高度
sheet.prefersGrabberVisible = true                 // 显示抓取条
sheet.preferredCornerRadius = 16                   // 圆角大小
```

### 视觉效果
```swift
sheet.backgroundAlpha = 0.5                        // 背景透明度
sheet.sheetContentBackgroundColor = .white         // 内容背景色
sheet.prefersShadowVisible = false                 // 是否显示阴影
```

### 交互行为
```swift
sheet.allowsTapBackgroundToDismiss = true          // 点击背景dismiss
sheet.allowsDragToDismiss = true                   // 允许拖拽dismiss
sheet.springDamping = 0.75                         // 弹簧效果（0-1）
sheet.minVerticalVelocityToTriggerDismiss = 800    // dismiss速度阈值
sheet.isHapticFeedbackEnabled = false              // 触觉反馈
```

## 🔧 自定义高度

### 固定高度
```swift
sheet.detents = [
    .custom(height: 300, identifier: "small"),
    .custom(height: 600, identifier: "large")
]
```

### 动态高度
```swift
sheet.detents = [
    .custom(identifier: "dynamic") { containerHeight in
        // 根据容器高度计算
        return containerHeight * 0.3
    }
]
```

## 📐 工作原理

```
用户操作          SheetInteraction处理           结果
───────────────────────────────────────────────────
拖动向下           计算新Y位置                   
  ↓                                            
newY > minY?      判断是否超过最短高度           
  ↓                                            
  YES  ──→        触发dismiss转场  ──→        开始dismiss
  NO   ──→        在detent间切换  ──→         移动到新位置
```

## 🎯 核心代码位置

想深入了解实现细节？看这些文件：

| 文件 | 作用 |
|-----|------|
| `SheetInteraction.swift` | ⭐️ 核心！手势处理和转场控制 |
| `SheetPresentationController.swift` | 主控制器，管理配置 |
| `SheetTransitionAnimator.swift` | 转场动画 |
| `SheetPresentedView.swift` | 视图包装器 |

## 💡 常见问题

### Q: 如何改变当前的detent？
```swift
sheet.selectedDetentIdentifier = "large"  // 会自动动画切换
```

### Q: 如何禁止dismiss？
```swift
sheet.allowsDragToDismiss = false
sheet.allowsTapBackgroundToDismiss = false
```

### Q: 如何自定义动画速度？
```swift
sheet.springDamping = 0.6  // 越小弹性越大，动画时间越长
```

### Q: 如何监听Sheet的状态变化？
目前dismiss时会自动调用转场完成回调：
```swift
cs_presentSheetViewController(sheetVC, animated: true) {
    print("Sheet presented")
}

// 在sheet内部
dismiss(animated: true) {
    print("Sheet dismissed")
}
```

## 📚 更多信息

- 详细API文档：查看 `USAGE.md`
- 实现原理：查看 `IMPLEMENTATION_SUMMARY.md`
- 示例代码：查看 `ViewController.swift`

## 🌟 特别说明

这个实现遵循您的三个核心要求：

1. ✅ 手势在SheetInteraction中处理，通过`registerPanGesture(to:)`注册
2. ✅ 视图位置和透明度完全由pan手势手动控制
3. ✅ Y值大于最短高度时触发dismiss，小于则在detent间切换

享受使用吧！🎊

