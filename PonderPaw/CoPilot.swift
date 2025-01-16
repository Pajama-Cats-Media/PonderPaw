import Foundation
import GameplayKit
import RxSwift

class CoPilot {
    public let stateMachine: GKStateMachine
    public var pages: [[String: Any]] = []
    // PublishSubject to broadcast subtitle events
    public let subtitleEvent = PublishSubject<SubtitleEvent>()
    public let pageCompletionEvent = PublishSubject<Int>()
    
    private let disposeBag = DisposeBag()
    private var readingObservable: Observable<Void>?
    private var hasCompleted = false // Flag to prevent redundant logs
    private let readActionHandler = ReadActionHandler() // ReadActionHandler instance
    
    // Define constants for wait times
    private let INITIAL_WAIT_TIME: TimeInterval = 5.0
    private let PAGE_DELAY_TIME: TimeInterval = 2.0
    private let ACTION_DELAY_TIME: TimeInterval = 3.0
    private let READ_GAP_TIME: TimeInterval = 0.2
    
    private let conversationalAIViewModel: ConversationalAIViewModel
    
    init(conversationalAIViewModel:ConversationalAIViewModel) {
        self.conversationalAIViewModel = conversationalAIViewModel
        
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
        log.info("JSON manifest loaded. \(pages.count) pages found.")
        
        // Create the observable chain for reading
        let initialDelay = Observable<Void>.just(())
            .delay(.seconds(5), scheduler: MainScheduler.instance)
        
        readingObservable = Observable.from(pages.enumerated())
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                return self.processPage(page, index: index)
            }
            .do(onSubscribe: {
                log.info("Reading started...")
            }, onDispose: { [weak self] in
                self?.markCompletion()
            })
    }
    
    func startReading() {
        guard let observable = readingObservable else {
            log.error("No reading observable available. Ensure JSON is loaded before starting.")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + INITIAL_WAIT_TIME) {
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
        
        return Observable.just(())
            .do(onNext: {
                log.info("Start to play Page \(index + 1)...")
            })
            .concatMap { [weak self] in
                guard let self = self else { return Observable<Void>.empty() }
                if let actions = page["actions"] as? [[String: Any]], !actions.isEmpty {
                    return self.processActions(actions)
                        .do(onDispose: {
                            log.info("Completed all actions for Page \(index + 1).")
                            self.pageCompletionEvent.onNext(index + 1) // Emit page completion event
                        })
                } else {
                    log.info("No actions for Page \(index + 1). Moving to the next page.")
                    self.pageCompletionEvent.onNext(index + 1) // Emit page completion event for empty page
                    return Observable.empty()
                }
            }
    }
    
    private func processActions(_ actions: [[String: Any]]) -> Observable<Void> {
        if stateMachine.canEnterState(ActionState.self) {
            stateMachine.enter(ActionState.self)
            logStateChange()
        }
        
        log.info("Processing \(actions.count) actions sequentially...")
        
        return Observable.from(actions.enumerated())
            .concatMap { index, action -> Observable<Void> in
                return self.performAction(action)
                    .do(onSubscribe: {
                        if let type = action["type"] as? String {
                            log.info("Started Action \(index + 1): [Type: \(type.uppercased())]")
                        } else {
                            log.error("Started Action \(index + 1): [Invalid action data]")
                        }
                    }, onDispose: {
                        log.info("Completed Action \(index + 1).")
                    })
            }
            .do(
                onSubscribe: {
                    log.info("Started processing actions sequentially...")
                },
                onDispose: {
                    log.info("All actions completed.")
                }
            )
    }
    
    private func performAction(_ action: [String: Any]) -> Observable<Void> {
        guard let type = action["type"] as? String else {
            log.error("Action has no type. Skipping.")
            return Observable.empty()
        }
        
        if type == "read" {
            let content = action["content"] as? String ?? "No content provided"
            let isAudioEnabled = ((action["audio"] as? String)?.isEmpty == false)
            
            if let subtitle = action["subtitle"] as? [String: Any] {
                subtitleEvent.onNext(SubtitleEvent(subtitle: subtitle, content: content))
            } else {
                subtitleEvent.onNext(SubtitleEvent(subtitle: [:], content: content))
            }
            
            return readActionHandler.read(action: action)
                .delay(.milliseconds(Int(READ_GAP_TIME * 1000)), scheduler: MainScheduler.instance)
                .do(onCompleted: {
                    self.subtitleEvent.onNext(SubtitleEvent(subtitle: [:], content: ""))
                    print("One read action is completed!")
                })
            
        } else if type == "agent" {
            guard let maxTime = action["maxTime"] as? Int else {
                log.error("Agent action missing 'maxTime'. Skipping.")
                return Observable.empty()
            }
            
            return Observable<Void>.create { observer in
                log.info("Starting 'agent' action with a maximum time of \(maxTime) seconds.")
                let workItem = DispatchWorkItem {
                    log.info("Max time reached. Ending conversation.")
                    self.conversationalAIViewModel.endConversation()
                    observer.onCompleted()
                }
                
                // Start conversation
                self.conversationalAIViewModel.beginConversation()
                
                // Schedule work item to end conversation after maxTime
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(maxTime), execute: workItem)
                
                return Disposables.create {
                    // Ensure the workItem is canceled if disposed
                    workItem.cancel()
                    self.conversationalAIViewModel.endConversation()
                    log.info("'agent' action completed or disposed.")
                }
            }
        } else if type == "wait" {
            guard let length = action["length"] as? Int else {
                log.error("Wait action missing 'length'. Skipping.")
                return Observable.empty()
            }
            return Observable<Void>.create { observer in
                log.info("Wait action started for \(length) seconds.")
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(length)) {
                    log.info("Wait action completed after \(length) seconds.")
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        } else {
            return Observable<Void>.create { observer in
                DispatchQueue.global().asyncAfter(deadline: .now() + self.ACTION_DELAY_TIME) {
                    log.info("Completed Action: [Type: \(type.uppercased())]")
                    observer.onCompleted()
                }
                return Disposables.create()
            }
        }
    }
    
    
    private func markCompletion() {
        if !hasCompleted {
            log.info("All reading completed.")
            hasCompleted = true
            stateMachine.enter(FinishState.self)
            logStateChange()
        }
    }
    
    private func logStateChange() {
        guard let currentState = stateMachine.currentState else {
            log.error("State machine is not in a valid state.")
            return
        }
        log.info("Transitioned to state: \(type(of: currentState))")
    }
}
