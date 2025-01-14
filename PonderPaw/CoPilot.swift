import Foundation
import GameplayKit
import RxSwift

class CoPilot {
    public let stateMachine: GKStateMachine
    public var pages: [[String: Any]] = []
    private let disposeBag = DisposeBag()
    private var readingObservable: Observable<Void>?
    private var hasCompleted = false // Flag to prevent redundant logs
    private let readActionHandler = ReadActionHandler() // ReadActionHandler instance
    
    // Define constants for wait times
    private let INITIAL_WAIT_TIME: TimeInterval = 5.0
    private let PAGE_DELAY_TIME: TimeInterval = 2.0
    private let ACTION_DELAY_TIME: TimeInterval = 3.0
    
    init() {
        // Initialize FSM states
        let startState = StartState()
        let pageReadyState = PageReadyState()
        let actionState = ActionState()
        let finishState = FinishState()
        
        stateMachine = GKStateMachine(states: [startState, pageReadyState, actionState, finishState])
        
        // Enter the initial state
        stateMachine.enter(StartState.self)
        logStateChange()
    }
    
    func loadJson(jsonManifest: String) {
        // Parse JSON
        guard let data = jsonManifest.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playbook = parsed["playbook"] as? [String: Any],
              let pages = playbook["pages"] as? [[String: Any]] else {
            fatalError("Invalid JSON manifest.")
        }
        
        self.pages = pages
        print("JSON manifest loaded. \(pages.count) pages found.")
        
        // Create the observable chain for reading
        let initialDelay = Observable<Void>.just(())
            .delay(.seconds(5), scheduler: MainScheduler.instance) // Wait for 5 seconds
        
        
        readingObservable = Observable.from(pages.enumerated())
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                return self.processPage(page, index: index) // Process actions within the page
            }
            .do(onSubscribe: {
                print("Reading started after initial wait...")
            }, onDispose: { [weak self] in
                self?.markCompletion()
            })
    }
    
    func startReading() {
        guard let observable = readingObservable else {
            print("No reading observable available. Ensure JSON is loaded before starting.")
            return
        }
        
        // Add delay before starting the subscription
        // Add delay using DispatchQueue
        DispatchQueue.main.asyncAfter(deadline: .now() + INITIAL_WAIT_TIME) {
            // Subscribe to the observable after the delay
            observable
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
    
    private func processPage(_ page: [String: Any], index: Int) -> Observable<Void> {
        if stateMachine.canEnterState(PageReadyState.self) {
            stateMachine.enter(PageReadyState.self)
            logStateChange()
            (stateMachine.currentState as? PageReadyState)?.configure(with: page)
        }
        
        print("Processing Page \(index + 1)...")
        
        return Observable.just(())
            .concatMap { [weak self] in
                guard let self = self else { return Observable<Void>.empty() }
                if let actions = page["actions"] as? [[String: Any]], !actions.isEmpty {
                    return self.processActions(actions)
                        .do(onDispose: {
                            print("Completed all actions for Page \(index + 1).")
                        })
                } else {
                    print("No actions for Page \(index + 1). Moving to the next page.")
                    return Observable.empty()
                }
            }
    }
    
    private func processActions(_ actions: [[String: Any]]) -> Observable<Void> {
        if stateMachine.canEnterState(ActionState.self) {
            stateMachine.enter(ActionState.self)
            logStateChange()
        }

        AppLogger.shared.logInfo(category: "playbook", message: "Processing \(actions.count) actions sequentially...")

        // Ensure each action is processed sequentially using concatMap
        return Observable.from(actions.enumerated())
            .concatMap { index, action -> Observable<Void> in
                // Perform the action
                return self.performAction(action)
                    .do(onSubscribe: {
                        if let type = action["type"] as? String, let content = action["content"] as? String {
                            AppLogger.shared.logInfo(category: "playbook", message: "Started Action \(index + 1): [Type: \(type.uppercased()), Content: \(content)]")
                        } else {
                            AppLogger.shared.logError(category: "playbook", message: "Started Action \(index + 1): [Invalid action data]")
                        }
                    }, onDispose: {
                        AppLogger.shared.logInfo(category: "playbook", message: "Completed Action \(index + 1).")
                    })
            }
            .do(
                onSubscribe: {
                    AppLogger.shared.logInfo(category: "playbook", message: "Started processing actions sequentially...")
                },
                onDispose: {
                    AppLogger.shared.logInfo(category: "playbook", message: "All actions completed.")
                }
            )
    }
    
    
    private func performAction(_ action: [String: Any]) -> Observable<Void> {
        guard let type = action["type"] as? String else {
            print("Action has no type. Skipping.")
            return Observable.empty()
        }
        
        if type == "read" {
            // Extract content and audio usage details for logging
            let content = action["content"] as? String ?? "No content provided"
            let isAudioEnabled = ((action["audio"] as? String)?.isEmpty == false)
            
            // Use the readActionHandler and ensure it completes properly
            return readActionHandler.read(action: action)
        } else {
            // Simulate a delay for other actions
            return Observable<Void>.create { observer in
                DispatchQueue.global().asyncAfter(deadline: .now() + self.ACTION_DELAY_TIME) {
                    print("Completed Action: [Type: \(type.uppercased())]")
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
    }
    
    
    private func markCompletion() {
        if !hasCompleted {
            print("Reading completed.")
            hasCompleted = true
            stateMachine.enter(FinishState.self)
            logStateChange()
        }
    }
    
    private func logStateChange() {
        guard let currentState = stateMachine.currentState else {
            print("State machine is not in a valid state.")
            return
        }
        print("Transitioned to state: \(type(of: currentState))")
    }
}
