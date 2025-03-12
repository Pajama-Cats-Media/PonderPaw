//
//  CoPilot.swift
//  PonderPaw
//
//  Created by Homer Quan on 2/10/25.
//

import Foundation
import GameplayKit
import RxSwift
import Combine

class CoPilot {
    public let stateMachine: GKStateMachine
    public var pages: [[String: Any]] = []
    public var sharedKnowledge: [String: Any] = [:]
    
    // PublishSubjects for events
    public let subtitleEvent = PublishSubject<SubtitleEvent>()
    public let pageCompletionEvent = PublishSubject<Int>()
    
    private let disposeBag = DisposeBag()
    private let skipAgentSubject = PublishSubject<Void>()
    private var readingDisposeBag = DisposeBag() // DisposeBag for managing reading
    private var readingObservable: Observable<Void>?
    
    private var hasCompleted = false
    private let readActionHandler: ReadActionHandler
    
    private let INITIAL_WAIT_TIME: TimeInterval = 1.0
    private let READ_GAP_TIME: TimeInterval = 0.25
    private let PAGE_GAP_TIME: TimeInterval = 0.5
    
    private let conversationalAIViewModel: ConversationalAIViewModel
    
    private var cancellables = Set<AnyCancellable>()
    
    // Pause/Resume mechanism
    private var pauseSubject = BehaviorSubject<Bool>(value: false)
    
    init(conversationalAIViewModel: ConversationalAIViewModel, storyFolder: URL?) {
        self.conversationalAIViewModel = conversationalAIViewModel
        
        self.readActionHandler = ReadActionHandler(storyFolder: storyFolder)
        
        let startState = StartState()
        let pageReadyState = PageReadyState()
        let actionState = ActionState()
        let finishState = FinishState()
        
        stateMachine = GKStateMachine(states: [startState, pageReadyState, actionState, finishState])
        stateMachine.enter(StartState.self)
        logStateChange()
    }
    
    func loadJson(jsonManifest: String) {
        
        guard let data = jsonManifest.data(using: .utf8) else {
            fatalError("Invalid JSON manifest: Failed to convert jsonManifest to Data.")
        }
        
        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            fatalError("Invalid JSON manifest: Failed to parse JSON.")
        }
        
        guard let meta = parsed["meta"] as? [String: Any] else {
            fatalError("Invalid JSON manifest: Missing or invalid 'meta' key.")
        }
        
        //        this one is optional
        let sharedKnowledge = (parsed["knowledge"] as? [String: Any]) ?? [:]
        
        guard let playbook = parsed["playbook"] as? [String: Any] else {
            fatalError("Invalid JSON manifest: Missing or invalid 'playbook' key.")
        }
        
        guard let pages = playbook["pages"] as? [[String: Any]] else {
            fatalError("Invalid JSON manifest: Missing or invalid 'pages' key in 'playbook'.")
        }
        
        log.info("JSON manifest loaded. \(pages.count) pages found.")
        log.info("shared knowledge. \(sharedKnowledge)")
        
        self.pages = pages
        self.sharedKnowledge = sharedKnowledge
        
        // Observable chain for reading with pause handling
        readingObservable = Observable.from(pages.enumerated())
            .concatMap { [weak self] index, page -> Observable<Void> in
                guard let self = self else { return Observable.empty() }
                
                return self.processPage(page, index: index)
                    .concat(Observable.empty().delay(.milliseconds(Int(PAGE_GAP_TIME * 1000)), scheduler: MainScheduler.instance))
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
        
        // Observe changes in status
        self.conversationalAIViewModel.$status
            .sink { newStatus in
                print("New Status changed to: \(newStatus)")
                if(newStatus == .disconnected){
                    print("skip agent action in conversation")
                    self.conversationalAIViewModel.endConversation()
                    self.skipAgentAction()
                }
            }
            .store(in: &cancellables)
        
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
        
        if stateMachine.canEnterState(StartState.self) {
            stateMachine.enter(StartState.self)
            logStateChange()
        }
        
        pageCompletionEvent.onCompleted()
        subtitleEvent.onCompleted()
    }
    
    func togglePause() -> Bool {
        do {
            let currentPauseState = try pauseSubject.value() // Get current pause state
            let newPauseState = !currentPauseState
            pauseSubject.onNext(newPauseState) // Emit new pause state
            let status = newPauseState ? "paused" : "resumed"
            log.info("Stream is now \(status).")
            return newPauseState
        } catch {
            log.error("Failed to toggle pause: \(error)")
            return false
        }
    }
    
    func skipAgentAction() {
        skipAgentSubject.onNext(())
    }
    
    private func processPage(_ page: [String: Any], index: Int) -> Observable<Void> {
        if stateMachine.canEnterState(PageReadyState.self) {
            stateMachine.enter(PageReadyState.self)
            logStateChange()
            (stateMachine.currentState as? PageReadyState)?.configure(with: page)
        }
        
        return Observable.just(())
            .do(onNext: {
                let newPage = index + 1
                log.info("Start to play Page \(newPage)...")
                // quick fix, conversation will break one event, fire another
                self.pageCompletionEvent.onNext(newPage)
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
        
        log.info("Processing Action type: \(type)")
        
        if type == "read" {
            let content = action["content"] as? String ?? "No content provided"
            
            return readActionHandler.read(action: action, pause: pauseSubject)
                .do(onSubscribe: {
                    if let subtitle = action["subtitle"] as? [String: Any] {
                        self.subtitleEvent.onNext(SubtitleEvent(subtitle: subtitle, content: content))
                    } else {
                        self.subtitleEvent.onNext(SubtitleEvent(subtitle: [:], content: content))
                    }
                })
                .delay(.milliseconds(Int(READ_GAP_TIME * 1000)), scheduler: MainScheduler.instance)
                .do(onCompleted: {
                    self.subtitleEvent.onNext(SubtitleEvent(subtitle: [:], content: ""))
                    print("One read action is completed!")
                })
            
        } else if type == "agent" {
            guard let maxTime = action["max_time"] as? Int else {
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
                if let prompt = action["prompt"] as? String,
                   let opening = action["opening"] as? String {
                    self.conversationalAIViewModel.beginConversation(initialPrompt: prompt, firstMessage: opening, voiceId: "gOkFV1JMCt0G0n9xmBwV", knowledge: self.sharedKnowledge)
                } else {
                    // Handle the case where the cast fails
                    print("Error: Unable to cast prompt or opening to String.")
                }
                
                // Schedule work item to end conversation after maxTime
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(maxTime), execute: workItem)
                
                // Observe skip event
                let skipSubscription = self.skipAgentSubject.subscribe(onNext: {
                    log.info("Skip triggered. Ending agent action early.")
                    // Execute the work item immediately without waiting
                    DispatchQueue.global().async(execute: workItem)
                    workItem.cancel()
                    observer.onCompleted()
                })
                
                return Disposables.create {
                    // Ensure the workItem is canceled if disposed
                    workItem.cancel()
                    skipSubscription.dispose()
                    self.conversationalAIViewModel.endConversation()
                    log.info("'agent' action completed or disposed.")
                }
            }
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
