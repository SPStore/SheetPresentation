import CoreLocation
import MapKit
import UIKit

/// 全屏地图、定位，进入后自动弹出地点搜索 Sheet。
final class MapDemoEntryViewController: UIViewController {

    /// `setRegion` 等会触发 `regionWillChange`；用深度计数跳过，避免首屏定位时误把 Sheet 收成短档。
    private var programmaticRegionChangeDepth = 0

    private let mapView: MKMapView = {
        let v = MKMapView(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.showsUserLocation = true
        return v
    }()

    private lazy var locationManager: CLLocationManager = {
        let m = CLLocationManager()
        m.delegate = self
        return m
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Map"
        view.backgroundColor = .white
        mapView.delegate = self
        view.addSubview(mapView)
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()

        configureMapCustomBackBarButtonItem()
        
        DispatchQueue.main.async {
            self.presentLocationSheetIfNeeded()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        centerMapOnUserOrDefault(animated: animated)
        // 本示例禁用全屏侧滑返回，避免与地图穿透、sheet 生命周期搅在一起；离开本页时恢复。
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if isMovingFromParent {
            // MKMapView 销毁前断开 delegate 并移出视图层级，
            // 避免 GPU 命令缓冲区还在引用 Metal drawable 时触发断言崩溃。
            mapView.delegate = nil
            mapView.removeFromSuperview()
        }
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        // 兜底：非自定义返回路径（如将来恢复侧滑）仍会在移出容器时收起 sheet。
        if parent == nil, presentedViewController != nil {
            dismiss(animated: false)
        }
    }

    /// 用 `leftBarButtonItem` 自定义返回（`backBarButtonItem` 是上一页设置的，不作用在当前页导航栏左侧）。
    private func configureMapCustomBackBarButtonItem() {
        let item = UIBarButtonItem(
            image: UIImage(systemName: "chevron.backward"),
            style: .plain,
            target: self,
            action: #selector(mapCustomBackTapped)
        )
        item.accessibilityLabel = NSLocalizedString("Back", comment: "")
        navigationItem.leftBarButtonItem = item
    }

    @objc private func mapCustomBackTapped() {
        dismissPresentedSheetIfNeeded()
        navigationController?.popViewController(animated: true)
    }

    private func dismissPresentedSheetIfNeeded() {
        guard presentedViewController != nil else { return }
        dismiss(animated: false)
    }

    private func presentLocationSheetIfNeeded() {
        guard presentedViewController == nil else { return }

        let vc = MapSheetDemoViewController()
        vc.isModalInPresentation = true

        let sheet = vc.cs.sheetPresentationController
        let settings = SheetDemoSettingsStore.shared
        // 应用全局配置
        settings.configure(sheetController: sheet)
        
        sheet.allowsTapBackgroundToDismiss = false
        sheet.dimmingBackgroundAlpha = 0
        sheet.prefersShadowVisible = true
        sheet.detents = MapSheetDemoViewController.makeMapDetents()
        sheet.selectedDetentIdentifier = MapSheetDemoViewController.DetentID.medium

        // `containerView` / 内部 dimming 仅在 present 完成后才就绪。在业务侧用 KVC + 公开属性组合配置穿透，
        cs.presentSheetViewController(vc, animated: false) {
            Self.configureMapSheetTouchPassThrough(for: vc)
        }
    }

    /// 地图场景：容器 `ignoreDirectTouchEvents` + 关闭蒙层交互。
    /// 蒙层在 `setupViews` 里先于 sheet 加入 `containerView`；用运行时类名识别，避免依赖跨模块不可见的 `SheetDimmingView` 类型。
    private static func configureMapSheetTouchPassThrough(for presented: UIViewController) {
        guard let sheet = presented.presentationController as? SheetPresentationController,
              let container = sheet.containerView else { return }

        // 实现穿透一共做2件事：
        // 1. 通过KVC的方式上设置 sheet.containerView 的私有属性 ignoreDirectTouchEvents 为 true
        // 2. 关闭 sheet 组件内部的 dimmingView 的交互
        // 由于穿透场景较为特殊，就没封装在组件内部.
        container.applyIgnoreDirectTouchEventsIfSupported(true)

        guard let dimming = dimmingSubview(of: sheet) else { return }
        dimming.isUserInteractionEnabled = false
    }

    private static func dimmingSubview(of sheet: SheetPresentationController) -> UIView? {
        guard let cls = sheetDimmingViewRuntimeClass else { return nil }
        return sheet.containerView?.subviews.first { $0.isKind(of: cls) }
    }

    /// Swift 未加 `@objc(SheetDimmingView)` 时，运行时类名多为 `模块名.SheetDimmingView`；短名需在组件侧 `@objc` 暴露。
    private static let sheetDimmingViewRuntimeClass: AnyClass? = {
        let candidates: [String] = [
            "SheetDimmingView",
            "SheetPresentationDemo.SheetDimmingView",
            sheetDimmingQualifiedRuntimeClassName()
        ]
        for name in candidates {
            if let c = NSClassFromString(name) { return c }
        }
        return nil
    }()

    private static func sheetDimmingQualifiedRuntimeClassName() -> String {
        let bundle = Bundle(for: SheetPresentationController.self)
        let module =
            (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)?
            .replacingOccurrences(of: " ", with: "_")
            ?? "SheetPresentationDemo"
        return "\(module).SheetDimmingView"
    }

    private func centerMapOnUserOrDefault(animated: Bool) {
        programmaticRegionChangeDepth += 1
        if let coord = mapView.userLocation.location?.coordinate {
            let region = MKCoordinateRegion(center: coord, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: animated)
        } else {
            let shanghai = CLLocationCoordinate2D(latitude: 31.23, longitude: 121.47)
            let region = MKCoordinateRegion(center: shanghai, latitudinalMeters: 2000, longitudinalMeters: 2000)
            mapView.setRegion(region, animated: animated)
        }
    }
}

// MARK: - MKMapViewDelegate

extension MapDemoEntryViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard programmaticRegionChangeDepth == 0, presentedViewController != nil else { return }
        // 检查内部 scroll 子视图是否有活跃手势，排除屏幕旋转等非用户触发的 region 变化
        let hasActiveGesture = mapView.subviews.first?.gestureRecognizers?.contains {
            $0.state == .began || $0.state == .changed
        } ?? false
        guard hasActiveGesture else { return }
        (presentedViewController as? MapSheetDemoViewController)?.userMoveMapView()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if programmaticRegionChangeDepth > 0 {
            programmaticRegionChangeDepth -= 1
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension MapDemoEntryViewController: CLLocationManagerDelegate {}

// MARK: - 系统 touch 穿透

private extension UIView {

    /// `ignoreDirectTouchEvents` 为 UIKit 内部属性；通过 KVC 写入，仅在 `responds(to:)` 为真时生效。
    func applyIgnoreDirectTouchEventsIfSupported(_ ignore: Bool) {
        let key = "ignoreDirectTouchEvents"
        guard responds(to: NSSelectorFromString(key)) else { return }
        setValue(ignore, forKey: key)
    }
}
