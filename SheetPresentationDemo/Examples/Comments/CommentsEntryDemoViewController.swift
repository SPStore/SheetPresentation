import UIKit

final class CommentsEntryDemoViewController: UIViewController {

    static let commentsDetentIdentifier = SheetPresentationController.Detent.Identifier("comments.expanded")

    private let backButton = UIButton(type: .system)
    private let enterButton = UIButton(type: .system)
    private let previewImageView = UIImageView()
    /// transform变化完全由previewFrameInWindow决定
    /// 当前previewFrameInWindow是previewImageView本身在window中的frame
    /// 有些图片肯能包含其它内容，比如一张高度为全屏的图片，但是只有中间一部分是主体，其余部分均为背景，那么previewFrameInWindow可以改为这个主体在window中的frame。这样可以保证，sheet弹出之后，主体部分刚好在顶部剩余空间展示
    private var previewFrameInWindow: CGRect = .zero
    private var previousPresentedFrame: CGRect = .zero
    /// 与 `applyPreviewTransform` 内分支一致，避免 detent 切换当帧 y 未变不重算。
    private var lastPreviewTransformDetent: SheetPresentationController.Detent.Identifier?
    private var isCommentsSheetPresented = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Comments Enter"
        view.backgroundColor = .black
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupUI() {
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.setImage(UIImage(named: "nav_back"), for: .normal)
        backButton.tintColor = .white
        backButton.addTarget(self, action: #selector(backAction), for: .touchUpInside)

        let previewImage = UIImage(named: "worldcup_messi") ?? UIImage(systemName: "photo.fill")
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.image = previewImage
        previewImageView.tintColor = .red
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.clipsToBounds = true

        enterButton.translatesAutoresizingMaskIntoConstraints = false
        var enterConfig = UIButton.Configuration.plain()
        enterConfig.title = "弹出评论"
        enterConfig.baseForegroundColor = .white
        enterConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        enterConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16)
            return outgoing
        }
        enterButton.configuration = enterConfig
        enterButton.layer.borderWidth = 1
        enterButton.layer.borderColor = UIColor.white.cgColor
        enterButton.layer.cornerRadius = 4
        enterButton.clipsToBounds = true
        enterButton.addTarget(self, action: #selector(openComments), for: .touchUpInside)

        view.addSubview(backButton)
        view.addSubview(previewImageView)
        view.addSubview(enterButton)

        let imageSize = sizeAdapt(containerSize: view.bounds.size, originSize: previewImage?.size ?? CGSize(width: 300, height: 500))
        let imageHeight = min(imageSize.height, view.bounds.height * 0.58)
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 48),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 0),
            backButton.widthAnchor.constraint(equalToConstant: 60),
            backButton.heightAnchor.constraint(equalToConstant: 30),

            previewImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            previewImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            previewImageView.heightAnchor.constraint(equalToConstant: imageHeight),

            enterButton.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 30),
            enterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !isCommentsSheetPresented {
            previewFrameInWindow = previewImageView.convert(previewImageView.bounds, to: nil)
        }
    }

    @objc private func backAction() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func openComments() {
        previousPresentedFrame = .zero
        view.layoutIfNeeded()
        previewFrameInWindow = previewImageView.convert(previewImageView.bounds, to: nil)

        isCommentsSheetPresented = true

        let vc = CommentsSheetDemoViewController()
        vc.onRequestExpandDetents = { [weak self] sheet in
            self?.expandCommentsSheetDetents(sheet: sheet)
        }
        vc.onRequestRestoreDetents = { [weak self] sheet in
            self?.restoreCommentsSheetDetents(sheet: sheet)
        }
        vc.onRequestDismissed = { [weak self] in
            self?.handleCommentsSheetDismissed()
        }
        let sheet = vc.cs.sheetPresentationController
        sheet.delegate = self
        sheet.detents = [
            .custom(identifier: Self.commentsDetentIdentifier) { ctx in
                ctx.maximumDetentValue * 0.73
            }
        ]
        sheet.dimmingBackgroundAlpha = 0
        sheet.isEdgePanGestureEnabled = true
        sheet.edgePanTriggerDistance = view.bounds.width

        cs.presentSheetViewController(vc, animated: true)
    }

    /// 展开为全屏大档（供评论 Sheet 内按钮调用）。
    func expandCommentsSheetDetents(sheet: SheetPresentationController) {
        sheet.animateChanges {
            sheet.detents = [.large()]
            sheet.selectedDetentIdentifier = .large
        }
    }

    /// 从全屏大档恢复为评论区比例档（供评论 Sheet 内按钮调用）。
    func restoreCommentsSheetDetents(sheet: SheetPresentationController) {
        sheet.animateChanges {
            sheet.detents = [
                .custom(identifier: Self.commentsDetentIdentifier) { ctx in
                    ctx.maximumDetentValue * 0.73
                }
            ]
            sheet.selectedDetentIdentifier = Self.commentsDetentIdentifier
        }
    }

    private func sizeAdapt(containerSize: CGSize, originSize: CGSize) -> CGSize {
        var finalSize = originSize
        if finalSize.height / finalSize.width < containerSize.height / containerSize.width {
            finalSize.width = containerSize.width
            finalSize.height = originSize.height / (originSize.width / finalSize.width)
        } else {
            finalSize.height = containerSize.height
            finalSize.width = originSize.width / (originSize.height / finalSize.height)
        }
        return finalSize
    }

    private func applyPreviewTransform(
        newFrame: CGRect,
        oldFrame: CGRect,
        sheet: SheetPresentationController
    ) {
        guard isCommentsSheetPresented else { return }
        if oldFrame.origin.y == 0 {
            return
        }

        let detentId = sheet.selectedDetentIdentifier
        if newFrame.origin.y == oldFrame.origin.y, detentId == lastPreviewTransformDetent {
            return
        }

        let screenH = UIScreen.main.bounds.height
        let topOffset = view.window?.safeAreaInsets.top ?? 0
        let y = newFrame.origin.y

        // 第二段（大档）：scale = (y - topOffset)/(screenH - topOffset)；平移与第一段同一形式 T(0,-tr).scaledBy(s,s)，
        // tr 为一次函数且在 y == screenH 时为 0，在 y == topOffset 时 tr == midY - topOffset（窗口坐标下与顶安全区的相对关系，与第一段 minY 结构对应）。
        if detentId == SheetPresentationController.Detent.Identifier.large {
            let initialY = topOffset
            let finalY = screenH
            guard previewFrameInWindow.height > 0, finalY > initialY else { return }

            let span = finalY - initialY
            var scale = (y - initialY) / span
            scale = min(max(scale, 0), 1)

            let minTranslate = previewFrameInWindow.midY - topOffset
            let tk = (0 - minTranslate) / span
            let translate = tk * (y - initialY) + minTranslate
            let translationTransform = CGAffineTransform(translationX: 0, y: -translate)
            previewImageView.transform = translationTransform.scaledBy(x: scale, y: scale)
            lastPreviewTransformDetent = detentId
            return
        }

        // 第一段（评论区 detent）：保持原样，勿改公式。
        let longStateHeight = screenH * 0.73
        let topSpacing = screenH - longStateHeight
        let initialY = topSpacing
        let finalY = screenH

        guard previewFrameInWindow.height > 0, finalY > initialY else { return }

        let safeHeight = previewFrameInWindow.height
        
        let minScale = (topSpacing - topOffset) / safeHeight
        let sk = (1 - minScale) / (finalY - initialY)
        var scale = sk * (y - initialY) + minScale
        scale = min(max(scale, minScale), 1)

        let minY = previewFrameInWindow.origin.y - topOffset
            + (safeHeight - topSpacing + topOffset) * 0.5
        let tk = (0 - minY) / (finalY - initialY)
        let translate = tk * (y - initialY) + minY
        let translationTransform = CGAffineTransform(translationX: 0, y: -translate)
        previewImageView.transform = translationTransform.scaledBy(x: scale, y: scale)
        lastPreviewTransformDetent = detentId
    }

    /// 统一收尾：手势 dismiss 与代码 dismiss 都调用这里，避免依赖单一 delegate 回调语义。
    func handleCommentsSheetDismissed() {
        backButton.alpha = 1
        enterButton.alpha = 1
        isCommentsSheetPresented = false
        previewImageView.transform = .identity
        previousPresentedFrame = .zero
        lastPreviewTransformDetent = nil
        view.setNeedsLayout()
    }
}

extension CommentsEntryDemoViewController: SheetPresentationControllerDelegate {

    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    ) {
        (sheetPresentationController.presentedViewController as? CommentsSheetDemoViewController)?
            .syncExpandDetentButton(with: sheetPresentationController)
    }

    func sheetPresentationController(
        _ sheetPresentationController: SheetPresentationController,
        didUpdatePresentedFrame frame: CGRect
    ) {
        let oldFrame = previousPresentedFrame
        previousPresentedFrame = frame
        applyPreviewTransform(newFrame: frame, oldFrame: oldFrame, sheet: sheetPresentationController)
    }

    func presentationController(
        _ presentationController: UIPresentationController,
        willPresentWithAdaptiveStyle style: UIModalPresentationStyle,
        transitionCoordinator: UIViewControllerTransitionCoordinator?
    ) {
        backButton.alpha = 0
        enterButton.alpha = 0
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handleCommentsSheetDismissed()
    }
}
