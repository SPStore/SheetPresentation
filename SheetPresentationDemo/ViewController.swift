//
//  ViewController.swift
//  SheetPresentationDemo
//
//  Created by 乐升平 on 2026/1/30.
//

import UIKit

class ViewController: UIViewController, UIGestureRecognizerDelegate {
    
    private let presentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Present Sheet", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var pan: UIPanGestureRecognizer?

    override func viewDidLoad() {
        super.viewDidLoad()
        
//        view.backgroundColor = .green
        setupUI()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapAction(_:)))
        tap.delegate = self
        view.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer()
        view.addGestureRecognizer(pan)
        self.pan = pan
    }
    
    @objc private func tapAction(_ gesture: UITapGestureRecognizer) {

    }
    
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        print("点击手势")

        self.pan?.addTarget(self, action: #selector(panAction(_:)))
        

        return true
    }
    
    
    @objc private func panAction(_ gesture: UIPanGestureRecognizer) {
        print("点击手势 -> 平移手势")

        
    }
    
    private func setupUI() {
        view.addSubview(presentButton)
        
        NSLayoutConstraint.activate([
            presentButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            presentButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        presentButton.addTarget(self, action: #selector(presentSheet), for: .touchUpInside)
    }
    

    @objc private func presentSheet() {
        let sheetVC = DemoSheetViewController()
        
        // 配置Sheet属性
        let sheetController = sheetVC.cs.sheetPresentationController
        sheetController.detents = [
            .medium(),
            .large(),
//            .custom(identifier: .init("small")) { context in
//                return 300
//            }
        ]
//        sheetController.selectedDetentIdentifier = .medium
        sheetController.prefersGrabberVisible = true
        sheetController.preferredCornerRadius = 13
        sheetController.dimmingBackgroundAlpha = 0.4
//        sheetController.prefersShadowVisible = true
        sheetController.delegate = self
//        sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
        sheetController.requiresScrollingFromEdgeToDriveSheet = true
//        sheetController.sheetDrivingMode = .none
        sheetController.allowScreenEdgeInteractive = true
        sheetController.maxAllowedDistanceToScreenEdgeForPanInteraction = 500
        
//        sheetController.allowsTapBackgroundToDismiss = false
//        sheetVC.isModalInPresentation = true
        
        cs.presentSheetViewController(sheetVC, animated: true)
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            sheetController.animateChanges {
//                sheetController.selectedDetentIdentifier = .large
//            }
//        }
    }
}

// MARK: - SheetPresentationControllerDelegate

extension ViewController: SheetPresentationControllerDelegate {
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: SheetPresentationController
    ) {
        print("Selected detent changed to: \(sheetPresentationController.selectedDetentIdentifier?.rawValue ?? "nil")")
    }
    
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        print("User attempted to dismiss, but isModalInPresentation is true")
    }
    
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
//        presentationController.presentedViewController.transitionCoordinator?.animate { context in
//            presentationController.presentingViewController.view.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
//        } completion: { context in
//            print("结束")
////            presentationController.presentingViewController.view.transform = .identity
//
//        }
    }
    
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        
    }
}

// MARK: - Demo Sheet Content

class DemoSheetViewController: UIViewController {
    
    private let tableView: SPTableView = {
        let table = SPTableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return table
    }()
    
    private let items = [
        "Item 1", "Item 2", "Item 3", "Item 4", "Item 5",
        "Item 6", "Item 7", "Item 8", "Item 9", "Item 10",
        "Item 11", "Item 12", "Item 13", "Item 14", "Item 15",
        "Item 16", "Item 17", "Item 18", "Item 19", "Item 20",
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .yellow
        setupUI()
    }
    
    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Sheet Demo"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let dismissButton = UIButton(type: .system)
//        dismissButton.frame = view.bounds
//        dismissButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dismissButton.setTitle("Dismiss", for: .normal)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.backgroundColor = .green
        dismissButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        
        view.addSubview(titleLabel)
        view.addSubview(dismissButton)
        view.addSubview(tableView)
        
        tableView.delegate = self
        tableView.dataSource = self
        

//
//        tableView.backgroundColor = UIColor.green
//
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            dismissButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
//            dismissButton.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            dismissButton.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            dismissButton.bottomAnchor.constraint(equalTo: view.bottomAnchor)

            tableView.topAnchor.constraint(equalTo: dismissButton.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func dismissSheet() {
//        dismiss(animated: true)
        
        if cs.sheetPresentationController.selectedDetentIdentifier == .large {
            dismiss(animated: true)
            return
        }
        cs.sheetPresentationController.detents = [
            .large(),
            .medium(),
//            .custom(identifier: .init("small")) { context in
//                return 200
//            }
        ]
        
        cs.sheetPresentationController.animateChanges {
            self.cs.sheetPresentationController.selectedDetentIdentifier = .large
        }
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//            self.cs.sheetPresentationController.detents = [
//                .medium(),
//            ]
//        }
        
    }
}

// MARK: - UITableViewDelegate & DataSource

extension DemoSheetViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 100
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = "第\(indexPath.row)行";
        cell.contentView.backgroundColor = .white
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        print("Selected: \(items[indexPath.row])")
    }
}
