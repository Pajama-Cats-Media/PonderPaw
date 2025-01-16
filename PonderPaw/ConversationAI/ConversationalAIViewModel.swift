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
                
                callbacks.onConnect = { _ in self.status = .connected }
                callbacks.onDisconnect = { self.status = .disconnected }
                callbacks.onMessage = { message, _ in print(message) }
                callbacks.onError = { errorMessage, _ in print("Error: \(errorMessage)") }
                callbacks.onStatusChange = { newStatus in self.status = newStatus }
                callbacks.onModeChange = { newMode in self.mode = newMode }
                callbacks.onVolumeUpdate = { newVolume in self.audioLevel = newVolume }
                
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
                status = .disconnected
                log.info("AI Conversation ended.")
            }
        } else {
            log.info("No active AI conversation to end.")
        }
    }
    
    private var conversation: ElevenLabsSDK.Conversation?
}
