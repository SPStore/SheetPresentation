import UIKit

final class NestedHorizontalScrollDemoViewController: UIViewController {

    private struct SectionData {
        let title: String
        let items: [String]
    }

    private let sections: [SectionData] = [
        SectionData(title: "", items: [""]),
        SectionData(title: "功能一览", items: ["实时消息推送", "多设备同步", "离线缓存", "快捷操作", "智能搜索"]),
        SectionData(title: "个性化设置", items: ["外观与主题", "通知偏好", "隐私与安全", "存储与流量"]),
        SectionData(title: "支持", items: ["帮助中心", "意见反馈", "关于应用"]),
    ]

    private let outerCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Nested Horizontal Scroll", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        outerCollectionView.translatesAutoresizingMaskIntoConstraints = false
        outerCollectionView.backgroundColor = .systemGroupedBackground
        outerCollectionView.register(HorizontalCarouselCell.self, forCellWithReuseIdentifier: HorizontalCarouselCell.reuseID)
        outerCollectionView.register(NestedCardItemCell.self, forCellWithReuseIdentifier: NestedCardItemCell.reuseID)
        outerCollectionView.register(
            NestedSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: NestedSectionHeaderView.reuseID
        )
        outerCollectionView.dataSource = self
        outerCollectionView.delegate = self

        view.addSubview(sheetNav)
        view.addSubview(outerCollectionView)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            outerCollectionView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            outerCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    deinit {
        print("[SheetDemo] NestedHorizontalScrollDemoViewController deinit")
    }
}

// MARK: - UICollectionViewDataSource

extension NestedHorizontalScrollDemoViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            return collectionView.dequeueReusableCell(withReuseIdentifier: HorizontalCarouselCell.reuseID, for: indexPath)
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NestedCardItemCell.reuseID, for: indexPath) as! NestedCardItemCell
        let count = sections[indexPath.section].items.count
        let position: NestedCardItemCell.Position
        if count == 1 { position = .single }
        else if indexPath.item == 0 { position = .first }
        else if indexPath.item == count - 1 { position = .last }
        else { position = .middle }
        cell.configure(title: sections[indexPath.section].items[indexPath.item], position: position)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: NestedSectionHeaderView.reuseID,
            for: indexPath
        ) as! NestedSectionHeaderView
        header.configure(title: sections[indexPath.section].title)
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension NestedHorizontalScrollDemoViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = indexPath.section == 0
            ? collectionView.bounds.width
            : collectionView.bounds.width - 32
        return CGSize(width: width, height: indexPath.section == 0 ? 106 : 50)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        section == 0 ? .zero : UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        section == 0 ? .zero : CGSize(width: collectionView.bounds.width, height: 40)
    }
}
