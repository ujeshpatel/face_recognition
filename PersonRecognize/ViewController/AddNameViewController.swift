//
//  AddNameViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 10/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
// AVFoundation is no longer directly used here
import SkyFloatingLabelTextField
// MBProgressHUD is not used
import ProgressHUD
import RxSwift
import RxCocoa

class AddNameViewController: UIViewController {
    
    // Removed: private var generator:AVAssetImageGenerator!
    
    @IBOutlet weak var idTextField: SkyFloatingLabelTextField!
    @IBOutlet weak var faceImageView: UIImageView!
    @IBOutlet weak var textField: SkyFloatingLabelTextField!
    var videoURL: URL?

    private var viewModel: AddNameViewModel!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = AddNameViewModel(videoURL: videoURL)
        bindView()
        
        hideKeyboardWhenTappedAround() // Keep existing utility
        
        // Removed: fnet.load() call
        // Removed: Manual thumbnail generation and faceImageView styling
    }
    
    private func bindView() {
        // User Name Input
        textField.rx.text.orEmpty
            .bind(to: viewModel.userName)
            .disposed(by: disposeBag)

        // User ID Input
        idTextField.rx.text.orEmpty
            .bind(to: viewModel.userID)
            .disposed(by: disposeBag)

        // Face Thumbnail Image
        viewModel.faceThumbnailImage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.faceImageView.image = image
                if image != nil {
                    self?.faceImageView.layer.cornerRadius = (self?.faceImageView.frame.height ?? 0) / 2
                    self?.faceImageView.layer.masksToBounds = true
                    self?.faceImageView.layer.borderWidth = 1
                    self?.faceImageView.layer.borderColor = UIColor.white.cgColor
                }
            })
            .disposed(by: disposeBag)

        // Loading State
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { isLoading in
                if isLoading {
                    ProgressHUD.animate("Adding...")
                } else {
                    ProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)

        // Alert Messages
        viewModel.alertMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                self?.showDialog(message: message) // Assuming showDialog is an extension or helper
            })
            .disposed(by: disposeBag)

        // Dismiss View Event
        viewModel.dismissView
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] in
                // The original code dismisses the rootViewController.
                // This might be specific to how the view is presented.
                // If it's pushed onto a navigation stack, self?.navigationController?.popViewController(animated: true)
                // or self?.dismiss(animated: true, completion: nil) might be more appropriate.
                // For consistency with original, using rootViewController.dismiss.
                self?.view.window?.rootViewController?.dismiss(animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
    
    @IBAction func tapDoneButoon(_ sender: UIButton) {
        viewModel.submitNameAndVideo()
        // Removed all previous logic (validation, ProgressHUD, fb calls, GetFrames, userDefaults, dismiss)
    }
    
    // Removed: func getThumbnailImageFromVideoUrl(url: URL, completion: @escaping ((_ image: UIImage?)->Void))
}

// Assuming UIViewController+ShowDialog.swift or similar provides this:
// extension UIViewController {
//    func showDialog(message: String) {
//        let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//        self.present(alert, animated: true, completion: nil)
//    }
// }

// Assuming UIViewController+HideKeyboard.swift provides:
// extension UIViewController {
//    func hideKeyboardWhenTappedAround() {
//        let tap = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
//        tap.cancelsTouchesInView = false
//        view.addGestureRecognizer(tap)
//    }
//    @objc func dismissKeyboard() {
//        view.endEditing(true)
//    }
// }
```
