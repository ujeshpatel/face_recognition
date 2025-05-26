//
//  AddUserViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 06/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
// Vision, MobileCoreServices, AVFoundation, FaceCropper are not directly used in this refactored VC logic
// MBProgressHUD is not used, replaced by ProgressHUD
import ProgressHUD
import SkyFloatingLabelTextField
import RxCocoa
import RxSwift

class UserData: UIViewController { // Removed UIImagePickerControllerDelegate & UINavigationControllerDelegate as they are not used here
    
    @IBOutlet weak var findName: SkyFloatingLabelTextField!
    @IBOutlet weak var tableView: UITableView!
    
    // ViewModel and DisposeBag
    private var viewModel: UserDataViewModel!
    let disposeBag = DisposeBag()
    
    // Property for segue
    var value: String = "" // Used in prepare(for:sender:)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = UserDataViewModel() // Initialize ViewModel
        
        // Configure TableView delegate (for didSelectRowAt, if not fully handled by Rx)
        // tableView.delegate = self // RxCocoa handles selection if .modelSelected or .itemSelected is used.
                                 // For custom didSelectRowAt logic calling ViewModel, this is fine.
        
        bindView() // Setup bindings
        viewModel.fetchUsers() // Fetch data
        
        // Remove old logic:
        // NetworkChecker, direct fb.loadUsers, ProgressHUD.animate("Loading users..."), userList processing
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.hideKeyboardWhenTappedAround() // Keep existing utility function
    }
    
    private func bindView() {
        // Bind search input to ViewModel's searchQuery
        findName.rx.text
            .orEmpty
            .bind(to: viewModel.searchQuery)
            .disposed(by: disposeBag)

        // Bind ViewModel's searchResult to TableView
        viewModel.searchResult
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: "cellID", cellType: UITableViewCell.self)) { row, data, cell in
                cell.textLabel?.text = "\(data.values.first!). \(data.keys.first!)"
            }
            .disposed(by: disposeBag)

        // Subscribe to loading state
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { isLoading in
                if isLoading {
                    ProgressHUD.animate("Processing...") // Generic message
                } else {
                    ProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)

        // Subscribe to status messages
        viewModel.statusMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { message in
                // Using ProgressHUD to show messages briefly. Could be a toast or custom label.
                // Important: ProgressHUD.show() can sometimes block UI if not dismissed.
                // Consider using a less intrusive way for status messages if they are frequent.
                ProgressHUD.show(message)
                // Auto-dismiss after a short period for non-error messages if appropriate
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    if !self.viewModel.isLoading.value { // Dismiss only if not in a loading state
                         ProgressHUD.dismiss()
                    }
                }
            })
            .disposed(by: disposeBag)

        // Subscribe to dialog events
        viewModel.dialogEvent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .showAlert(let title, let message):
                    self.showInfoDialog(title: title, message: message)
                case .showOptionsForUser(let userName, let title):
                    self.presentUserOptionsAlert(userName: userName, title: title)
                }
            })
            .disposed(by: disposeBag)

        // Subscribe to navigation events
        viewModel.navigationEvent
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .toViewFace(let name):
                    self.value = name // Set value for prepare(for:sender:)
                    self.performSegue(withIdentifier: "viewFaceData", sender: nil)
                }
            })
            .disposed(by: disposeBag)
        
        // Handle item selection through Rx if preferred, or use delegate method
        tableView.rx.itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                self?.tableView.deselectRow(at: indexPath, animated: true)
                self?.viewModel.handleUserSelection(at: indexPath.row)
            })
            .disposed(by: disposeBag)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "viewFaceData" {
            let vc = segue.destination as! ViewFaceViewController
            vc.name = self.value // self.value is set by navigationEvent subscription
        }
    }
    
    @IBAction func tapGenerateAll(_ sender: UIBarButtonItem) {
        viewModel.generateAllVectors()
    }

    // Helper function to present user options
    private func presentUserOptionsAlert(userName: String, title: String) {
        let alert = UIAlertController(title: title, message: "User: \(userName)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Generate Vector", style: .default, handler: { [weak self] _ in
            self?.viewModel.generateVector(for: userName)
        }))
        alert.addAction(UIAlertAction(title: "View Face", style: .default, handler: { [weak self] _ in
            self?.viewModel.navigateToViewFace(userName: userName)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Basic dialog helper (can be an extension)
    func showInfoDialog(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

// Removed old UITableViewDelegate extension, as didSelectRowAt is handled by Rx or will be removed if Rx fully covers it.
// If tableView.rx.modelSelected or itemSelected is used, the delegate method isn't strictly necessary
// unless there's other logic in it. The current plan uses itemSelected.

// Removed old extension UserData with bindUI() - its functionality is now in bindView() and ViewModel
// Removed generate(valueSelected: String) method.

// Make sure UIViewController+HideKeyboard.swift exists for self.hideKeyboardWhenTappedAround()
// Make sure ViewFaceViewController exists and has a `name` property.
// Make sure "cellID" is correctly set in the Storyboard for the TableView cell.
// Make sure "viewFaceData" segue identifier is correct in the Storyboard.
// The fb, NetworkChecker, vectorHelper dependencies are now encapsulated in the ViewModel (conceptually).
// ProgressHUD usage is now driven by ViewModel's relays.
```
