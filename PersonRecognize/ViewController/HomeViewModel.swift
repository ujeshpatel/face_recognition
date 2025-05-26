import Foundation
import RxSwift
import RxCocoa
import RealmSwift // Assuming RealmSwift is used for Realm types
import UIKit // For UIImage

// Assuming global/singleton access for fnet, fb, realm, vectorHelper, NetworkChecker,
// current (global image), and NUMBER_OF_K as per original HomeViewController context.

// MARK: - Placeholder/Example Definitions (These should match your actual project structure)
// Ensure these are properly defined in your project if they are not already.

// Minimal 'Vector' for this context:
struct Vector { // This might be defined elsewhere, ensure it's accessible
    var name: String
    var vector: [Double] // Or whatever type stringToArray returns
    var distance: Double // Or whatever type is appropriate
}

// Minimal 'SavedVector' Realm Object (ensure this is defined in your Realm setup):
class SavedVector: Object { // This should be defined in a Realm model file
    @Persisted var name: String = ""
    @Persisted var vector: String = "" // Assuming stringToArray converts this
    @Persisted var distance: Double = 0.0
    // Add a primary key if needed, e.g., @Persisted(primaryKey: true) var id: ObjectId
}

// Globals that need to be accessible (placeholders, ensure actual instances are used)
var current: CGImage? // Example global, manage its lifecycle appropriately
// For singletons/shared instances, define them properly
class FaceNet { // Placeholder
    static let shared = FaceNet()
    private init() {}
    func load() { print("FaceNet loaded (placeholder)") }
    func clean() { print("FaceNet cleaned (placeholder)") }
}
class FirebaseManager { // Placeholder
    static let shared = FirebaseManager()
    private init() {}
    func loadVector(completion: @escaping ([Vector], Error?) -> Void) { /* ... */ }
    func loadUsers(completionHandler: @escaping ([String: Int], Error?) -> Void) { /* ... */ }
}
class VectorHelper { // Placeholder
    static let shared = VectorHelper()
    private init() {}
    func saveVector(_ vector: Vector) { /* ... */ } // Assuming this saves to Realm
}
class NetworkChecker { // Placeholder
    static let shared = NetworkChecker()
    private init() {}
    var isConnectedToInternet: Bool = true // Default to true for simulation
}
let NUMBER_OF_K: Int = 10 // Example value
func stringToArray(string: String) -> [Double] { return [] } // Placeholder

// Accessing actual instances for dependencies
fileprivate let fnet = FaceNet.shared
fileprivate let fb = FirebaseManager.shared
// Realm instance should be obtained via try! Realm() or try? Realm() where needed
fileprivate let vectorHelper = VectorHelper.shared
// NetworkChecker is used via NetworkChecker.shared directly in methods

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
    // These will be populated by loadData()
    private var kMeanVectorsList: [Vector] = [] 
    private var userDictionary: [String: Int] = [:]

    // MARK: - Dependencies (Accessed as globals/singletons as per original VC)
    // For example:
    // private let fnet = FaceNet() // Or however it's accessed globally
    // private let fb = FirebaseManager.shared // Or however it's accessed globally
    // private let realm = try! Realm() // Or however it's accessed globally
    // private let vectorHelper = VectorHelper() // Or however it's accessed globally
    // private let networkChecker = NetworkChecker.shared // Or however it's accessed globally


    init() {
        // If 'current' global image needs to be loaded initially:
        // if let cgImg = current { // 'current' is the global CGImage?
        //     displayImage.accept(UIImage(cgImage: cgImg))
        // }
        // loadData() // Optionally call loadData immediately, or let View trigger it.
    }

    // MARK: - Core Logic
    func loadData() {
        isLoading.accept(true)
        statusMessage.accept("Loading users...") // More generic message for initial load

        if NetworkChecker.shared.isConnectedToInternet { // Assuming NetworkChecker.shared exists
            let group = DispatchGroup()
            var anErrorOccurred = false

            group.enter()
            fb.loadVector { [weak self] (vectors, error) in // Assuming fb.loadVector exists
                defer { group.leave() }
                if let error = error {
                    print("Error loading kMean vectors: \(error.localizedDescription)")
                    anErrorOccurred = true
                    return
                }
                self?.kMeanVectorsList = vectors
                
                // Save to local data (Realm)
                do {
                    let realm = try Realm() // Access Realm instance
                    try realm.write {
                        realm.deleteAll() // Or more specific deletion
                        for vector in vectors {
                             // Assuming vectorHelper has a method to convert/save, or do it directly
                             // For example, if VectorObject is a Realm class:
                             // let vectorObj = VectorObject(from: vector)
                             // realm.add(vectorObj, update: .modified)
                             // This part depends on how VectorHelper and Realm objects are structured
                             // For now, let's assume vectorHelper can handle it or it's done directly
                             vectorHelper.saveVector(vector) // Assuming this saves to Realm
                        }
                    }
                } catch {
                    print("Error saving vectors to Realm: \(error.localizedDescription)")
                    anErrorOccurred = true
                }
            }

            group.enter()
            fb.loadUsers(completionHandler: { [weak self] (users, error) in // Assuming fb.loadUsers exists
                defer { group.leave() }
                if let error = error {
                    print("Error loading users: \(error.localizedDescription)")
                    anErrorOccurred = true
                    return
                }
                self?.userDictionary = users
                // Potentially save users to Realm if needed, similar to vectors
            })
            
            group.notify(queue: .main) { [weak self] in
                guard let self = self else { return }
                self.isLoading.accept(false)
                if anErrorOccurred {
                    self.statusMessage.accept("Error loading data from Firebase. Using local data if available.")
                    self.loadFromLocalRealm() // Fallback to local
                } else {
                    self.updateVectorsLabelText()
                    self.statusMessage.accept("Data loaded successfully from Firebase.")
                }
            }
        } else {
            // Offline: Load from Realm
            loadFromLocalRealm()
        }
    }
    
    private func loadFromLocalRealm() {
        do {
            let realm = try Realm()
            let result = realm.objects(SavedVector.self) // Assuming SavedVector is the Realm object
            self.kMeanVectorsList = [] // Clear before loading
            for vectorObject in result {
                // Convert SavedVector to Vector if necessary
                // This depends on the structure of SavedVector and Vector
                let v = Vector(name: vectorObject.name, vector: stringToArray(string: vectorObject.vector), distance: vectorObject.distance)
                self.kMeanVectorsList.append(v)
            }
            // Also load userDict from Realm if it's stored there
            // For example:
            // let userObjects = realm.objects(UserObject.self)
            // self.userDictionary = ... convert userObjects ...

            self.updateVectorsLabelText()
            if self.kMeanVectorsList.isEmpty { // Check if anything was loaded
                 self.statusMessage.accept("No internet. No local data found.")
            } else {
                 self.statusMessage.accept("No internet. Using local data.")
            }
        } catch {
            print("Error loading data from Realm: \(error.localizedDescription)")
            self.kMeanVectorsList = []
            self.userDictionary = [:]
            self.updateVectorsLabelText()
            self.statusMessage.accept("Error accessing local data.")
        }
        self.isLoading.accept(false) // Ensure isLoading is false after trying local load
    }

    private func updateVectorsLabelText() {
        // Original logic: vectorsLabel.text = "You have \(kMeanVectors.count / NUMBER_OF_K) users."
        // This implies kMeanVectors count is related to user count by a factor of NUMBER_OF_K
        // Or, it might be "You have \(userDictionary.count) users and \(kMeanVectorsList.count) vectors."
        // Let's use a more direct representation based on available data for clarity
        
        // Ensure NUMBER_OF_K is not zero to avoid division by zero
        var calculatedUserCount = 0
        if NUMBER_OF_K > 0 {
            calculatedUserCount = kMeanVectorsList.count / NUMBER_OF_K
        }
        
        let userCount = userDictionary.count > 0 ? userDictionary.count : calculatedUserCount
        vectorsLabelText.accept("Users: \(userCount), Vectors: \(kMeanVectorsList.count)")
    }


    // MARK: - Lifecycle Forwarded Methods
    func handleViewWillAppear() {
        // Logic for 'current' image if it's a global or accessible
        if let cgImg = current { // 'current' is the global CGImage? from original VC
            displayImage.accept(UIImage(cgImage: cgImg))
        }
    }

    func handleViewDidAppear() {
        fnet.clean() // Assuming fnet is accessible (global/singleton)
    }

    func handleViewWillDisappear() {
        fnet.load() // Assuming fnet is accessible (global/singleton)
    }

    // MARK: - User Action Handlers
    func syncDataTriggered() {
        loadData() // Re-load data when sync is triggered
    }

    func navigationButtonTapped(target: NavigationTarget) {
        navigationEvent.accept(target)
    }
}

// Note: The global variables/singletons like 'current', 'fnet', 'fb', 'realm', 
// 'vectorHelper', 'NetworkChecker', 'NUMBER_OF_K', 'SavedVector', 'stringToArray'
// are assumed to be defined elsewhere and accessible, matching the context of the original HomeViewController.
// If 'SavedVector' or other Realm objects are used, their definitions must exist.
// If 'stringToArray' is a global function, it must be defined.
// Ensure 'Vector' struct/class is defined as expected by this ViewModel.
// Minimal 'Vector' for this context:
// struct Vector {
//     var name: String
//     var vector: [Double] // Or whatever type stringToArray returns
//     var distance: Double // Or whatever type is appropriate
// }
// Minimal 'SavedVector' Realm Object (ensure this is defined in your Realm setup):
// class SavedVector: Object {
//     @Persisted var name: String = ""
//     @Persisted var vector: String = "" // Assuming stringToArray converts this
//     @Persisted var distance: Double = 0.0
// }
// Globals that need to be accessible:
// var current: CGImage? 
// let fnet: FaceNet // instance
// let fb: FirebaseManager // instance
// let vectorHelper: VectorHelper // instance
// let NetworkChecker: NetworkChecker // instance with .shared
// let NUMBER_OF_K: Int
// func stringToArray(string: String) -> [Double] // Or appropriate type
```
