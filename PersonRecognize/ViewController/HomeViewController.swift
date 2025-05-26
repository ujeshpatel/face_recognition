//
//  HomeViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 09/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
// AVFoundation, RealmSwift are no longer directly used here
import ProgressHUD
import RxSwift
import RxCocoa

// KDTree is not used here anymore

class HomeViewController: UIViewController {
    
    @IBOutlet weak var img: UIImageView!
    @IBOutlet weak var vectorsLabel: UILabel!
    
    private var viewModel: HomeViewModel!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = HomeViewModel()
        bindView() // Set up bindings before loading data that might emit events
        viewModel.loadData()
        
        // Removed: Direct NetworkChecker check and showDialog call.
        // This is now handled by the ViewModel's statusMessage relay.
    }
    
    private func bindView() {
        // Vectors Label
        viewModel.vectorsLabelText
            .observe(on: MainScheduler.instance)
            .bind(to: vectorsLabel.rx.text)
            .disposed(by: disposeBag)

        // Display Image
        viewModel.displayImage
            .observe(on: MainScheduler.instance)
            .bind(to: img.rx.image)
            .disposed(by: disposeBag)

        // Loading State
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { isLoading in
                if isLoading {
                    ProgressHUD.animate("Processing...") // ViewModel can provide more specific messages if needed
                } else {
                    ProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)

        // Status Messages
        viewModel.statusMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                self?.showDialog(message: message) // Assuming showDialog is an extension or helper method
            })
            .disposed(by: disposeBag)

        // Navigation Events
        viewModel.navigationEvent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] target in
                let segueIdentifier: String
                switch target {
                case .startPredict:
                    segueIdentifier = "startPredict"
                case .openPredictImage:
                    segueIdentifier = "openPredictImage"
                case .openAddUser:
                    segueIdentifier = "openAddUser"
                case .viewFace:
                    segueIdentifier = "viewFace"
                case .viewLog:
                    segueIdentifier = "viewLog"
                }
                self?.performSegue(withIdentifier: segueIdentifier, sender: nil)
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        viewModel.handleViewWillAppear()
        // Removed: Direct update of img.image (now handled by displayImage relay)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.handleViewDidAppear()
        // Removed: Direct call to fnet.clean() and commented out loadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        viewModel.handleViewWillDisappear()
        // Removed: Direct call to fnet.load()
    }
    
    @IBAction func tapStart(_ sender: UIButton) {
        viewModel.navigationButtonTapped(target: .startPredict)
    }
    
    @IBAction func tapPredictImage(_ sender: UIButton) {
        viewModel.navigationButtonTapped(target: .openPredictImage)
    }
    
    @IBAction func tapAddUser(_ sender: UIButton) {
        viewModel.navigationButtonTapped(target: .openAddUser)
    }
    
    @IBAction func tapViewData(_ sender: UIButton) {
        viewModel.navigationButtonTapped(target: .viewFace)
    }
    
    @IBAction func tapViewLog(_ sender: UIButton) {
        viewModel.navigationButtonTapped(target: .viewLog)
    }
    
    @IBAction func tapSyncData(_ sender: UIButton) {
        viewModel.syncDataTriggered()
        // Removed: Direct NetworkChecker check, showDialog, and ProgressHUD.dismiss()
    }
    
    // Removed loadData() method entirely.
}

// Assuming UIViewController+ShowDialog.swift or similar provides this:
// extension UIViewController {
//    func showDialog(message: String) {
//        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//        self.present(alert, animated: true, completion: nil)
//    }
// }
```
