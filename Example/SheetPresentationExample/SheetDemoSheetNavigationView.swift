//
//  SheetDemoSheetNavigationView.swift
//  SheetPresentationExample
//
//  Sheet 内 Demo 顶栏：标题 + 可选副标题 + 右侧关闭；置于 grabber 下方（由外层 top = safeArea + grabberPad）。
//  高度由子视图与约束撑开。
//

import UIKit

extension UIViewController {
    /// 手柄开启时与 grabber 占位一致，顶栏应从此偏移之下开始布局。
    var sheetDemoGrabberLayoutPadding: CGFloat {
        return 0
    }
}

final class SheetDemoSheetNavigationView: UIView {

    private enum Layout {
        static let contentTop: CGFloat = 20
        static let contentBottom: CGFloat = 20
    }

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let subtitleLabel: UILabel?

    /// 关闭时由外层 VC 在 block 里 `dismiss` 等。
    var onClose: (() -> Void)?

    init(title: String, subtitle: String? = nil, onClose: @escaping () -> Void) {
        self.onClose = onClose

        if let subtitleText = subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !subtitleText.isEmpty {
            let sl = UILabel()
            sl.translatesAutoresizingMaskIntoConstraints = false
            sl.text = subtitleText
            sl.font = .preferredFont(forTextStyle: .footnote)
            sl.textColor = .secondaryLabel
            sl.numberOfLines = 0
            sl.textAlignment = .center
            sl.setContentCompressionResistancePriority(.required, for: .vertical)
            self.subtitleLabel = sl
        } else {
            self.subtitleLabel = nil
        }

        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = .systemBackground

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.accessibilityLabel = "关闭"
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addAction(UIAction { [weak self] _ in
            self?.onClose?()
        }, for: .touchUpInside)

        addSubview(titleLabel)
        addSubview(closeButton)
        if let sl = subtitleLabel {
            addSubview(sl)
        }

        let centerTitleX = titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor)
        centerTitleX.priority = .defaultHigh

        var constraints: [NSLayoutConstraint] = [
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Layout.contentTop),
            centerTitleX,
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: closeButton.leadingAnchor, constant: -8),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32)
        ]

        if let sl = subtitleLabel {
            constraints += [
                sl.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
                sl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                sl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                bottomAnchor.constraint(equalTo: sl.bottomAnchor, constant: Layout.contentBottom)
            ]
        } else {
            constraints += [
                bottomAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.contentBottom)
            ]
        }

        NSLayoutConstraint.activate(constraints)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}
