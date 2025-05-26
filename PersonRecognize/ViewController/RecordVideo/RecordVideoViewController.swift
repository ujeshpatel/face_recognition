//
//  RecordVideoViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 09/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
import AVFoundation
// MBProgressHUD is not used directly here, ProgressHUD might be if ViewModel exposes isLoading
import RxSwift
import RxCocoa

class RecordVideoViewController: UIViewController { // Removed AVCaptureFileOutputRecordingDelegate
    
    @IBOutlet weak var desLabel: UILabel!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var videoView: VideoView! // Assuming VideoView is a UIView subclass for preview
    
    // MARK: - ViewModel and DisposeBag
    private var viewModel: RecordVideoViewModel!
    private let disposeBag = DisposeBag()
    
    // MARK: - Preview Layer and Output URL
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var outputVideoUrl: URL? // For segue

    // MARK: - Removed Properties
    // var captureSession: AVCaptureSession!
    // var stillImageOutput: AVCapturePhotoOutput!
    // var movieOutput = AVCaptureMovieFileOutput()
    // var timeRecord = 5
    // var timer = Timer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = RecordVideoViewModel()
        setupLivePreviewFromViewModel()
        bindView()
        
        // If hideKeyboardWhenTappedAround() is a utility function, it can be called here:
        // hideKeyboardWhenTappedAround()
    }
    
    private func setupLivePreviewFromViewModel() {
        videoView.layer.cornerRadius = 150 // Or get from ViewModel if configurable
        videoView.layer.masksToBounds = true
        videoView.layer.borderWidth = 1
        videoView.layer.borderColor = UIColor.white.cgColor

        viewModel.previewSessionRelay // Assuming this is BehaviorRelay<AVCaptureSession?>
            .compactMap { $0 } // Ensure session is not nil
            .take(1) // Take the first valid session
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                guard let self = self else { return }
                self.videoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                self.videoPreviewLayer?.videoGravity = .resizeAspectFill 
                self.videoPreviewLayer?.frame = self.videoView.layer.bounds // Initial frame
                self.videoPreviewLayer?.connection?.videoOrientation = .portrait 
                if let layer = self.videoPreviewLayer {
                    self.videoView.layer.insertSublayer(layer, at: 0)
                }
                
                DispatchQueue.main.async { 
                     self.videoPreviewLayer?.frame = self.videoView.bounds
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func bindView() {
        // Instruction Label
        viewModel.instructionText
            .bind(to: desLabel.rx.text)
            .disposed(by: disposeBag)

        // Start Button Title
        viewModel.startButtonTitle
            .bind(to: startButton.rx.title(for: .normal),
                  to: startButton.rx.title(for: .disabled))
            .disposed(by: disposeBag)

        // Start Button Enabled State
        viewModel.isStartButtonEnabled
            .bind(to: startButton.rx.isEnabled)
            .disposed(by: disposeBag)

        // Alert Messages
        viewModel.alertMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] message in
                // Assuming showDialog is a UIViewController extension or helper
                self?.showDialog(message: message) 
            })
            .disposed(by: disposeBag)

        // Navigation
        viewModel.navigateToFillName
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] videoURL in
                self?.outputVideoUrl = videoURL // Store for segue
                self?.performSegue(withIdentifier: "openFillName", sender: nil)
            })
            .disposed(by: disposeBag)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.stopViewDisappearLogic()
        // Removed: self.captureSession.stopRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = videoView.bounds
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "openFillName" {
            let vc = segue.destination as! AddNameViewController
            vc.videoURL = self.outputVideoUrl // Uses the property set by ViewModel binding
        }
    }
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        viewModel.handleStartButtonTap()
        // Removed: All direct AVFoundation logic, timer management, and navigation.
    }
    
    // Removed: timerAction()
    // Removed: setupLivePreview() (replaced by setupLivePreviewFromViewModel)
    // Removed: AVCaptureFileOutputRecordingDelegate conformance and fileOutput method
}

// Assuming a showDialog helper extension exists for UIViewController
// extension UIViewController {
//     func showDialog(message: String) {
//         let alert = UIAlertController(title: "Info", message: message, preferredStyle: .alert)
//         alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//         present(alert, animated: true, completion: nil)
//     }
// }
```
