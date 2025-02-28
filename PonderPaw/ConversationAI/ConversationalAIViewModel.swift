import SwiftUI
import ElevenLabsSDK
import _Concurrency

class ConversationalAIViewModel: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var mode: ElevenLabsSDK.Mode = .listening
    @Published var status: ElevenLabsSDK.Status = .disconnected
    @Published var subtitle: String = ""
    
    private var conversation: ElevenLabsSDK.Conversation?
    private let agentId = "SZ3AaTQGuaVGyBINtz1Q"
    
    func beginConversation(initialPrompt:String, firstMessage:String, voiceId:String) {
        guard status != .connected else {
            log.info("AI Conversation already connected. No action taken.")
            return
        }
        
        Task {
            do {
                // Configure the agent with this prompt (and any other needed settings like language)
                // The prompt include necessary knowledge base for this conversationa s well
                let agentPrompt = ElevenLabsSDK.AgentPrompt(prompt: initialPrompt)
                // Configure the agent with this prompt (and any other needed settings like language)
                let agentConfig = ElevenLabsSDK.AgentConfig(prompt: agentPrompt, firstMessage: firstMessage)
                // Create an overrides object with the agent configuration
                let ttsConfig = ElevenLabsSDK.TTSConfig(voiceId: voiceId)
                let overrides = ElevenLabsSDK.ConversationConfigOverride(agent:agentConfig, tts: ttsConfig)
                // Prepare the session configuration with the overrides
                let config = ElevenLabsSDK.SessionConfig(agentId: self.agentId, overrides: overrides)
                var callbacks = ElevenLabsSDK.Callbacks()
                
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
                callbacks.onMessage = { [weak self] message, role in
                    print("\(role.rawValue): \(message)")
                    if role.rawValue == "ai" {
                        DispatchQueue.main.async {
                            self?.subtitle = message
                        }
                    } else {
                        DispatchQueue.main.async {
                            self?.subtitle = ""
                        }
                    }
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
                
                // Register client tools
                self.registerClientTools()
            } catch {
                print("Error starting conversation: \(error)")
            }
        }
    }
    
    func endConversation() {
        guard status == .connected else {
            log.info("No active AI conversation to end.")
            return
        }
        
        Task {
            conversation?.endSession()
            conversation = nil
            DispatchQueue.main.async {
                self.status = .disconnected
            }
            log.info("AI Conversation ended.")
        }
    }
    
    //    Not working yet
    private func registerClientTools() {
        guard let conversation = self.conversation else {
            print("Cannot register tools: Conversation not initialized.")
            return
        }
        
        var clientTools = ElevenLabsSDK.ClientTools()
        
        // Register the end_call tool
        clientTools.register("end_talk") { [weak self] _ async throws -> String? in
            guard let self = self else { return nil }
            print("end_talk tool invoked. Ending conversation.")
            self.endConversation()
            return nil
        }
        
    }
}
