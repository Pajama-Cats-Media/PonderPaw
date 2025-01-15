import Foundation
import GameplayKit
import RxSwift

class CoPilot {
    public let stateMachine: GKStateMachine
    public var pages: [[String: Any]] = []
    public let subtitleEvent = PublishSubject<SubtitleEvent>()
    public var currentPage: Int = -1 // Tracks the current page
    public var currentAction: [String: Any]? // Tracks the current action
    
    private let disposeBag = DisposeBag()
    private var readingObservable: Observable<Void>?
    private var hasCompleted = false
    private let readActionHandler = ReadActionHandler()
    
    private var isPaused = false // Flag to check if CoPilot is paused
    private let pauseSubject = PublishSubject<Void>() // Used to pause and resume actions

    private let INITIAL_WAIT_TIME: TimeInterval = 5.0
    private let PAGE_DELAY_TIME: TimeInterval = 2.0
    private let ACTION_DELAY_TIME: TimeInterval = 3.0
    private let READ_GAP_TIME: TimeInterval = 0.2
    
    init() {
        let startState = StartState()
        let pageReadyState = PageReadyState()
        let actionState = ActionState()
        let finishState = FinishState()
        
        stateMachine = GKStateMachine(states: [startState, pageReadyState, actionState, finishState])
        stateMachine.enter(StartState.self)
        logStateChange()
    }
    
    func loadJson(jsonManifest: String) {
        guard let data = jsonManifest.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let playbook = parsed["playbook"] as? [String: Any],
              let pages = playbook["pages"] as? [[String: Any]] else {
            fatalError("Invalid JSON manifest.")
        }
        
        self.pages = pages
        print("JSON manifest loaded. \(pages.count) pages found.")
        
        readingObservable = Observable.from(pages.enumerated())
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                self.currentPage = index
                return self.processPage(page, index: index)
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + INITIAL_WAIT_TIME) {
            observable
                .subscribe()
                .disposed(by: self.disposeBag)
        }
    }
    
    func stop() {
        isPaused = true
        pauseSubject.onNext(())
        print("CoPilot has been paused.")
    }
    
    func resume() {
        guard isPaused, let currentAction = currentAction else {
            print("Cannot resume. Either not paused or no current action.")
            return
        }
        isPaused = false
        print("Resuming current action...")
        performAction(currentAction)
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
        
        return Observable.from(actions.enumerated())
            .concatMap { [weak self] index, action -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                self.currentAction = action
                return self.performAction(action)
            }
            .do(
                onSubscribe: {
                    print("Started processing actions...")
                },
                onDispose: {
                    print("All actions completed.")
                }
            )
    }
    
    private func performAction(_ action: [String: Any]) -> Observable<Void> {
        guard let type = action["type"] as? String else {
            print("Action has no type. Skipping.")
            return Observable.empty()
        }
        
        if type == "read" {
            let content = action["content"] as? String ?? "No content provided"
            
            if let subtitle = action["subtitle"] as? [String: Any] {
                subtitleEvent.onNext(SubtitleEvent(subtitle: subtitle, content: content))
            }
            
            // Use a replayable observable to allow resuming the action from where it was paused
            let playbackObservable = readActionHandler.read(action: action)
                .delay(.milliseconds(Int(READ_GAP_TIME * 1000)), scheduler: MainScheduler.instance)
                .replay(1) // Replay the last emitted value to resume from where it left off
            
            // Connect the observable to start the playback
            let connectable = playbackObservable.connect()
            pauseSubject
                .asObservable()
                .take(1) // Wait for the first pause signal
                .subscribe(onNext: { _ in
                    connectable.dispose() // Dispose the current playback to pause
                })
                .disposed(by: disposeBag)
            
            return playbackObservable
                .do(onDispose: {
                    print("Completed 'read' action: \(content)")
                })
        } else {
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
