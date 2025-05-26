import UIKit
import Vision
import AVFoundation
import RxSwift
import RxCocoa

// MARK: - Helper Enums and Structs
enum SessionSetupResult {
    case success
    case notAuthorized
    case configurationFailed
}

struct AlertContent {
    let title: String
    let message: String
    let actions: [UIAlertAction]?
}

// MARK: - Constants (Placeholder values)
fileprivate let UNKNOWN = "Unknown"
fileprivate let VALID_TIME: Int = 3 // seconds
fileprivate let NUMBER_OF_FRAMES_THRESHOLD: Int = 10
fileprivate let TRAINING_MODE = false // Example, should be configurable if needed

// MARK: - Global/Singleton Placeholders (mimicking existing structure for this task)
fileprivate let fnet = FaceNet() // Placeholder for FaceNet instance
fileprivate let vectorHelper = VectorHelper() // Placeholder for VectorHelper instance
// Assume TrainingDataset and User struct are defined elsewhere
// fileprivate let trainingDataset = TrainingDataset.shared // Example
// struct User { let name: String; let image: UIImage?; let time: String? } // Example

class FrameViewModel: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let disposeBag = DisposeBag()

    // MARK: - AVCaptureSession Related
    let session = AVCaptureSession()
    let previewViewSession = BehaviorRelay<AVCaptureSession?>(value: nil)
    var isSessionRunning = BehaviorRelay<Bool>(value: false)
    let sessionQueue = DispatchQueue(label: "session queue", qos: .userInitiated)
    var setupResult = BehaviorRelay<SessionSetupResult>(value: .success)
    var videoDeviceInput: AVCaptureDeviceInput!
    var videoDataOutput: AVCaptureVideoDataOutput!
    let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", qos: .userInitiated)
    var devicePosition: AVCaptureDevice.Position = .front

    // MARK: - Vision Related
    var visionRequests = [VNRequest]()

    // MARK: - UI/State Relays
    let detectedFacesInfo = PublishRelay<[(observation: VNFaceObservation, label: String)]>()
    let alertMessage = PublishRelay<AlertContent>()
    let speakRequest = PublishRelay<String>()
    let currentFrameForPhoto = BehaviorRelay<UIImage?>(value: nil)

    // MARK: - Recognition Logic Internals
    private var currentLabel: String = UNKNOWN
    private var numberOfFramesDetected: Int = 0
    private var localUserList: [User] = [] // Placeholder for local user data
    private var timer: Timer? // For VALID_TIME logic

    // MARK: - Dependencies (accessed via placeholders above)
    // private let fnet: FaceNet 
    // private let vectorHelper: VectorHelper
    // private let trainingDataset: TrainingDataset

    override init() {
        super.init()
        fnet.load() // Load FaceNet model
        previewViewSession.accept(session) // Make session available to PreviewView
        
        checkCameraAuthorization()
        setupVisionRequests()
    }

    // MARK: - Camera Session Management
    func checkCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
        case .notDetermined:
            // The user has not yet been asked for camera access.
            // Suspend the session queue to delay session setup until the access request has completed.
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult.accept(.notAuthorized)
                }
                self.sessionQueue.resume()
            })
        default:
            // The user has previously denied access.
            setupResult.accept(.notAuthorized)
            return // Do not proceed with configuration if not authorized
        }
        
        // Configure session only if authorized (or not yet determined, will be handled by queue suspension)
        sessionQueue.async {
            self.configureSession()
        }
    }

    func configureSession() {
        guard setupResult.value == .success else {
            if setupResult.value == .notAuthorized {
                // Emit alert for not authorized
                DispatchQueue.main.async {
                    self.alertMessage.accept(AlertContent(title: "Camera Access Denied", message: "Please grant camera access in Settings.", actions: nil))
                }
            }
            return
        }
        
        session.beginConfiguration()
        session.sessionPreset = .vga640x480 // Example preset

        // Add video input.
        addVideoInput()
        
        // Add video output.
        addVideoOutput()
        
        session.commitConfiguration()
    }

    private func addVideoInput() {
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if devicePosition == .front {
                if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    defaultVideoDevice = frontCameraDevice
                }
            } else {
                if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    defaultVideoDevice = backCameraDevice
                }
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult.accept(.configurationFailed)
                session.commitConfiguration() // Need to commit if beginConfiguration was called
                return
            }
            
            let newVideoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if let currentInput = videoDeviceInput {
                session.removeInput(currentInput)
            }
            
            if session.canAddInput(newVideoDeviceInput) {
                session.addInput(newVideoDeviceInput)
                videoDeviceInput = newVideoDeviceInput
            } else {
                print("Couldn't add video device input to the session.")
                setupResult.accept(.configurationFailed)
                session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult.accept(.configurationFailed)
            session.commitConfiguration()
            return
        }
    }

    private func addVideoOutput() {
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true // Important for real-time processing
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        } else {
            print("Could not add video data output to the session")
            setupResult.accept(.configurationFailed)
            session.commitConfiguration() // Need to commit if beginConfiguration was called
            return
        }
    }

    func startSessionLogic() {
        sessionQueue.async {
            if self.setupResult.value == .success && !self.session.isRunning {
                self.session.startRunning()
                DispatchQueue.main.async { self.isSessionRunning.accept(self.session.isRunning) }
                // self.addObservers() // TODO: Implement observer logic if needed
            }
        }
    }

    func stopSessionLogic() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async { self.isSessionRunning.accept(self.session.isRunning) }
                // self.removeObservers() // TODO: Implement observer logic
                fnet.clean() // Clean FaceNet resources
                // Cancel any ongoing vision requests, though usually not explicitly needed if session stops sending buffers.
            }
        }
    }

    func switchCamera() {
        devicePosition = (devicePosition == .front) ? .back : .front
        sessionQueue.async {
            self.session.beginConfiguration()
            self.addVideoInput() // This will remove old input and add new one
            self.session.commitConfiguration()
        }
    }
    
    // TODO: Implement addObservers(), removeObservers(), sessionRuntimeError(), sessionWasInterrupted(), sessionInterruptionEnded()
    // These would typically involve NotificationCenter and update alertMessage or internal state. For brevity, skipped full impl.

    // MARK: - Vision and Recognition Logic
    func setupVisionRequests() {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest { (request, error) in
            // Using a block directly for simplicity here instead of separate handleDetectedFaces method for now
            // This avoids issues with `self` context in completion handlers if not careful
            DispatchQueue.main.async { // Ensure UI updates are on main thread
                guard let results = request.results as? [VNFaceObservation] else {
                    self.detectedFacesInfo.accept([]) // No faces or error
                    return
                }
                
                var faceData: [(observation: VNFaceObservation, label: String)] = []
                let currentFrameImage = self.currentFrameForPhoto.value // Capture for use in this block
                
                for observation in results {
                    // TODO: Potentially crop face from currentFrameImage using observation.boundingBox for better accuracy
                    // For now, using the whole frame as per original simplified flow.
                    // let croppedImage = self.cropFace(from: currentFrameImage, boundingBox: observation.boundingBox)
                    let label = self.getLabelForFrame(image: currentFrameImage) // Pass croppedImage if implemented
                    faceData.append((observation, label))
                }
                self.detectedFacesInfo.accept(faceData)
            }
        }
        self.visionRequests = [faceDetectionRequest]
    }

    // handleDetectedFaces is now inlined in setupVisionRequests completion handler

    func getLabelForFrame(image: UIImage?) -> String {
        guard let image = image else { return UNKNOWN }
        
        let result = vectorHelper.getResult(image: image) // Assuming this returns PredictionResult(name: String, distance: Double)
        let name = result.name
        
        if name == currentLabel {
            numberOfFramesDetected += 1
        } else {
            currentLabel = name
            numberOfFramesDetected = 1
            timer?.invalidate() // Invalidate previous timer
            timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(VALID_TIME), repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.numberOfFramesDetected >= NUMBER_OF_FRAMES_THRESHOLD {
                    if self.currentLabel != UNKNOWN {
                        // Check if user is in localUserList (simulating FrameViewController's logic)
                        if !self.localUserList.contains(where: { $0.name == self.currentLabel }) {
                            let detectedUser = User(name: self.currentLabel, image: image, time: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))
                            self.localUserList.append(detectedUser)
                            
                            // Training mode logic (placeholder)
                            if TRAINING_MODE {
                                // trainingDataset.saveImage(image, label: self.currentLabel)
                                print("Training image saved for \(self.currentLabel)")
                            }
                            
                            self.speakRequest.accept(self.currentLabel)
                            // Simulating showDialog3s
                            let alert = AlertContent(title: "User Detected", message: "\(self.currentLabel) recognized.", actions: nil)
                            self.alertMessage.accept(alert)
                            // Auto-dismiss alert after 3s would be handled by the View
                        }
                    }
                }
            }
        }
        return "\(currentLabel): \(String(format: "%.1f", result.distance))%" // Example label format
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Convert CMSampleBuffer to UIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async { // Update BehaviorRelay on main thread
            self.currentFrameForPhoto.accept(image)
        }

        do {
            // For consistency with the Vision framework, it's generally better to pass the CVPixelBuffer directly
            // or a CGImage if transformations are needed (like orientation).
            // Here, using CGImage from the converted UIImage.
            let imageRequestHandler = VNImageRequestHandler(cgImage: image.cgImage!, options: [:])
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

    // MARK: - User Action Methods
    func takePhotoTriggered() {
        guard let frame = currentFrameForPhoto.value else {
            alertMessage.accept(AlertContent(title: "Error", message: "No frame available to capture.", actions: nil))
            return
        }
        
        // Logic from FrameViewController's takePhoto
        // Assuming currentLabel is the recognized person for this photo
        if currentLabel != UNKNOWN {
            let detectedUser = User(name: currentLabel, image: frame, time: DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))
            
            // Simulating showDialog3s for photo taken
            let message = "\(detectedUser.name) photo captured."
            alertMessage.accept(AlertContent(title: "Photo Taken", message: message, actions: nil))
            
            // Original code had Firebase upload logic here, which is commented out.
            // fb.uploadSingleImage(user: detectedUser) { error in ... }
        } else {
            alertMessage.accept(AlertContent(title: "Photo", message: "No recognized user to associate with the photo.", actions: nil))
        }
    }
}


// MARK: - Placeholder Definitions (for compilation if not globally available)
// These should be replaced with actual implementations or proper mocks.

// struct User { let name: String; let image: UIImage?; let time: String? }
// class FaceNet { func load() {}; func clean() {} }
// struct PredictionResult { let name: String; let distance: Double }
// class VectorHelper { func getResult(image: UIImage) -> PredictionResult { return PredictionResult(name: UNKNOWN, distance: 0.0)} }
// class TrainingDataset { static let shared = TrainingDataset(); func saveImage(_ image: UIImage, label: String) {} }

```
