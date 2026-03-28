import UIKit

final class OrthogonalScrollDemoViewController: UIViewController {

    private struct SectionData {
        let title: String
        let items: [String]
    }

    private let sections: [SectionData] = [
        SectionData(title: "Featured", items: ["精选推荐 1", "精选推荐 2", "精选推荐 3", "精选推荐 4"]),
        SectionData(title: "快捷功能", items: Array(0..<14).map { "功能 \($0 + 1)" }),
        SectionData(title: "功能一览", items: ["实时消息推送", "多设备同步", "离线缓存", "快捷操作", "智能搜索"]),
        SectionData(title: "设置", items: ["外观与主题", "通知偏好", "隐私与安全", "存储与流量"]),
    ]

    private static let featureColors: [UIColor] = [
        .systemBlue, .systemPurple, .systemOrange, .systemGreen,
    ]

    private static let iconColors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple,
        .systemPink, .systemBrown, .systemCyan, .systemMint,
    ]

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "Orthogonal Scroll", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(FeatureCardCell.self, forCellWithReuseIdentifier: FeatureCardCell.reuseID)
        collectionView.register(IconCell.self, forCellWithReuseIdentifier: IconCell.reuseID)
        collectionView.register(OrthogonalCardItemCell.self, forCellWithReuseIdentifier: OrthogonalCardItemCell.reuseID)
        collectionView.register(
            OrthogonalSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: OrthogonalSectionHeaderView.reuseID
        )
        collectionView.dataSource = self

        view.addSubview(sheetNav)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            collectionView.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            switch sectionIndex {
            case 0: return self?.makeFeaturedSection()
            case 1: return self?.makeIconRowSection()
            default: return self?.makeCardListSection()
            }
        }
    }

    /// 大卡片分页轮播（groupPagingCentered），两侧可见相邻卡片
    private func makeFeaturedSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.82), heightDimension: .absolute(160)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    /// 小图标连续横滑（continuous）
    private func makeIconRowSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(64), heightDimension: .absolute(64))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(64), heightDimension: .absolute(64)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    /// 普通垂直卡片列表
    private func makeCardListSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50))
        )
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(50)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16)
        section.boundarySupplementaryItems = [makeHeader()]
        return section
    }

    private func makeHeader() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(40)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}

// MARK: - UICollectionViewDataSource

extension OrthogonalScrollDemoViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { sections.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch indexPath.section {
        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FeatureCardCell.reuseID, for: indexPath) as! FeatureCardCell
            cell.configure(
                title: sections[0].items[indexPath.item],
                color: Self.featureColors[indexPath.item % Self.featureColors.count]
            )
            return cell
        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: IconCell.reuseID, for: indexPath) as! IconCell
            cell.configure(color: Self.iconColors[indexPath.item % Self.iconColors.count])
            return cell
        default:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OrthogonalCardItemCell.reuseID, for: indexPath) as! OrthogonalCardItemCell
            let count = sections[indexPath.section].items.count
            let position: OrthogonalCardItemCell.Position
            if count == 1 { position = .single }
            else if indexPath.item == 0 { position = .first }
            else if indexPath.item == count - 1 { position = .last }
            else { position = .middle }
            cell.configure(title: sections[indexPath.section].items[indexPath.item], position: position)
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind, withReuseIdentifier: OrthogonalSectionHeaderView.reuseID, for: indexPath
        ) as! OrthogonalSectionHeaderView
        header.configure(title: sections[indexPath.section].title)
        return header
    }
}
