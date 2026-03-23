import UIKit

/// 模拟 App Store 风格的详情页：简介、新功能区域为固定高度内层 UITextView，
final class NestedVerticalScrollDemoViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }

    private func setupUI() {
        let grabberPad = sheetDemoGrabberLayoutPadding
        let sheetNav = SheetDemoSheetNavigationView(title: "App Detail", onClose: { [weak self] in
            self?.dismiss(animated: true)
        })

        let outerScroll = UIScrollView()
        outerScroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeAppHeader())
        stack.addArrangedSubview(makeGroupDivider())
        stack.addArrangedSubview(makeSectionTitle("简介"))
        stack.addArrangedSubview(makeTextArea(descriptionText, height: 160))
        stack.addArrangedSubview(makeGroupDivider())
        stack.addArrangedSubview(makeSectionTitle("新功能"))
        stack.addArrangedSubview(makeTextArea(whatsNewText, height: 120))
        stack.addArrangedSubview(makeGroupDivider())
        stack.addArrangedSubview(makeSectionTitle("评分及评论"))
        let reviews = [
            ("张三", "非常好用，体验流畅"),
            ("李四", "UI 设计很精美，推荐"),
            ("王五", "功能强大，值得下载"),
            ("赵六", "无障碍支持做得很好"),
            ("钱七", "每次更新都有惊喜"),
        ]
        for (name, body) in reviews {
            stack.addArrangedSubview(makeReviewRow(name: name, body: body))
        }
        let bottomPad = UIView()
        bottomPad.heightAnchor.constraint(equalToConstant: 20).isActive = true
        stack.addArrangedSubview(bottomPad)

        outerScroll.addSubview(stack)
        view.addSubview(sheetNav)
        view.addSubview(outerScroll)

        NSLayoutConstraint.activate([
            sheetNav.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: grabberPad),
            sheetNav.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetNav.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            outerScroll.topAnchor.constraint(equalTo: sheetNav.bottomAnchor),
            outerScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerScroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: outerScroll.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Subview builders

    private func makeAppHeader() -> UIView {
        let container = UIView()
        container.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let icon = UIView()
        icon.backgroundColor = .systemBlue
        icon.layer.cornerRadius = 16
        icon.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.text = "示例 App"
        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "嵌套垂直滚动 · iOS 17.4+"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(nameLabel)
        container.addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),

            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 14),
            nameLabel.topAnchor.constraint(equalTo: icon.topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
        ])
        return container
    }

    private func makeSectionTitle(_ title: String) -> UIView {
        let header = UIView()
        header.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeTextArea(_ text: String, height: CGFloat) -> UITextView {
        let tv = UITextView()
        tv.text = text
        tv.font = .systemFont(ofSize: 15)
        tv.textColor = .secondaryLabel
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 0, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.heightAnchor.constraint(equalToConstant: height).isActive = true
        return tv
    }

    private func makeReviewRow(name: String, body: String) -> UIView {
        let container = UIView()
        container.heightAnchor.constraint(equalToConstant: 76).isActive = true

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let starsLabel = UILabel()
        starsLabel.text = "★★★★★"
        starsLabel.font = .systemFont(ofSize: 12)
        starsLabel.textColor = .systemOrange
        starsLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text = body
        bodyLabel.font = .systemFont(ofSize: 14)
        bodyLabel.textColor = .secondaryLabel
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(nameLabel)
        container.addSubview(starsLabel)
        container.addSubview(bodyLabel)
        container.addSubview(separator)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            starsLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            starsLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            bodyLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: starsLabel.bottomAnchor, constant: 3),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])
        return container
    }

    private func makeGroupDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .systemGroupedBackground
        divider.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return divider
    }

    // MARK: - Content

    private var descriptionText: String {
        """
        这是一个模拟 App Store 风格详情页的示例，用于演示嵌套垂直滚动场景。「简介」\
        和「新功能」区域均为固定高度的内层 UITextView，拥有独立的滚动区域。

        当你在内层 TextView 中向上滑动到内容底部后，继续上划，外层 ScrollView 会\
        接管手势，页面继续向上滚动，露出下方的「评论」区域。反之，在内层顶部向下\
        滑动，也会先触发 Sheet 收起，而不是继续滚动内层。

        这种模式广泛应用于电商详情页、内容阅读类 App 以及 App Store 本身。固定高度\
        的内嵌滚动区域既限制了展开区域的占比，又保持了完整的阅读体验。

        继续向下可查看「新功能」和「评论」区域。这段文字足够长，确保内层 TextView \
        能够独立滚动，你可以先把「简介」区域滚到底，再观察外层页面是否继续滚动。
        """
    }

    private var whatsNewText: String {
        """
        • 修复了若干已知问题，包括特定设备上的崩溃和布局错乱
        • 整体性能大幅提升，冷启动速度缩短约 40%
        • 新增完整深色模式支持，所有页面均已适配
        • 优化内存管理，长时间使用不再出现卡顿
        • 完善无障碍（Accessibility）功能，支持 VoiceOver 全流程
        • 新增 iPad 分屏模式适配
        • 改进网络请求重试逻辑，弱网环境体验更佳
        • 全面适配最新系统版本，支持动态字体缩放
        """
    }
}
