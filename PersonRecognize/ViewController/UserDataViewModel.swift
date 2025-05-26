import Foundation
import RxSwift
import RxCocoa

class UserDataViewModel {
    // MARK: - Properties
    let searchResult = BehaviorRelay<[[String: Int]]>(value: [])
    let disposeBag = DisposeBag()
    // selectedUserName can be removed if selection is handled by events.
    // However, if any internal logic in ViewModel needs to know the "current" user outside of an event stream, keep it.
    // For now, let's assume events are sufficient.
    // var selectedUserName: String = "" 
    private var userList = [[String: Int]]()

    // MARK: - State Relays for UI
    let isLoading = BehaviorRelay<Bool>(value: false)
    let statusMessage = PublishRelay<String>()
    let navigationEvent = PublishRelay<NavigationEvent>()
    let dialogEvent = PublishRelay<DialogEvent>()

    enum NavigationEvent {
        case toViewFace(name: String)
    }

    enum DialogEvent {
        case showAlert(title: String, message: String)
        case showOptionsForUser(userName: String, title: String) // Added
    }
    
    // MARK: - Input Relays
    let searchQuery = PublishRelay<String?>()

    init() {
        searchQuery
            .compactMap { $0 } 
            .subscribe(onNext: { [weak self] query in
                self?.filterUsers(query: query)
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Core Logic
    func fetchUsers() {
        isLoading.accept(true)
        statusMessage.accept("Loading Users...")
        // Simulate network call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            // Placeholder for actual Firebase call:
            // fb.loadUsers { result in ... }
            let mockUserDict = ["UserA": 1, "UserB": 2, "UserC": 3, "AnotherUser": 4, "TestUser": 5]
            self.userList = mockUserDict.map { [$0.key: $0.value] }
                .sorted { ($0.keys.first ?? "").lowercased() < ($1.keys.first ?? "").lowercased() }
            self.searchResult.accept(self.userList)
            self.statusMessage.accept(self.userList.isEmpty ? "No users found." : "Users loaded successfully.")
            self.isLoading.accept(false)
        }
    }

    private func filterUsers(query: String) {
        if query.isEmpty {
            searchResult.accept(userList)
        } else {
            let filteredList = userList.filter { userEntry in
                return userEntry.keys.first?.lowercased().contains(query.lowercased()) ?? false
            }
            searchResult.accept(filteredList)
        }
    }

    func generateVector(for userName: String) {
        isLoading.accept(true)
        statusMessage.accept("Processing \(userName)...")
        // Placeholder for actual generation logic:
        // vectorHelper.generateAndSaveVector(userName: userName) { result in ... }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            // Simulate vector existence check or generation process
            let mockVectorExists = false // or true to test other path
            if mockVectorExists {
                self.statusMessage.accept("\(userName) vector data already exists.")
                self.dialogEvent.accept(.showAlert(title: "Info", message: "\(userName) vector data already exists."))
            } else {
                self.statusMessage.accept("Vector for \(userName) generated successfully.")
                // Potentially trigger navigation or other success action
                self.dialogEvent.accept(.showAlert(title: "Success", message: "Vector for \(userName) generated."))
            }
            self.isLoading.accept(false)
        }
    }

    // MARK: - User Interaction Handling
    func handleUserSelection(at index: Int) {
        guard index >= 0 && index < searchResult.value.count else {
            dialogEvent.accept(.showAlert(title: "Error", message: "Invalid selection."))
            return
        }
        let selectedData = searchResult.value[index]
        guard let userName = selectedData.keys.first else {
            dialogEvent.accept(.showAlert(title: "Error", message: "User data is malformed."))
            return
        }
        // self.selectedUserName = userName // Update if needed for other ViewModel logic
        dialogEvent.accept(.showOptionsForUser(userName: userName, title: "Select Action"))
    }

    func navigateToViewFace(userName: String) {
        // This function provides a clear action for the VC to call from the alert
        navigationEvent.accept(.toViewFace(name: userName))
    }
    
    func generateAllVectors() {
        // Placeholder for "Generate All" functionality
        // This would involve iterating through userList and calling generateVector for each.
        // Complexities: managing multiple async operations, overall progress, error handling for individual users.
        // For now, just a message.
        statusMessage.accept("Generate All Vectors feature not yet implemented.")
        // Example:
        // isLoading.accept(true)
        // statusMessage.accept("Starting generation for all users...")
        // // ... loop through users, call generateVector ... manage progress ...
        // isLoading.accept(false)
        // statusMessage.accept("Finished generating all vectors.")
    }
}
