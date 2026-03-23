//
//  ViewController.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/30.
//

import UIKit

private enum DemoActionType {
    case present
    case push
}

private enum SheetProfile {
    /// 单档，高度由关联值传入（内部 `.custom(identifier: "pageSheetLike")`）。
    case pageSheetLike(customHeight: CGFloat)
    case twoDetents
    case threeDetents
}

private struct DemoItem {
    let title: String
    let detail: String
    let action: DemoActionType
    let profile: SheetProfile
    let makeTarget: () -> UIViewController
}

final class ViewController: UIViewController {

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = 56
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private lazy var demos: [DemoItem] = [
        DemoItem(title: "Nested ScrollView", detail: "内嵌横向列表 + 纵向列表", action: .present, profile: .pageSheetLike(customHeight: 600)) {
            NestedScrollViewSheetDemoViewController()
        },
        DemoItem(title: "Detents", detail: "2个档位", action: .present, profile: .twoDetents) {
            DetentsSheetDemoViewController()
        },
        DemoItem(title: "Map", detail: "真地图 + 地点搜索 Sheet", action: .push, profile: .threeDetents) {
            MapDemoEntryViewController()
        },
        DemoItem(title: "Double List", detail: "左右双列表", action: .present, profile: .twoDetents) {
            DoubleListSheetDemoViewController()
        },
        DemoItem(title: "Dynamic Height", detail: "高度自适应内容", action: .push, profile: .twoDetents) {
            DynamicHeightDemoViewController()
        },
        DemoItem(title: "Comments Enter", detail: "评论区交互入口", action: .push, profile: .twoDetents) {
            CommentsEntryDemoViewController()
        },
        DemoItem(title: "Web", detail: "网页容器", action: .present, profile: .twoDetents) {
            WebSheetDemoViewController()
        },
        DemoItem(title: "Page Sheet", detail: "单档高度 600pt", action: .present, profile: .pageSheetLike(customHeight: 600)) {
            PageSheetDemoViewController()
        },
        DemoItem(title: "RefreshData", detail: "下拉刷新", action: .present, profile: .pageSheetLike(customHeight: view.bounds.height - 62)) {
            RefreshSheetDemoViewController()
        },
        DemoItem(title: "Navigation", detail: "present 一个导航控制器", action: .present, profile: .twoDetents) {
            NavigationSheetDemoViewController.makeNavigationRoot()
        },
        DemoItem(title: "Keyboard", detail: "键盘弹起避让", action: .present, profile: .twoDetents) {
            KeyboardSheetDemoViewController()
        },
        DemoItem(title: "Custom Transition", detail: "自定义非交互式转场动画", action: .push, profile: .twoDetents) {
            CustomTransitionDemoViewController()
        },
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Swift Example"
        view.backgroundColor = .systemBackground
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func show(_ item: DemoItem) {
        let target = item.makeTarget()
        if item.action == .push {
            guard let nav = navigationController else { return }
            target.hidesBottomBarWhenPushed = true
            nav.pushViewController(target, animated: true)
            return
        }
        presentAsSheet(target, profile: item.profile)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        demos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "demo")
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: "demo")
        let item = demos[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.detail
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.selectionStyle = .none
        cell.accessoryType = (item.action == .push) ? .disclosureIndicator : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        show(demos[indexPath.row])
    }
}

private extension ViewController {
    func presentAsSheet(_ vc: UIViewController, profile: SheetProfile) {
        let controller = vc.cs.sheetPresentationController
        controller.delegate = self
        SheetDemoSettingsStore.shared.configureController(controller, for: vc)
        if vc is RefreshSheetDemoViewController {
            controller.allowsScrollViewToDriveSheet = false
        }

        switch profile {
        case .pageSheetLike(let customHeight):
            controller.detents = [
                .custom(identifier: .init("pageSheetLike")) { _ in customHeight }
            ]
        case .twoDetents:
            controller.detents = [.large(), .medium()]
        case .threeDetents:
            controller.detents = [
                .large(),
                .medium(),
                .custom(identifier: .init("map.small")) { _ in 220 }
            ]
            controller.selectedDetentIdentifier = .medium
        }
        cs.presentSheetViewController(vc, animated: true) {

        }
    }
}
extension ViewController: SheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    ) {
        print("Selected detent: \(sheetPresentationController.selectedDetentIdentifier?.rawValue ?? "nil")")
    }
}

