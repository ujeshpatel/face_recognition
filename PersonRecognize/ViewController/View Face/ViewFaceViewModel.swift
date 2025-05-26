import UIKit
import RxSwift
import RxCocoa

// MARK: - Global/Singleton Placeholders (mimicking existing structure for this task)
// These would ideally be injected or managed by a proper dependency framework.
// For this task, we assume they are globally accessible.

// Example placeholder for TrainingDataset
// In a real app, this would be a proper class/struct.
class TrainingDataset { // Simplified placeholder
    static let shared = TrainingDataset()
    private init() {}
    // Simulates fetching images for a label. Returns an array of optional UIImages.
    func getImage(label: String) -> [UIImage?] {
        print("TrainingDataset: Fetching images for label \(label)")
        // Simulate fetching a few placeholder images if you want to test the imageList relay.
        // For now, returning an empty array or a couple of nils.
        // return [nil, nil, nil] 
        // Or, to simulate some actual images:
        // return [UIImage(systemName: "person.fill"), UIImage(systemName: "person.crop.circle")]
        return [] // Default to empty for now
    }
}

// Example placeholder for VectorHelper
// class VectorHelper { // Already defined in HomeViewModel, ensure consistency or use a shared definition
//    static let shared = VectorHelper()
//    private init() {}
//    // Simulates adding/generating vectors for a user name.
//    // The completion handler provides an array of Vector structs.
//    func addVector(name: String, completion: @escaping ([Vector]) -> Void) {
//        print("VectorHelper: Adding/generating vectors for \(name)")
//        // Simulate async processing
//        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
//            // completion([Vector(name: name, feature: [0.5, 0.6])]) // Simulate some generated vectors
//            completion([]) // Simulate no vectors found/generated
//        }
//    }
// }

// Example placeholder for FirebaseManager
// class FirebaseManager { // Already defined in HomeViewModel, ensure consistency or use a shared definition
//    static let shared = FirebaseManager()
//    private init() {}
//    // Simulates uploading k-Mean vectors.
//    func uploadKMeanVectors(vectors: [Vector], child: String, completion: @escaping () -> Void) {
//        print("FirebaseManager: Uploading k-Mean vectors to child \(child)")
//        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { completion() }
//    }
//    // Simulates uploading all vectors.
//    func uploadAllVectors(vectors: [Vector], child: String, completion: @escaping () -> Void) {
//        print("FirebaseManager: Uploading all vectors to child \(child)")
//        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { completion() }
//    }
// }

// Example placeholder for global function getKMeanVectorSameName
// This function would take an array of Vector and return k-mean vectors via completion.
func getKMeanVectorSameName(vectors: [Vector], completion: @escaping ([Vector]) -> Void) {
    print("Global: Calculating k-Mean vectors")
    // Simulate async processing
    DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
        // completion(vectors) // Pass through for simulation, or actual k-means logic
        completion(vectors.count > 5 ? Array(vectors.prefix(5)) : vectors) // Simulate reducing to k-means
    }
}

// Example placeholder for Vector struct (if not globally defined from HomeViewModel's context)
// struct Vector { let name: String; let feature: [Float] }

// Example placeholder for global constants (if not globally defined)
// let KMEAN_VECTOR = "kMeanVectors_child_name"
// let ALL_VECTOR = "allVectors_child_name"


class ViewFaceViewModel {
    let disposeBag = DisposeBag()

    private let userName: String

    // MARK: - Output Relays
    let imageList = BehaviorRelay<[UIImage?]>(value: [])
    let viewTitle = BehaviorRelay<String?>(value: nil)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let alertMessage = PublishRelay<String>()

    // MARK: - Dependencies (Conceptual - assuming global access via placeholders above)
    private let trainingDataset = TrainingDataset.shared // Using shared instance from placeholder
    private let vectorHelper = VectorHelper.shared     // Using shared instance from placeholder
    private let fb = FirebaseManager.shared            // Using shared instance from placeholder

    init(userName: String) {
        self.userName = userName
        loadFaceImages()
    }

    private func loadFaceImages() {
        // Assuming trainingDataset.getImage is synchronous or handles its own threading for UI image data.
        // If it were async, this would need a completion handler to update relays.
        let fetchedImages = trainingDataset.getImage(label: self.userName)
        self.imageList.accept(fetchedImages)
        self.viewTitle.accept("\(self.userName): \(fetchedImages.count) faces")
    }

    func generateAndUploadVectors() {
        self.isLoading.accept(true)
        
        vectorHelper.addVector(name: self.userName) { [weak self] resultVectors in
            guard let self = self else { return }

            if !resultVectors.isEmpty {
                // Vectors generated, proceed to k-Means and upload
                getKMeanVectorSameName(vectors: resultVectors) { kMeanVectors_calculated in
                    // Assuming getKMeanVectorSameName calls its completion on a background thread or main.
                    // For safety, dispatch Firebase calls if their completion might be on main.
                    // Or, ensure Firebase completions dispatch to main for UI updates.
                    
                    self.fb.uploadKMeanVectors(vectors: kMeanVectors_calculated, child: KMEAN_VECTOR) {
                        // Firebase completion, ensure UI updates are on main thread
                        DispatchQueue.main.async {
                            self.isLoading.accept(false) // Stop loading after k-Means upload
                            self.alertMessage.accept("Uploaded k-Means vectors for \(self.userName). Total source images: \(resultVectors.count).")
                            
                            // Now upload all vectors (can be in background, UI already updated for k-Means)
                            // If this also needs a loading indicator, manage isLoading more granularly.
                            self.fb.uploadAllVectors(vectors: resultVectors, child: ALL_VECTOR) {
                                print("Successfully uploaded all vectors for \(self.userName).")
                                // Optionally, another alertMessage or log
                                // self.alertMessage.accept("All vectors also uploaded for \(self.userName).")
                            }
                        }
                    }
                }
            } else {
                // No vectors generated from local data
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.alertMessage.accept("No local images found to generate vectors for \(self.userName). Please ensure images are available locally.")
                }
            }
        }
    }
}

// Ensure VectorHelper, FirebaseManager, Vector struct, and constants (KMEAN_VECTOR, ALL_VECTOR)
// are defined and accessible in the scope where this ViewModel is used.
// For the purpose of this task, they are assumed to be globally available or defined
// within the same project structure (e.g., from previous ViewModel creations).
// If these were defined in other files like HomeViewModel.swift, ensure they are not private
// or fileprivate in a way that makes them inaccessible here.
// For simplicity, I'm assuming the placeholder definitions above or similar are available.
```
