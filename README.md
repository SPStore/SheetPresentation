<p align="center">
  <img src="https://raw.githubusercontent.com/SPStore/SheetPresentation/main/Assets/banner.png" title="SheetPresentation" width="960">
</p>
<p align="center">
  iOS 底部抽屉（Bottom Sheet）展示库，提供多档位、ScrollView 联动、侧滑返回、浮动样式等能力
</p>
<p align="center">
  <a href="https://github.com/SPStore/SheetPresentation"><img src="https://img.shields.io/badge/platform-iOS-blue.svg"></a>
  <a href="https://swift.org/"><img src="https://img.shields.io/badge/Swift-5.9-orange.svg"></a>
  <a href="https://developer.apple.com/ios/"><img src="https://img.shields.io/badge/iOS-13.0%2B-blue.svg"></a>
  <a href="https://github.com/SPStore/SheetPresentation/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg"></a>
  <a href="https://swift.org/package-manager/"><img src="https://img.shields.io/badge/SPM-compatible-brightgreen.svg"></a>
  <a href="https://cocoapods.org/pods/SheetPresentation"><img src="https://img.shields.io/badge/CocoaPods-compatible-brightgreen.svg"></a>
</p>

---

## 特性

- [x] **多档位（Detents）**：支持任意数量的高度档位，内置 `large()`、`medium()`，支持固定高度与动态 resolver 闭包
- [x] **ScrollView 无缝联动**：Sheet 内嵌列表/滚动视图时，手势在 Sheet 拖拽与 ScrollView 滚动之间自动切换，无需额外配置
- [x] **交互式 dismiss**：向下拖过最小档位可交互式关闭，支持速度判断与进度取消
- [x] **侧滑返回**：可选的屏幕边缘 Pan 手势，触发交互式横向 dismiss
- [x] **浮动样式（iOS 26+）**：`prefersFloatingStyle` 开启后四周带圆角与间距，随档位高度动态插值
- [x] **自定义转场动画**：通过 `SheetPresentationControllerTransitionAnimating` 协议注入自定义 present/dismiss 动画
- [x] **背景视觉效果**：`sheetBackgroundEffect` 支持 `UIBlurEffect`/`UIGlassEffect`（iOS 26+）或完全透明
- [x] **支持旋转**：横竖屏切换时 Sheet 位置与档位自动重新计算

---

## 功能演示

<p align="center">
  <img src="Assets/demo.gif" width="300">
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="Assets/demo2.gif" width="300">
</p>

---

## 系统要求

- iOS 13+
- Swift 5.9+
- Xcode 15+

---

## 安装

### Swift Package Manager

在 Xcode 中选择 **File → Add Package Dependencies**，填入仓库地址，或在 `Package.swift` 中添加：

```swift
dependencies: [
    .package(url: "https://github.com/SPStore/SheetPresentation.git", from: "1.0.2")
]
```

### CocoaPods

由于 `SheetPresentation` 在 CocoaPods 上已被其他库占用，因此安装名使用了带 `SP` 前缀的 `SPSheetPresentation`。

在 `Podfile` 中添加：

```ruby
pod 'SPSheetPresentation', '~> 1.0.2'
```

然后执行：

```bash
pod install
```

> 注意：注意：如果CocoaPods的方式安装，编译报错：SheetPresentation.framework/PrivacyInfo.xcprivacy: utimensat (2): Operation not permitted，请在你的主工程中的Targets -> Build Settings -> User Script Sandboxing 改为No


安装后代码中仍然使用：

```swift
import SheetPresentation
```

---

## 快速开始

### 最简示例

```swift
import SheetPresentation

// 在任意 UIViewController 中：
let contentVC = MyContentViewController()
sp.presentSheetViewController(contentVC, animated: true)
```

`sp` 是库为 `UIViewController` 提供的命名空间扩展，无需额外配置即可使用默认样式（单档 `large()`）。

### 配置档位

```swift
let contentVC = MyContentViewController()
let sheet = contentVC.sp.sheetPresentationController

sheet.detents = [.large(), .medium()]
sheet.selectedDetentIdentifier = .medium   // 初始显示中档

sp.presentSheetViewController(contentVC, animated: true)
```

### 三档位示例

```swift
let smallID = SheetPresentationController.Detent.Identifier("small")

sheet.detents = [
    .large(),
    .medium(),
    .custom(identifier: smallID) { _ in 220 }
]
sheet.selectedDetentIdentifier = smallID
```

---

## API 概览

### 访问 SheetPresentationController

```swift
// 通过被展示的 VC 访问
let sheet = contentVC.sp.sheetPresentationController

// NavigationController 场景
let sheet = navigationController?.sp.sheetPresentationController
```

### 展示

```swift
// 基础展示
sp.presentSheetViewController(contentVC, animated: true)

// 带 sourceView（iPad Popover）
sp.presentSheetViewController(contentVC, animated: true, sourceView: button)
```

### Detent 配置

```swift
// 内置档位
sheet.detents = [.large()]
sheet.detents = [.large(), .medium()]

// 固定高度
sheet.detents = [
    .custom(identifier: .init("panel")) { _ in 400 }
]

// 动态高度（根据容器尺寸计算）
sheet.detents = [
    .custom(identifier: .init("adaptive")) { ctx in
        ctx.maximumDetentValue * 0.6
    }
]
```

### 动画切换档位

```swift
sheet.animateChanges {
    sheet.selectedDetentIdentifier = .large
}
```

### 外观

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `preferredCornerRadius` | `CGFloat?` | `nil` | nil 时 iOS 26+ 逐角选择贴边同心或独立面板 40pt 样式，不设最小半径；显式值优先覆盖四角，0 为直角。低版本仍只设置顶角，默认 13pt |
| `prefersFullWidth` | `Bool` | `false` | 默认按容器尺寸与 Size Class 自适应限宽并居中；开启后恢复全宽布局 |
| `prefersGrabberVisible` | `Bool` | `false` | 顶部手柄 |
| `prefersShadowVisible` | `Bool` | `false` | 投影 |
| `dimmingBackgroundAlpha` | `CGFloat` | `0.4` | 背景遮罩透明度 |
| `sheetBackgroundEffect` | `UIVisualEffect?` | `nil` | Sheet 背景模糊/玻璃效果 |
| `prefersFloatingStyle` | `Bool` | `false` | 动态浮动样式（iOS 26+）：部分高度档位留白，large 贴底，档位之间连续过渡 |

自适应宽度基于当前展示容器计算，不依赖设备型号或 `UIScreen.main`；展开、折叠及分屏后会重新布局。
宽屏采用居中页面比例。iOS 26+ 顶部安全区不足 8pt 时，`.large()` 顶部和面板侧边保留 8pt，但底部贴边；
有顶部安全区时继续避让安全区，低版本保留原有高度规则。关闭浮动样式时，不额外添加底部间距。
开启浮动样式后，部分高度档位的底部留白为 8pt，接近最大高度时逐渐收敛到 0；
左右留白与自适应限宽取更严格的约束，不是在已经限宽的 frame 上再次内缩。
各档位先计算最终落点，拖动时在相邻落点的底部间距之间连续插值，越过最低档关闭时不再收窄。
自定义 resolver 的返回值仍表示面板整体高度（包含宿主需要的安全区），不会被间距重复扣减。
自适应限宽以当前系统 Sheet 的宽屏表现为基准：宽布局的宽度不超过容器高度减去两端边距；
这是对已测场景的近似适配，不是 UIKit 公开承诺的宽度算法。此规则由组件实现，不依赖未展示的系统弹窗或私有 API。

自动圆角用隐藏且不参与交互的窗口坐标参考视图承接公开的 `containerConcentric` API，
避免自定义转场容器缺少圆角上下文时把所有角解析为 0；不访问私有 API，也不按机型硬编码物理半径。
Swift 接口的 `nil` 表示自动样式，对应 UIKit Objective-C 的 `UISheetPresentationControllerAutomaticDimension`，不是半径 0。
圆角以当前档位的停靠布局为参照；下拉、回弹和关闭转场的临时位移不会改变这一参照或把顶部圆角切换为 40pt。
自动模式下，regular 宽布局或有侧边留白的面板，在停靠 frame 实际贴底时使用底部直角，包含 `large` 与自定义高度档位。
浮动面板不贴底时保留底部圆角，compact 全宽面板保留设备同心底角；判断基于停靠几何与 Size Class，而非档位名称或设备型号。
显式设置的圆角半径仍优先，包括 `0`。
贴边范围由窗口四角中最大的设备圆角决定，避免非对称设备的小角被面板边距误判为独立面板。
该范围内逐角使用 UIKit 的同心解析结果；较小设备角被边距完全抵消时保留该设备角本身的半径，不补成大圆角。
例如外屏设备角为 8pt/59pt、面板边距为 8pt 时，面板顶部采用 8pt/51pt，而非 40pt/51pt。
停靠布局位于窗口圆角范围之外时，采用独立面板的 40pt 设计值；这是组件的默认样式，不是全局最小半径，也不承诺与系统 Sheet 完全一致。
没有固定 8pt/80pt 的圆角判断门槛。参考视图随弹窗移除而清理，切换停靠档位、旋转、折叠/展开或窗口尺寸变化后重新计算。
圆角策略不改变面板的宽度、外边距与档位高度；显式设置半径时不参与自动场景判断。

```swift
// 默认使用自动圆角，也可以在运行时恢复自动模式。
sheet.preferredCornerRadius = nil

// 明确要求直角，不会被当作未指定。
sheet.preferredCornerRadius = 0

// 需要沿用固定样式时显式配置。
sheet.preferredCornerRadius = 24
sheet.prefersFullWidth = true
```

### 交互行为

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `allowsTapBackgroundToDismiss` | `Bool` | `true` | 点击背景关闭 |
| `allowsPanGestureToDriveSheet` | `Bool` | `true` | 拖拽手势驱动 Sheet |
| `allowsScrollViewToDriveSheet` | `Bool` | `true` | ScrollView 驱动 Sheet |
| `prefersScrollingExpandsWhenScrolledToEdge` | `Bool` | `true` | 滚到顶端可展开到上一档 |
| `requiresScrollingFromEdgeToDriveSheet` | `Bool` | `false` | 要求从内容顶部开始才能驱动 Sheet |
| `prefersSheetPanOverpullWithDamping` | `Bool` | `false` | 最大档上拉阻尼回弹 |
| `isEdgePanGestureEnabled` | `Bool` | `false` | 侧滑返回手势 |
| `edgePanTriggerDistance` | `CGFloat` | `32` | 侧滑触发边距（pt） |

---

## 进阶用法

### 监听档位变化

```swift
// 让 delegate 实现 SheetPresentationControllerDelegate
class MyViewController: UIViewController, SheetPresentationControllerDelegate {

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    ) {
        print("当前档位：\(sheetPresentationController.selectedDetentIdentifier?.rawValue ?? "-")")
    }
}

// 赋值 delegate
sheet.delegate = self
```

### 禁止关闭（模态锁定）

```swift
contentVC.isModalInPresentation = true
// 配合 delegate 弹提示
func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
    // 弹出确认弹窗
}
```

### 背景模糊效果

```swift
// 使用系统模糊
sheet.sheetBackgroundEffect = UIBlurEffect(style: .systemMaterial)

// iOS 26+ 使用玻璃效果
if #available(iOS 26, *) {
    sheet.sheetBackgroundEffect = UIGlassEffect()
}

// 无效果（透明背景）
sheet.sheetBackgroundEffect = nil
```

### 浮动样式（iOS 26+）

```swift
if #available(iOS 26, *) {
    sheet.prefersFloatingStyle = true
}
```

开启后 Sheet 在部分高度档位采用浮动留白，向上到 large 时贴底；左右间距不会与宽屏限宽叠加。
拖动、档位切换和转场共用最终 frame 的计算，自动圆角仍参照各档位停靠布局，避免关闭时改变设备非对称顶角。
宽度与留白以系统 Sheet 的已测场景为基准；档位高度契约与自定义拖拽实现保持组件自身语义，不承诺复制 UIKit 未公开的内部动画。

### 自定义转场动画

让 `delegate` 同时实现 `SheetPresentationControllerTransitionAnimating`：

```swift
extension MyViewController: SheetPresentationControllerTransitionAnimating {

    func animatorForPresentTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeAnimator(isPresenting: true)
    }

    func animatorForDismissTransition(
        _ sheetPresentationController: SheetPresentationController
    ) -> UIViewControllerAnimatedTransitioning? {
        FadeAnimator(isPresenting: false)
    }
}
```

返回 `nil` 使用库内置动画。交互式 dismiss（拖拽/侧滑）始终使用库内实现。


## License

MIT
