import MapKit
import UIKit

/// 地图 Sheet：毛玻璃底、搜索栏、地点列表；搜索聚焦时切长档，地图被用户拖动时收短档。
final class MapSheetDemoViewController: UIViewController {

    enum DetentID {
        static let short = SheetPresentationController.Detent.Identifier("map.short")
        static let medium = SheetPresentationController.Detent.Identifier("map.medium")
        static let long = SheetPresentationController.Detent.Identifier("map.long")
    }

    private let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    private let searchBar = UISearchBar(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .plain)

    /// 列表展示用随机地名，viewDidLoad 生成一次，避免 cell 复用时标题闪烁变化。
    private var mapDemoPlaces: [(title: String, subtitle: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        effectView.translatesAutoresizingMaskIntoConstraints = false
        effectView.alpha = 0.92

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.placeholder = "搜索地点或地址"
        searchBar.backgroundImage = UIImage()
        searchBar.setSearchFieldBackgroundImage(UIImage(), for: .normal)
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        configureSearchTextFieldCapsuleBase()

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.showsVerticalScrollIndicator = false
        tableView.register(MapLocationTableViewCell.self, forCellReuseIdentifier: MapLocationTableViewCell.reuseId)

        view.addSubview(effectView)
        view.addSubview(searchBar)
        view.addSubview(tableView)

        let grabberPad = sheetDemoGrabberLayoutPadding
        NSLayoutConstraint.activate([
            effectView.topAnchor.constraint(equalTo: view.topAnchor),
            effectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            effectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            effectView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad + 10),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 7),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -7),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        cs.sheetPresentationController.delegate = self

        mapDemoPlaces = Self.makeMapDemoPlaces(count: 20)
        updateBlurForCurrentTraitCollection()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let tf = searchBar.searchTextField
        let h = tf.bounds.height
        guard h > 0 else { return }
        // roundedRect 由系统子视图画底，改 layer 圆角常不生效；用 none + 自填色 + masksToBounds 才能真胶囊。
        let r = h / 2
        if tf.layer.cornerRadius != r {
            tf.layer.cornerRadius = r
        }
    }

    /// 胶囊底：必须 `borderStyle == .none` 且 `masksToBounds`，否则圆角只作用在 layer 上、肉眼看不到系统画的方底。
    private func configureSearchTextFieldCapsuleBase() {
        let tf = searchBar.searchTextField
        tf.borderStyle = .none
        tf.backgroundColor = .tertiarySystemFill
        tf.layer.masksToBounds = true
        tf.layer.cornerCurve = .continuous
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateBlurForCurrentTraitCollection()
    }

    private func updateBlurForCurrentTraitCollection() {
        let style: UIBlurEffect.Style =
            traitCollection.userInterfaceStyle == .dark ? .dark : .extraLight
        effectView.effect = UIBlurEffect(style: style)
    }

    /// 由地图页在用户拖动地图时调用，将 Sheet 收回到短档。
    func userMoveMapView() {
        let sheet = cs.sheetPresentationController
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = DetentID.short
        }
    }

    private func transitionToLongDetent() {
        let sheet = cs.sheetPresentationController
        sheet.animateChanges {
            sheet.selectedDetentIdentifier = DetentID.long
        }
    }

    static func makeMapDetents() -> [SheetPresentationController.Detent] {
        [
            .custom(identifier: DetentID.long) { ctx in Self.resolveLongDetentHeight(ctx) },
            .custom(identifier: DetentID.medium) { ctx in min(380, ctx.maximumDetentValue * 0.5) },
            .custom(identifier: DetentID.short) { ctx in
                let base: CGFloat = SheetDemoSettingsStore.shared.prefersFloatingStyle ? 76 : 160
                return min(base, ctx.maximumDetentValue * 0.25)
            }
        ]
    }

    /// 长档高度：屏高 − 主窗口 safe area 顶 − 60，并钳制到容器可用高度。
    private static func resolveLongDetentHeight(
        _ context: any SheetPresentationControllerDetentResolutionContext
    ) -> CGFloat {
        let screenH = UIScreen.main.bounds.height
        let topSafe: CGFloat
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            topSafe = window.safeAreaInsets.top
        } else {
            topSafe = context.containerSafeAreaTopInset
        }
        let target = screenH - topSafe - 60
        return min(max(target, 120), context.maximumDetentValue)
    }

    private static func makeMapDemoPlaces(count: Int) -> [(title: String, subtitle: String)] {
        let communityBrands = [
            "瑞虹", "大华", "万科", "保利", "融创", "绿地", "华润", "龙湖", "中海", "招商",
            "金地", "碧桂园", "绿城", "金茂", "建发", "仁恒", "新湖", "旭辉", "世茂", "阳光"
        ]
        let communitySuffixes = [
            "新城", "华庭", "雅苑", "壹号院", "悦府", "天玺", "紫郡", "御景", "公馆", "里",
            "府", "苑", "湾", "城", "花园", "豪庭", "名邸", "尚郡", "璟庭", "云著"
        ]
        let curatedCommunities = [
            "滨江凯旋门", "翠湖天地", "汤臣一品", "古北壹号", "星河湾", "仁恒滨江园",
            "新江湾城首府", "西郊庄园", "檀宫", "九间堂"
        ]
        let subwayStations = [
            "人民广场", "南京东路", "陆家嘴", "世纪大道", "徐家汇", "静安寺", "新天地",
            "虹桥火车站", "龙阳路", "花木路", "五角场", "中山公园", "莘庄", "张江高科",
            "金科路", "迪士尼", "娄山关路", "打浦桥", "老西门", "曲阜路"
        ]
        let subwayLines = ["1号线", "2号线", "4号线", "7号线", "9号线", "10号线", "11号线", "12号线", "13号线"]
        let districts = [
            "上海市 · 浦东新区", "上海市 · 静安区", "上海市 · 黄浦区", "上海市 · 徐汇区",
            "上海市 · 长宁区", "上海市 · 虹口区", "上海市 · 杨浦区", "上海市 · 闵行区"
        ]
        let extras = [
            "步行约 6 分钟", "步行约 10 分钟", "距此 1.1 km", "距此 2.3 km", "地铁直达",
            "换乘 1 次", "近商圈", "近公园"
        ]

        var out: [(title: String, subtitle: String)] = []
        out.reserveCapacity(count)
        for _ in 0..<count {
            let isSubway = Bool.random()
            let title: String
            if isSubway {
                title = "\(subwayStations.randomElement()!)站"
            } else if Bool.random() && Bool.random() {
                title = curatedCommunities.randomElement()!
            } else {
                var name = "\(communityBrands.randomElement()!)\(communitySuffixes.randomElement()!)"
                if Bool.random() {
                    name += " \(Int.random(in: 1...5))期"
                } else if Bool.random() {
                    name += "\(Int.random(in: 1...28))弄"
                }
                title = name
            }

            let subtitle: String
            if isSubway {
                subtitle = "地铁 \(subwayLines.randomElement()!) · \(extras.randomElement()!)"
            } else {
                subtitle = "\(districts.randomElement()!) · \(extras.randomElement()!)"
            }
            out.append((title, subtitle))
        }
        return out
    }

    deinit {
        print("[SheetDemo] MapSheetDemoViewController deinit")
    }
}

// MARK: - SheetPresentationControllerDelegate

extension MapSheetDemoViewController: SheetPresentationControllerDelegate {

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    ) {
        // 切到 long 往往是为了搜索框聚焦输入，不在此收键盘；其它档位（拖动手柄、地图联动收短等）收起键盘。
        if sheetPresentationController.selectedDetentIdentifier == DetentID.long {
            return
        }
        view.endEditing(true)
    }
}

// MARK: - UISearchBarDelegate

extension MapSheetDemoViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        transitionToLongDetent()
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MapSheetDemoViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { mapDemoPlaces.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MapLocationTableViewCell.reuseId, for: indexPath)
            as! MapLocationTableViewCell
        let place = mapDemoPlaces[indexPath.row]
        cell.textLabel?.text = place.title
        cell.detailTextLabel?.text = place.subtitle
        cell.imageView?.image = UIImage(named: "landmark")
        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 80 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

// MARK: - Cell

private final class MapLocationTableViewCell: UITableViewCell {
    static let reuseId = "mapLocationCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        textLabel?.font = .boldSystemFont(ofSize: 18)
        detailTextLabel?.font = .systemFont(ofSize: 16)
        textLabel?.textColor = .label
        detailTextLabel?.textColor = .secondaryLabel
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
