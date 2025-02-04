import Foundation
import GameplayKit
import RxSwift

class CoPilot {
    public let stateMachine: GKStateMachine
    public var pages: [[String: Any]] = []
    
    // PublishSubjects for events
    public let subtitleEvent = PublishSubject<SubtitleEvent>()
    public let pageCompletionEvent = PublishSubject<Int>()
    
    private let disposeBag = DisposeBag()
    private var readingDisposeBag = DisposeBag() // DisposeBag for managing reading
    private var readingObservable: Observable<Void>?
    
    private var hasCompleted = false
    private let readActionHandler = ReadActionHandler()
    
    private let INITIAL_WAIT_TIME: TimeInterval = 5.0
    private let READ_GAP_TIME: TimeInterval = 0.2
    
    private let conversationalAIViewModel: ConversationalAIViewModel

    // Pause/Resume mechanism
    private var isPaused = false
    private let pauseSubject = PublishSubject<Void>()
    private let resumeSubject = PublishSubject<Void>()

    init(conversationalAIViewModel: ConversationalAIViewModel) {
        self.conversationalAIViewModel = conversationalAIViewModel
        
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
        log.info("JSON manifest loaded. \(pages.count) pages found.")

        // Observable chain for reading with pause handling
        readingObservable = Observable.from(pages.enumerated())
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                
                return self.processPage(page, index: index)
                    .flatMap { _ in
                        self.pauseSubject // Wait if paused
                            .take(1) // Wait for a single resume event
                            .flatMap { _ in Observable.just(()) }
                    }
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
        
        readingDisposeBag = DisposeBag() // Reset dispose bag for new reading session
        
        DispatchQueue.main.asyncAfter(deadline: .now() + INITIAL_WAIT_TIME) {
            observable
                .subscribe()
                .disposed(by: self.readingDisposeBag)
        }
    }
    
    func stopReading() {
        log.info("Stopping reading process...")

        readingDisposeBag = DisposeBag() // Dispose of all active observables
        
        hasCompleted = false
        isPaused = false // Ensure it resets

        if stateMachine.canEnterState(StartState.self) {
            stateMachine.enter(StartState.self)
            logStateChange()
        }

        pageCompletionEvent.onCompleted()
        subtitleEvent.onCompleted()
    }
    
    func togglePause() {
        if isPaused {
            log.info("Resuming reading process...")
            isPaused = false
            resumeSubject.onNext(())
        } else {
            log.info("Pausing reading process...")
            isPaused = true
            pauseSubject.onNext(())
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
                            self.pageCompletionEvent.onNext(index + 1)
                        })
                } else {
                    log.info("No actions for Page \(index + 1). Moving to the next page.")
                    self.pageCompletionEvent.onNext(index + 1)
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
                    .do(onDispose: {
                        log.info("Completed Action \(index + 1).")
                    })
            }
            .do(onDispose: {
                log.info("All actions completed.")
            })
    }
    
    private func performAction(_ action: [String: Any]) -> Observable<Void> {
        guard let type = action["type"] as? String else {
            log.error("Action has no type. Skipping.")
            return Observable.empty()
        }
        
        if type == "read" {
            let content = action["content"] as? String ?? "No content provided"
            
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
            
        } else {
            return Observable<Void>.create { observer in
                DispatchQueue.global().asyncAfter(deadline: .now() + 3.0) {
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
