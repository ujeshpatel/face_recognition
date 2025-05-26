import Foundation
import RxSwift
import RxCocoa
import RealmSwift
import ProgressHUD // For status messages, though direct calls will be replaced by relays
import UIKit // For UIImage

// Assuming these are globally accessible or singletons for this step
// let fnet = FaceNet() - This would be an instance
// let fb = FirebaseManager.shared
// let vectorHelper = VectorHelper()
// let networkChecker = NetworkChecker.shared
// var current: CGImage? - Global variable from original HomeViewController
// let NUMBER_OF_K: Int = 10 - Global constant

class HomeViewModel {
    let disposeBag = DisposeBag()

    // MARK: - Output Relays for View
    let vectorsLabelText = BehaviorRelay<String?>(value: "Loading data...")
    let displayImage = BehaviorRelay<UIImage?>(value: nil)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let statusMessage = PublishRelay<String>()
    let navigationEvent = PublishRelay<NavigationTarget>()

    enum NavigationTarget {
        case startPredict, openPredictImage, openAddUser, viewFace, viewLog
    }

    // MARK: - Private Properties (Data managed by ViewModel)
    private var kMeanVectors: [Vector] = []
    private var userDict: [String: Int] = [:] // To store user names and their counts/IDs

    // MARK: - Dependencies (Conceptual - assuming global/singleton access for now)
    // These would ideally be injected. For now, we'll assume they can be called directly.
    // private let fnet: FaceNet // Instance needed
    // private let fb: FirebaseManager
    // private let realm: Realm
    // private let vectorHelper: VectorHelper
    // private let networkChecker: NetworkChecker

    // For the purpose of this task, we'll initialize Realm directly.
    // In a real app, fnet, fb, etc., would also be properly initialized or injected.
    private var realm: Realm
    // Accessing global variables like 'current' directly is not ideal MVVM.
    // The ViewController should ideally pass 'current' to the ViewModel if it changes,
    // or the ViewModel should have a way to request it. For now, we'll mimic direct access in handleViewWillAppear.

    init() {
        do {
            self.realm = try Realm()
        } catch {
            // This would typically be handled more gracefully, maybe by trying to recover or logging.
            // For this exercise, a fatal error highlights the issue during development.
            fatalError("Failed to initialize Realm in HomeViewModel: \(error)")
        }
        
        // Initial data load can be triggered here or by the View calling a method.
        // loadData() // Or let View call it in its viewDidLoad/viewWillAppear
    }

    // MARK: - Core Logic: Data Loading
    func loadData() {
        isLoading.accept(true)
        vectorsLabelText.accept("Loading data...")

        // Assuming NetworkChecker.shared and other singletons/globals are accessible
        if NetworkChecker.shared.isConnectedToInternet {
            // Online: Load from Firebase and save to Realm
            let group = DispatchGroup()
            var firebaseError: Error?

            group.enter()
            FirebaseManager.shared.loadVector(child: KMEAN_VECTOR) { [weak self] (vectors, error) in
                if let error = error {
                    firebaseError = error
                    print("Error loading kMean vectors: \(error.localizedDescription)")
                } else {
                    self?.kMeanVectors = vectors
                    // Save to Realm (this part needs careful transaction handling)
                    self?.saveKMeanVectorsToRealm(vectors)
                }
                group.leave()
            }

            group.enter()
            FirebaseManager.shared.loadUsers { [weak self] (users, error) in
                if let error = error {
                    firebaseError = error
                    print("Error loading users: \(error.localizedDescription)")
                } else {
                    self?.userDict = users
                    // Save to Realm (this part needs careful transaction handling)
                    self?.saveUsersToRealm(users)
                }
                group.leave()
            }

            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.isLoading.accept(false)
                if firebaseError != nil {
                    self.statusMessage.accept("Error loading data from Firebase. Check console.")
                    // Optionally, try loading from Realm as a fallback
                    self.loadDataFromRealm()
                } else {
                    self.updateVectorsLabel()
                    self.statusMessage.accept("Data loaded from Firebase and synced to local Realm.")
                }
            }
        } else {
            // Offline: Load from Realm
            loadDataFromRealm()
            statusMessage.accept("No internet connection. Using local data.")
            isLoading.accept(false)
        }
    }

    private func loadDataFromRealm() {
        // Assuming VectorObject and UserObject are Realm object types corresponding to Vector and userDict items
        self.kMeanVectors = realm.objects(VectorObject.self).map { $0.toSwiftVector() } // Needs conversion method
        
        let userObjects = realm.objects(UserObject.self) // Needs UserObject definition
        var localUserDict: [String: Int] = [:]
        for userObj in userObjects {
            localUserDict[userObj.name] = userObj.id
        }
        self.userDict = localUserDict
        
        updateVectorsLabel()
        if kMeanVectors.isEmpty && userDict.isEmpty {
            statusMessage.accept("No local data found. Please connect to the internet and sync.")
        }
    }
    
    private func saveKMeanVectorsToRealm(_ vectors: [Vector]) {
        // This is a simplified representation. VectorHelper might have more sophisticated logic.
        // Or, if VectorHelper.saveVector is for individual vectors, we might loop.
        // For now, assuming a direct Realm transaction.
        do {
            try realm.write {
                realm.delete(realm.objects(VectorObject.self)) // Clear old vectors
                for vector in vectors {
                    // Assuming VectorObject has an initializer or properties to map from Vector
                    let vectorObj = VectorObject(from: vector) // Needs implementation
                    realm.add(vectorObj, update: .modified) // Use .modified if primary keys exist
                }
            }
        } catch {
            print("Failed to save KMean vectors to Realm: \(error)")
            statusMessage.accept("Failed to save KMean vectors locally.")
        }
    }

    private func saveUsersToRealm(_ users: [String: Int]) {
         do {
            try realm.write {
                realm.delete(realm.objects(UserObject.self)) // Clear old users
                for (name, id) in users {
                    let userObj = UserObject() // Needs UserObject definition
                    userObj.name = name
                    userObj.id = id
                    // userObj.primaryKey = name // if name is PK
                    realm.add(userObj, update: .modified) // Use .modified if primary keys exist
                }
            }
        } catch {
            print("Failed to save users to Realm: \(error)")
            statusMessage.accept("Failed to save users locally.")
        }
    }

    private func updateVectorsLabel() {
        // Logic from HomeViewController.loadData to update the label
        // Assuming kMeanVectors are the primary source for the label text
        if kMeanVectors.count > 0 {
            vectorsLabelText.accept("\(kMeanVectors.count) vectors in \(userDict.count) users")
        } else {
            vectorsLabelText.accept("No vectors loaded. Tap sync.")
        }
    }


    // MARK: - Lifecycle Forwarded Methods
    func handleViewWillAppear() {
        // Logic for 'current' image if it's a global or accessible
        // This mimics the direct access in the original ViewController.
        // A better approach would be for the ViewController to provide this image to the ViewModel.
        if let cgImg = currentImageGlobal { // Assuming 'currentImageGlobal' is the global CGImage?
            displayImage.accept(UIImage(cgImage: cgImg))
        }
        // Any other logic from original viewWillAppear can be added here
    }

    func handleViewDidAppear() {
        FaceNet.shared.clean() // Assuming FaceNet has a shared instance or is globally accessible
    }

    func handleViewWillDisappear() {
        FaceNet.shared.load() // Assuming FaceNet has a shared instance or is globally accessible
    }

    // MARK: - User Action Handlers
    func syncDataTriggered() {
        // Could add extra logic here, e.g., confirm before syncing if recently synced.
        loadData()
    }

    func navigationButtonTapped(target: NavigationTarget) {
        navigationEvent.accept(target)
    }
}

// MARK: - Realm Object Definitions (Placeholders - these should be in their own files or a Realm model file)
// These are needed for the Realm operations in HomeViewModel.
// They need to match the structure of 'Vector' and the user data.

// Placeholder for global 'current' image (mimicking original VC structure)
var currentImageGlobal: CGImage? 

// Placeholder for global FaceNet instance
class FaceNet { // Simplified placeholder
    static let shared = FaceNet()
    private init() {}
    func clean() { print("FaceNet cleaned") }
    func load() { print("FaceNet loaded") }
}

// Placeholder for FirebaseManager
class FirebaseManager { // Simplified placeholder
    static let shared = FirebaseManager()
    private init() {}
    func loadVector(child: String, completion: @escaping ([Vector], Error?) -> Void) {
        print("FirebaseManager: Loading vectors from child \(child)")
        // Simulate async call
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            // completion([], nil) // Simulate success with empty data
            completion([Vector(name: "test", feature: [0.1, 0.2])], nil) // Simulate success with some data
            // completion([], NSError(domain: "FirebaseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch vectors."])) // Simulate error
        }
    }
    func loadUsers(completion: @escaping ([String: Int], Error?) -> Void) {
        print("FirebaseManager: Loading users")
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            completion(["UserA": 1, "UserB": 2], nil) // Simulate success
        }
    }
}

// Placeholder for Vector (if not already defined elsewhere)
struct Vector { // Simplified placeholder
    let name: String
    let feature: [Float]
    // Add other properties if they exist in the original Vector struct/class
}

// Placeholder for VectorObject (Realm model)
class VectorObject: Object { // Simplified placeholder
    @Persisted(primaryKey: true) var name: String // Assuming name is unique, or use another PK
    @Persisted var feature = List<Float>()
    // Add other properties corresponding to Vector struct

    // Convenience initializer to convert from Vector to VectorObject
    convenience init(from vector: Vector) {
        self.init()
        self.name = vector.name
        self.feature.append(objectsIn: vector.feature)
    }
    
    func toSwiftVector() -> Vector { // Conversion back to non-Realm type
        return Vector(name: self.name, feature: Array(self.feature))
    }
}

// Placeholder for UserObject (Realm model)
class UserObject: Object { // Simplified placeholder
    @Persisted(primaryKey: true) var name: String // Assuming name is unique
    @Persisted var id: Int
    // Add other properties if needed
}


// Placeholder for NetworkChecker
class NetworkChecker { // Simplified placeholder
    static let shared = NetworkChecker()
    private init() {}
    var isConnectedToInternet: Bool = true // Simulate connected state
}

// Placeholder for VectorHelper
class VectorHelper { // Simplified placeholder
    func saveVector(name: String, image: UIImage, completion: @escaping ([Vector]) -> Void) { // Signature might differ
        print("VectorHelper: Saving vector for \(name)")
        // Simulate async processing
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            completion([Vector(name: name, feature: [0.3, 0.4])]) // Simulate generated vector
        }
    }
}

// Placeholder for global constants (if not defined elsewhere)
let KMEAN_VECTOR = "kMeanVectors" // Example value
let ALL_VECTOR = "allVectors"     // Example value
let NUMBER_OF_K = 10              // Example value
let USER_REF = "users"            // Example value
```
