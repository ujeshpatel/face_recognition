import Foundation
import UIKit // For UIImage
import RxSwift
import RxCocoa
import AVFoundation // For AVAsset, AVAssetImageGenerator, CMTime

// Assuming fnet, fb, GetFrames, savedUserList, defaults are accessible globally or via singletons.
// For ProgressHUD, ViewModel uses isLoading. For showDialog, alertMessage.

// Global/Singleton Placeholders (mimicking existing structure for this task)
// These would ideally be injected or managed by a proper dependency framework.
fileprivate let fnet = FaceNet() // Placeholder for FaceNet instance
fileprivate let fb = FirebaseManager.shared // Placeholder for FirebaseManager
fileprivate let getFramesUtil = GetFrames() // Placeholder for GetFrames instance
// Global 'savedUserList' and 'defaults' are assumed to be accessible as per original structure.
// var savedUserList: [String] = [] // Example, if it needs to be defined for compilation
// let defaults = UserDefaults.standard // Example

class AddNameViewModel {
    let disposeBag = DisposeBag()

    // MARK: - Input
    let videoURL: URL?

    // MARK: - Bindable Properties
    let userName = BehaviorRelay<String>(value: "")
    let userID = BehaviorRelay<String>(value: "")

    // MARK: - Output Relays
    let faceThumbnailImage = BehaviorRelay<UIImage?>(value: nil)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let alertMessage = PublishRelay<String>()
    let dismissView = PublishRelay<Void>()

    // MARK: - Dependencies (accessed via placeholders above)
    // private let fnet: FaceNet 
    // private let fb: FirebaseManager
    // private let getFramesUtil: GetFrames
    // Access to savedUserList and defaults will be direct as per original code for now

    init(videoURL: URL?) {
        self.videoURL = videoURL
        fnet.load() // From original AddNameViewController's viewDidLoad

        if let url = videoURL {
            generateThumbnail(from: url)
        }
    }

    private func generateThumbnail(from url: URL) {
        DispatchQueue.global().async {
            let asset = AVAsset(url: url)
            let avAssetImageGenerator = AVAssetImageGenerator(asset: asset)
            avAssetImageGenerator.appliesPreferredTrackTransform = true
            // Original code used CMTimeMake(value: 2, timescale: 1)
            // Let's use a slightly more robust way to get a time (e.g., 1st second or a specific time)
            // For consistency with original, using CMTimeMake.
            let thumbnailTime = CMTimeMake(value: 2, timescale: 1) 
            do {
                let cgThumbImage = try avAssetImageGenerator.copyCGImage(at: thumbnailTime, actualTime: nil)
                let thumbImage = UIImage(cgImage: cgThumbImage)
                DispatchQueue.main.async { [weak self] in
                    self?.faceThumbnailImage.accept(thumbImage)
                }
            } catch {
                print("Error generating thumbnail: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    // Optionally send an alert or set a placeholder error image
                    self?.alertMessage.accept("Could not generate video thumbnail.")
                    self?.faceThumbnailImage.accept(nil) 
                }
            }
        }
    }

    func submitNameAndVideo() {
        let nameValue = userName.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let idStrValue = userID.value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = videoURL else {
            alertMessage.accept("No video URL provided.")
            return
        }
        guard !nameValue.isEmpty else {
            alertMessage.accept("User Name cannot be empty.")
            return
        }
        guard !idStrValue.isEmpty else {
            alertMessage.accept("User ID cannot be empty.")
            return
        }
        guard let userIdInt = Int(idStrValue) else {
            alertMessage.accept("User ID must be a valid number.")
            return
        }

        isLoading.accept(true)

        // Firebase upload (async)
        // Assuming fb.uploadUser has a completion handler for this example
        fb.uploadUser(name: nameValue, user_id: userIdInt) { [weak self] /* success, error in */ in
            guard let self = self else { return }
            
            // This completion block's threading depends on fb.uploadUser's implementation.
            // For safety, dispatch UI updates and sensitive operations to the main thread.
            
            // Update savedUserList and UserDefaults (global access as per original structure)
            // This is not ideal MVVM. A dedicated service/manager should handle this.
            // Ensure thread safety if these globals can be accessed from multiple threads.
            DispatchQueue.main.async { // Assuming savedUserList/defaults are not thread-safe
                if !savedUserList.contains(nameValue) { // Avoid duplicates if name is unique ID
                    savedUserList.append(nameValue)
                    defaults.set(savedUserList, forKey: SAVED_USERS)
                }

                // Call GetFrames utility
                // This also might be a long-running task.
                // Consider how its completion affects the overall loading state / user feedback.
                self.getFramesUtil.getAllFrames(url, for: nameValue)
            
                self.isLoading.accept(false)
                // self.alertMessage.accept("User '\(nameValue)' added successfully!") // Optional: show success message
                self.dismissView.accept(())
            }
        }
        // If fb.uploadUser does NOT have a completion handler in the real implementation,
        // then isLoading.accept(false) and dismissView.accept(()) would be called immediately after
        // starting the upload and getFramesUtil, which might be premature.
        // The example snippet implies a completion handler, so I've followed that.
    }
}

// Placeholder definitions for dependencies if not available globally (for compilation)
// These should match actual implementations or be properly mocked/stubbed.

// Assuming FaceNet, FirebaseManager, GetFrames, savedUserList, defaults, SAVED_USERS are defined elsewhere.
// Example:
// class FaceNet { func load() { print("FaceNet loaded (placeholder)") } }
// class FirebaseManager {
//    static let shared = FirebaseManager()
//    func uploadUser(name: String, user_id: Int, completion: @escaping () -> Void) {
//        print("FirebaseManager: Uploading user \(name) (placeholder)")
//        DispatchQueue.global().asyncAfter(deadline: .now() + 1) { completion() }
//    }
// }
// class GetFrames { func getAllFrames(_ url: URL, for name: String) { print("GetFrames: Processing \(name) (placeholder)") } }
// var savedUserList: [String] = []
// let defaults = UserDefaults.standard
// let SAVED_USERS = "SavedUsersKey"

```
