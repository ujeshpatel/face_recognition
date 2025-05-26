//
//  PredictImageViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 11/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
// AVFoundation is no longer directly used here
import FaceCropper // Still needed if UIImage.face.crop is used by ViewModel, but VC doesn't call it
// MBProgressHUD is not used
import ProgressHUD
import RxSwift
import RxCocoa

// KDTree is not used here anymore

class PredictImageViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var mainImg: UIImageView!
    @IBOutlet weak var face1: UIImageView!
    @IBOutlet weak var face2: UIImageView!
    @IBOutlet weak var nameFace2: UILabel!
    @IBOutlet weak var nameFace1: UILabel!
    
    private var viewModel: PredictImageViewModel!
    private let disposeBag = DisposeBag()
    
    // Removed: var corner:CGFloat = 35

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = PredictImageViewModel()
        bindView()
        
        // Removed: fnet.load()
        // Removed: clearData() call
        // Removed: Commented-out KNN code
    }
    
    private func bindView() {
        viewModel.mainImage
            .observe(on: MainScheduler.instance)
            .bind(to: mainImg.rx.image)
            .disposed(by: disposeBag)
        
        viewModel.face1Image
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.face1.image = image
                if image != nil {
                    self?.face1.layer.cornerRadius = self?.viewModel.cornerRadius ?? 35
                    self?.face1.layer.masksToBounds = true
                } else {
                     self?.face1.layer.cornerRadius = 0 // Reset if no image
                }
            })
            .disposed(by: disposeBag)

        viewModel.face2Image
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] image in
                self?.face2.image = image
                if image != nil {
                    self?.face2.layer.cornerRadius = self?.viewModel.cornerRadius ?? 35
                    self?.face2.layer.masksToBounds = true
                } else {
                    self?.face2.layer.cornerRadius = 0 // Reset if no image
                }
            })
            .disposed(by: disposeBag)
            
        viewModel.nameFace1Text
            .observe(on: MainScheduler.instance)
            .bind(to: nameFace1.rx.text)
            .disposed(by: disposeBag)
            
        viewModel.nameFace2Text
            .observe(on: MainScheduler.instance)
            .bind(to: nameFace2.rx.text)
            .disposed(by: disposeBag)

        viewModel.alertMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                self?.showDialog(message: message) // Assuming showDialog is an extension or helper
            })
            .disposed(by: disposeBag)
        
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { isLoading in
                if isLoading {
                    ProgressHUD.animate("Processing...")
                } else {
                    ProgressHUD.dismiss()
                }
            })
            .disposed(by: disposeBag)
    }
    
    @IBAction func tapTakePhoto(_ sender: UIButton) {
        viewModel.clearResults() // Clear previous results before picking a new image
        
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Show alert or log, ViewModel could also handle this via an event if needed
            self.showDialog(message: "Camera is not available.")
            return
        }
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .camera
        imagePicker.cameraFlashMode = UIImagePickerController.CameraFlashMode.off
        imagePicker.allowsEditing = true // Or false, depending on desired behavior
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    // Removed: func clearData()

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) else {
            print("No image found")
            // Optionally, inform the user via alertMessage relay in ViewModel
            // viewModel.alertMessage.accept("Could not retrieve image from picker.")
            return
        }
        viewModel.processImage(image)
        
        // Removed all image processing, vectorHelper calls, image.face.crop, and direct UI updates.
    }
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
