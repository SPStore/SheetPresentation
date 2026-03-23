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
        outerCollectionView.register(CardItemCell.self, forCellWithReuseIdentifier: CardItemCell.reuseID)
        outerCollectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.reuseID
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: CardItemCell.reuseID, for: indexPath) as! CardItemCell
        let count = sections[indexPath.section].items.count
        let position: CardItemCell.Position
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
            withReuseIdentifier: SectionHeaderView.reuseID,
            for: indexPath
        ) as! SectionHeaderView
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

// MARK: - CardItemCell

private final class CardItemCell: UICollectionViewCell {

    static let reuseID = "CardItemCell"

    enum Position { case first, middle, last, single }

    private let label = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .secondarySystemGroupedBackground
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false

        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(label)
        contentView.addSubview(separator)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func configure(title: String, position: Position) {
        label.text = title
        switch position {
        case .single:
            contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner,
                                               .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            separator.isHidden = true
        case .first:
            contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            separator.isHidden = false
        case .middle:
            contentView.layer.maskedCorners = []
            separator.isHidden = false
        case .last:
            contentView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            separator.isHidden = true
        }
    }
}

// MARK: - SectionHeaderView

private final class SectionHeaderView: UICollectionReusableView {

    static let reuseID = "SectionHeaderView"

    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 32),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func configure(title: String) {
        label.text = title
    }
}

// MARK: - HorizontalCarouselCell

private final class HorizontalCarouselCell: UICollectionViewCell {

    static let reuseID = "HorizontalCarouselCell"

    private static let colors: [UIColor] = [
        .systemRed, .systemOrange, .systemYellow, .systemGreen,
        .systemTeal, .systemBlue, .systemIndigo, .systemPurple,
        .systemPink, .systemBrown, .systemCyan, .systemMint,
    ]

    private let innerCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 64, height: 64)
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return UICollectionView(frame: .zero, collectionViewLayout: layout)
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        innerCollectionView.translatesAutoresizingMaskIntoConstraints = false
        innerCollectionView.backgroundColor = .clear
        innerCollectionView.showsHorizontalScrollIndicator = false
        innerCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "inner")
        innerCollectionView.dataSource = self
        contentView.addSubview(innerCollectionView)
        NSLayoutConstraint.activate([
            innerCollectionView.topAnchor.constraint(equalTo: contentView.topAnchor),
            innerCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            innerCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            innerCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

extension HorizontalCarouselCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 20 }
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "inner", for: indexPath)
        cell.backgroundColor = Self.colors[indexPath.item % Self.colors.count].withAlphaComponent(0.85)
        cell.layer.cornerRadius = 12
        return cell
    }
}
