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
        readingObservable = Observable.from(pages.enumerated()) // Process each page sequentially
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                return self.processPage(page, index: index) // Process actions within the page
            }
            .do(onSubscribe: {
                print("Reading started...")
            }, onDispose: { [weak self] in
                self?.markCompletion()
            })
    }
    
    func startReading() {
        guard let observable = readingObservable else {
            print("No reading observable available. Ensure JSON is loaded before starting.")
            return
        }
        
        // Subscribe to the observable to start processing
        observable
            .subscribe()
            .disposed(by: disposeBag)
    }
    
    private func processPage(_ page: [String: Any], index: Int) -> Observable<Void> {
        if stateMachine.canEnterState(PageReadyState.self) {
            stateMachine.enter(PageReadyState.self)
            logStateChange()
            (stateMachine.currentState as? PageReadyState)?.configure(with: page)
        }
        
        print("Processing Page \(index + 1)...")
        
        // Process actions for the page
        if let actions = page["actions"] as? [[String: Any]], !actions.isEmpty {
            return processActions(actions)
                .do(onDispose: {
                    print("Completed all actions for Page \(index + 1).")
                })
        } else {
            print("No actions for Page \(index + 1). Moving to the next page.")
            return Observable.empty()
        }
    }
    
    private func processActions(_ actions: [[String: Any]]) -> Observable<Void> {
        if stateMachine.canEnterState(ActionState.self) {
            stateMachine.enter(ActionState.self)
            logStateChange()
        }
        
        print("Processing \(actions.count) actions...")
        
        return Observable.from(actions.enumerated()) // Process each action sequentially
            .concatMap { index, action -> Observable<Void> in
                if let type = action["type"] as? String, let content = action["content"] as? String {
                    print("Processing Action \(index + 1): [Type: \(type.uppercased()), Content: \(content)]")
                } else {
                    print("Processing Action \(index + 1): [Invalid action data]")
                }
                return self.performAction(action)
            }
            .do(onSubscribe: {
                print("Action processing started.")
            }, onDispose: {
                print("Action processing completed.")
            })
    }
    
    private func performAction(_ action: [String: Any]) -> Observable<Void> {
        guard let type = action["type"] as? String else {
            return Observable.empty()
        }
        
        if type == "read" {
            return readActionHandler.read(action: action)
        } else {
            return Observable<Void>.create { observer in
                DispatchQueue.global().asyncAfter(deadline: .now() + 3) { // Simulate 3-second delay for other actions
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
