import SwiftUI
import ElevenLabsSDK
import _Concurrency

class ConversationalAIViewModel: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var mode: ElevenLabsSDK.Mode = .listening
    @Published var status: ElevenLabsSDK.Status = .disconnected
    private let agentId = "HLMUtO9U983aGkr0QrE2"
    
    func beginConversation() {
        // Do nothing if already connected
        guard status != .connected else {
            log.info("AI Conversation already connected. No action taken.")
            return
        }
        Task {
            do {
                let config = ElevenLabsSDK.SessionConfig(agentId: agentId)
                var callbacks = ElevenLabsSDK.Callbacks()
                
                // Capture 'self' weakly to avoid retain cycle
                callbacks.onConnect = { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.status = .connected
                    }
                }
                callbacks.onDisconnect = { [weak self] in
                    DispatchQueue.main.async {
                        self?.status = .disconnected
                    }
                }
                callbacks.onMessage = { message, _ in
                    print(message)
                }
                callbacks.onError = { errorMessage, _ in
                    print("Error: \(errorMessage)")
                }
                callbacks.onStatusChange = { [weak self] newStatus in
                    DispatchQueue.main.async {
                        self?.status = newStatus
                    }
                }
                callbacks.onModeChange = { [weak self] newMode in
                    DispatchQueue.main.async {
                        self?.mode = newMode
                    }
                }
                callbacks.onVolumeUpdate = { [weak self] newVolume in
                    DispatchQueue.main.async {
                        self?.audioLevel = newVolume
                    }
                }
                
                self.conversation = try await ElevenLabsSDK.Conversation.startSession(config: config, callbacks: callbacks)
            } catch {
                print("Error starting AI conversation: \(error)")
            }
        }
    }
    
    func endConversation() {
        if status == .connected {
            Task {
                conversation?.endSession()
                conversation = nil
                DispatchQueue.main.async {
                    self.status = .disconnected
                }
                log.info("AI Conversation ended.")
            }
        } else {
            log.info("No active AI conversation to end.")
        }
    }
    
    private var conversation: ElevenLabsSDK.Conversation?
}
