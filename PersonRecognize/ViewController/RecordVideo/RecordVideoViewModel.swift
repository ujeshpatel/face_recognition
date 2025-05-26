import Foundation
import AVFoundation
import RxSwift
import RxCocoa

class RecordVideoViewModel: NSObject, AVCaptureFileOutputRecordingDelegate {
    let disposeBag = DisposeBag()

    // MARK: - AVCaptureSession Related
    let captureSession = AVCaptureSession()
    var movieOutput = AVCaptureMovieFileOutput()
    let previewSessionRelay = BehaviorRelay<AVCaptureSession?>(value: nil)

    // MARK: - Recording State & Timer
    private var timeRecord = BehaviorRelay<Int>(value: 5) // Initial recording duration
    private var timer: Timer?
    enum RecordingState { case idle, recording, finished }
    let recordingState = BehaviorRelay<RecordingState>(value: .idle)
    private var tempVideoOutputURL: URL?

    // MARK: - UI Update Relays
    let instructionText = BehaviorRelay<String?>(value: "Press Start to record a 5-second video.")
    let startButtonTitle = BehaviorRelay<String?>(value: "Start")
    let isStartButtonEnabled = BehaviorRelay<Bool>(value: true)

    // MARK: - Navigation & Output Relays
    let navigateToFillName = PublishRelay<URL>()
    let alertMessage = PublishRelay<String>()

    override init() {
        super.init()
        
        // Configure capture session
        captureSession.sessionPreset = .high
        
        setupCameraInput()
        previewSessionRelay.accept(captureSession)
        
        // Start session for preview
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func setupCameraInput() {
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            alertMessage.accept("Front camera is not available.")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: frontCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                alertMessage.accept("Could not add front camera input to the session.")
                return
            }
        } catch {
            alertMessage.accept("Error setting up camera input: \(error.localizedDescription)")
            return
        }
    }

    func handleStartButtonTap() {
        switch recordingState.value {
        case .idle:
            instructionText.accept("Move your head slowly!")
            isStartButtonEnabled.accept(false)
            startButtonTitle.accept("\(timeRecord.value) seconds remaining!") // Initial countdown display
            
            // Ensure movieOutput is configured and added to the session
            // It's better to add it once and leave it, or ensure it's removed if not needed.
            // For simplicity, let's assume it can be added if not already present.
            if !captureSession.outputs.contains(movieOutput) {
                 if captureSession.canAddOutput(movieOutput) {
                    captureSession.addOutput(movieOutput)
                } else {
                    alertMessage.accept("Could not add movie output to the session.")
                    isStartButtonEnabled.accept(true) // Re-enable button
                    instructionText.accept("Error: Could not start recording.")
                    return
                }
            }

            let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            guard let documentDirectory = paths.first else {
                alertMessage.accept("Could not access document directory.")
                isStartButtonEnabled.accept(true)
                return
            }
            let videoOutputURL = documentDirectory.appendingPathComponent("output.mov")
            
            // Remove existing file if any
            if FileManager.default.fileExists(atPath: videoOutputURL.path) {
                do {
                    try FileManager.default.removeItem(at: videoOutputURL)
                } catch {
                    alertMessage.accept("Could not remove existing video file: \(error.localizedDescription)")
                    isStartButtonEnabled.accept(true)
                    return
                }
            }
            
            movieOutput.startRecording(to: videoOutputURL, recordingDelegate: self)
            
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                self?.timerTick()
            }
            recordingState.accept(.recording)
            
        case .recording:
            // Button should be disabled. If this state is reached via button, it's an issue.
            // Or, this could be a "Stop" action if the button text changes.
            // Based on prompt, button is disabled, so this path shouldn't be hit by user tap.
            break 
            
        case .finished:
            // This means user tapped "Done" (or similar) after recording finished.
            // captureSession.stopRunning() // Stop the whole session if navigating away permanently.
                                        // Or just remove movieOutput if preview should continue for some reason.
                                        // For now, let stopViewDisappearLogic handle session stop.
            if let url = tempVideoOutputURL {
                navigateToFillName.accept(url)
            } else {
                alertMessage.accept("No recorded video available to proceed.")
            }
            // Optionally reset state for potential re-recording if the view doesn't dismiss
            // resetToIdleState() // See example in prompt
        }
    }

    private func timerTick() {
        let newTime = timeRecord.value - 1
        timeRecord.accept(newTime)
        
        if newTime > 0 {
            startButtonTitle.accept("\(newTime) seconds remaining!")
        } else if newTime == 0 {
            startButtonTitle.accept("Processing...") // Indicate processing before "Done"
            movieOutput.stopRecording() // Delegate method fileOutput will be called
            // Timer invalidation and other UI updates to "Done" state are now handled in fileOutput delegate
        }
        // If newTime < 0, something went wrong, timer should have been invalidated.
    }
    
    // MARK: - AVCaptureFileOutputRecordingDelegate
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        // Invalidate timer here as this is the true end of recording process
        if timer != nil {
             timer?.invalidate()
             timer = nil
        }

        if let err = error {
            alertMessage.accept("Error recording video: \(err.localizedDescription)")
            // Reset to idle state on error to allow retrying
            recordingState.accept(.idle)
            isStartButtonEnabled.accept(true)
            startButtonTitle.accept("Start")
            instructionText.accept("Recording failed. Press Start to try again.")
            timeRecord.accept(5) // Reset timer duration
        } else {
            tempVideoOutputURL = outputFileURL
            // Update UI to "Done" state
            isStartButtonEnabled.accept(true)
            startButtonTitle.accept("Done")
            instructionText.accept("Recording complete. Tap Done to proceed.")
            recordingState.accept(.finished)
        }
        // Reset timeRecord for next potential recording, even on success,
        // if user cancels navigation and wants to re-record.
        timeRecord.accept(5)
    }

    // MARK: - Session Management
    func stopViewDisappearLogic() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
        // Clean up movieOutput if it was added and isn't automatically removed
        if captureSession.outputs.contains(movieOutput) {
            // captureSession.removeOutput(movieOutput) // Optional: if it should be removed on view disappear
        }
    }

    // Helper to reset state if needed (e.g., if user cancels after recording)
    func resetToIdleState() {
        recordingState.accept(.idle)
        timeRecord.accept(5)
        startButtonTitle.accept("Start")
        isStartButtonEnabled.accept(true)
        instructionText.accept("Press Start to record a 5-second video.")
        tempVideoOutputURL = nil
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
}
```
