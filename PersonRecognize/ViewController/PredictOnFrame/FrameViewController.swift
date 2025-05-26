//
//  FrameViewController.swift
//  PersonRez
//
//  Created by Hồ Sĩ Tuấn on 06/09/2020.
//  Copyright © 2020 Hồ Sĩ Tuấn. All rights reserved.
//

import UIKit
import Vision // Keep for VNFaceObservation if used directly by PreviewView, though likely not
import AVFoundation // Keep for AVSpeechSynthesizer
// FaceCropper is not directly used by VC
// ProgressHUD might be used if isLoading relay is added to ViewModel and bound
import RxSwift
import RxCocoa

class FrameViewController: UIViewController {
    
    @IBOutlet weak var previewView: PreviewView! // Keep this outlet
    
    // MARK: - ViewModel and DisposeBag
    private var viewModel: FrameViewModel!
    private let disposeBag = DisposeBag()

    // MARK: - Removed Properties
    // var currentFrame: UIImage?
    // private var devicePosition: AVCaptureDevice.Position = .front
    // private var session: AVCaptureSession!
    // private var isSessionRunning = false
    // private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)
    // private var setupResult: SessionSetupResult = .success // Enum might be internal to VM now or shared
    // private var videoDeviceInput: AVCaptureDeviceInput!
    // private var videoDataOutput: AVCaptureVideoDataOutput!
    // private var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
    // private var requests = [VNRequest]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Keep existing navigation bar styling
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = .clear
        
        viewModel = FrameViewModel()
        
        // Bind ViewModel's session to the PreviewView's session
        viewModel.previewViewSession
            .compactMap { $0 } // Ensure session is not nil
            .take(1) // Take the first valid session
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] session in
                self?.previewView.session = session
            })
            .disposed(by: disposeBag)
            
        bindView()
        
        // Removed: fnet.load(), direct session setup, Vision setup, authorization checks.
    }
    
    private func bindView() {
        // Detected Faces
        viewModel.detectedFacesInfo
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] facesInfo in
                self?.previewView.removeMask()
                for info in facesInfo {
                    // Assuming PreviewView's drawFaceboundingBox can take VNFaceObservation
                    // and a String label directly.
                    self?.previewView.drawFaceboundingBox(face: info.observation, label: info.label)
                }
            })
            .disposed(by: disposeBag)

        // Alert Messages
        viewModel.alertMessage
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] alertContent in
                let alertController = UIAlertController(title: alertContent.title, message: alertContent.message, preferredStyle: .alert)
                if let actions = alertContent.actions, !actions.isEmpty {
                    actions.forEach { alertController.addAction($0) }
                } else {
                    // Add a default OK action if no actions are provided by the ViewModel
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .default, handler: nil))
                }
                self?.present(alertController, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)

        // Speak Requests
        viewModel.speakRequest
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] textToSpeak in
                self?.speakNow(textToSpeak)
            })
            .disposed(by: disposeBag)

        // Session Setup Results (for Auth alerts)
        viewModel.setupResult
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                switch result {
                case .notAuthorized:
                    self?.showCameraPermissionAlert()
                case .configurationFailed:
                    // You might want a specific alert for configuration failure too.
                    // For now, using a generic one or relying on alertMessage from ViewModel.
                    let alertController = UIAlertController(title: "Camera Error", message: "Failed to configure the camera session.", preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    self?.present(alertController, animated: true, completion: nil)
                case .success:
                    // Session configured successfully, no specific alert needed here.
                    break
                }
            })
            .disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.startSessionLogic()
        // Removed: Direct session start and observer adding logic.
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.stopSessionLogic()
        // Removed: fnet.clean(), direct session stop, and observer removal logic.
    }
    
    // MARK: - User interaction
    @IBAction func tapTakePhoto(_ sender: UIButton) {
        viewModel.takePhotoTriggered()
        // Removed: All direct logic.
    }
    
    @IBAction func changeCamera(_ sender: UIBarButtonItem) {
        viewModel.switchCamera()
        // Removed: All direct logic.
    }

    // MARK: - Helper Methods
    private func speakNow(_ text: String) {
        let utterance = AVSpeechUtterance(string: text) // Default: "Hello \(name)"
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US") // Or other preferred language
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate // Or custom rate (e.g., 0.5 from original)
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

    private func showCameraPermissionAlert() {
        let message = NSLocalizedString("This app doesn't have permission to use the camera. Please change privacy settings.", comment: "Alert message when the user has denied access to the camera")
        let alertController = UIAlertController(title: "Camera Permission Denied", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .default, handler: { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        self.present(alertController, animated: true, completion: nil)
    }

    // MARK: - Removed Methods
    // configureSession, addVideoDataInput, addVideoDataOutput, stopCaptureSession
    // addObservers, removeObservers, sessionRuntimeError, sessionWasInterrupted, sessionInterruptionEnded
    // setupVision, handleFaces, getLabel, speak
}

// MARK: - Removed Extensions
// Removed: extension FrameViewController (for session configuration, observers, helpers, AVFoundation delegate)
// The AVCaptureVideoDataOutputSampleBufferDelegate conformance and its captureOutput method are removed.
```
