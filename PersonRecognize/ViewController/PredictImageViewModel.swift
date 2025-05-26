import Foundation
import UIKit
import RxSwift
import RxCocoa
import FaceCropper // Important import

// Assuming fnet, vectorHelper are accessible globally or via singletons for this task.
// These would ideally be injected in a production app.
fileprivate let fnet = FaceNet() // Placeholder for FaceNet instance
fileprivate let vectorHelper = VectorHelper() // Placeholder for VectorHelper instance
                                            // It's assumed VectorHelper has getResult(image:) method

class PredictImageViewModel {
    let disposeBag = DisposeBag()

    // MARK: - Output Relays
    let mainImage = BehaviorRelay<UIImage?>(value: nil)
    let face1Image = BehaviorRelay<UIImage?>(value: nil)
    let face2Image = BehaviorRelay<UIImage?>(value: nil)
    let nameFace1Text = BehaviorRelay<String?>(value: "")
    let nameFace2Text = BehaviorRelay<String?>(value: "")
    let alertMessage = PublishRelay<String>()
    let isLoading = BehaviorRelay<Bool>(value: false)

    // MARK: - Constants
    let cornerRadius: CGFloat = 35 // As per original VC

    // MARK: - Dependencies (accessed via placeholders above)
    // private let fnet: FaceNet 
    // private let vectorHelper: VectorHelper

    init() {
        fnet.load() // From original PredictImageViewController's viewDidLoad
        clearResults()
    }

    func clearResults() {
        mainImage.accept(nil)
        face1Image.accept(nil)
        face2Image.accept(nil)
        nameFace1Text.accept("")
        nameFace2Text.accept("")
        isLoading.accept(false) // Reset loading state if it was active
    }

    func processImage(_ image: UIImage) {
        self.isLoading.accept(true)
        self.mainImage.accept(image)
        
        // Clear previous face-specific results immediately
        self.face1Image.accept(nil)
        self.face2Image.accept(nil)
        // self.nameFace1Text.accept("Processing...") // Optional: intermediate state
        // self.nameFace2Text.accept("")

        let start = DispatchTime.now()
        // Assuming vectorHelper.getResult returns a struct/tuple like (name: String, distance: Double)
        let initialResult = vectorHelper.getResult(image: image)
        let end = DispatchTime.now()
        let nanoTime = end.uptimeNanoseconds - start.uptimeNanoseconds
        let timeInterval = Double(nanoTime) / 1_000_000_000

        // Initial update based on overall image (as per original logic flow)
        // The original code seems to prioritize face1Text for the first result, and face2Text for timing.
        self.nameFace1Text.accept("\(initialResult.name): \(String(format: "%.2f", initialResult.distance))%")
        self.nameFace2Text.accept("Time: \(String(format: "%.3f", timeInterval))s")
        
        image.face.crop { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async { // Ensure UI updates are on the main thread
                switch result {
                case .success(let faces):
                    if let firstFace = faces.first {
                        self.face1Image.accept(firstFace)
                        let firstFaceResult = self.vectorHelper.getResult(image: firstFace)
                        // Overwrite nameFace1Text with the result from the first detected face
                        self.nameFace1Text.accept("\(firstFaceResult.name): \(String(format: "%.2f", firstFaceResult.distance))%")
                        
                        if faces.count > 1 {
                            let secondFace = faces[1]
                            self.face2Image.accept(secondFace)
                            let secondFaceResult = self.vectorHelper.getResult(image: secondFace)
                            // Overwrite nameFace2Text with the result from the second detected face
                            self.nameFace2Text.accept("\(secondFaceResult.name): \(String(format: "%.2f", secondFaceResult.distance))%")
                        } else {
                            // If only one face, clear the second face image.
                            // Keep the timing info in nameFace2Text if no second face, or clear it.
                            // For now, let's keep the timing info if there's no second face.
                            self.face2Image.accept(nil)
                            // If timing was in nameFace2Text and we want to clear it when no second face:
                            // self.nameFace2Text.accept("")
                        }
                    } else {
                        // This case (success but no faces) should ideally not happen.
                        self.alertMessage.accept("No faces found after successful crop.")
                        self.face1Image.accept(nil)
                        self.face2Image.accept(nil)
                        // Reset labels if needed
                        // self.nameFace1Text.accept("No face detected.")
                        // self.nameFace2Text.accept("")
                    }
                case .notFound:
                    self.alertMessage.accept("Not found any face!")
                    self.face1Image.accept(nil)
                    self.face2Image.accept(nil)
                    // Reset labels to indicate no face found, or clear them
                    // self.nameFace1Text.accept("No face detected.")
                    // self.nameFace2Text.accept("")
                case .failure(let error):
                    print("Error crop face: \(error)")
                    self.alertMessage.accept("Error cropping face: \(error.localizedDescription)")
                    self.face1Image.accept(nil)
                    self.face2Image.accept(nil)
                    // Reset labels
                    // self.nameFace1Text.accept("Error processing face.")
                    // self.nameFace2Text.accept("")
                }
                self.isLoading.accept(false)
            }
        }
    }
}

// Placeholder definitions for dependencies if not available globally (for compilation)
// These should match actual implementations or be properly mocked/stubbed.

// Assuming FaceNet, VectorHelper are defined elsewhere and VectorHelper.getResult returns a specific type.
// Example:
// class FaceNet { func load() { print("FaceNet loaded (placeholder)") } }
// struct PredictionResult { // Example structure for what getResult might return
//    let name: String
//    let distance: Double
// }
// class VectorHelper {
//    func getResult(image: UIImage) -> PredictionResult {
//        print("VectorHelper: Getting result for image (placeholder)")
//        // Simulate some prediction
//        return PredictionResult(name: "UserX", distance: 98.5)
//    }
// }
// UIImage.face.crop is a method provided by FaceCropper.
// Ensure FaceCropper is correctly integrated if this were a real project.
```
