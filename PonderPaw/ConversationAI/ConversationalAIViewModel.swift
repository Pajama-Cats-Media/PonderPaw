import ElevenLabsSDK
import SwiftUI
import _Concurrency

class ConversationalAIViewModel: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var mode: ElevenLabsSDK.Mode = .listening
    @Published var status: ElevenLabsSDK.Status = .disconnected
    @Published var subtitle: String = ""

    private var conversation: ElevenLabsSDK.Conversation?
    private let agentId = "SZ3AaTQGuaVGyBINtz1Q"

    // Method to combine initial prompt with knowledge base
    private func createEnhancedPrompt(
        initialPrompt: String, knowledge: [String: Any]
    ) -> String {
        // Convert the knowledge dictionary to a readable string format
        let knowledgeDescription = knowledge.map { "\($0.key): \($0.value)" }
            .joined(separator: "\n")

        // Enhance the prompt with explicit instructions to use the knowledge base
        let enhancedPrompt = """
            \(initialPrompt)

            Knowledge Base:
            \(knowledgeDescription)

            Instructions: Use the information provided in the Knowledge Base to answer any questions or provide relevant information during this conversation.
            """

        return enhancedPrompt
    }

    func beginConversation(
        initialPrompt: String, firstMessage: String, voiceId: String,
        knowledge: [String: Any]
    ) {
        guard status != .connected else {
            log.info("AI Conversation already connected. No action taken.")
            return
        }

        // Create the enhanced prompt using the dedicated method
        let enhancedPrompt = createEnhancedPrompt(
            initialPrompt: initialPrompt, knowledge: knowledge)

        Task {
            do {
                // Configure the agent with this prompt (and any other needed settings like language)
                // The prompt include necessary knowledge base for this conversationa s well
                let agentPrompt = ElevenLabsSDK.AgentPrompt(
                    prompt: enhancedPrompt)
                // Configure the agent with this prompt (and any other needed settings like language)
                let agentConfig = ElevenLabsSDK.AgentConfig(
                    prompt: agentPrompt, firstMessage: firstMessage)
                // Create an overrides object with the agent configuration
                let ttsConfig = ElevenLabsSDK.TTSConfig(voiceId: voiceId)
                let overrides = ElevenLabsSDK.ConversationConfigOverride(
                    agent: agentConfig, tts: ttsConfig)
                // Prepare the session configuration with the overrides
                let config = ElevenLabsSDK.SessionConfig(
                    agentId: self.agentId, overrides: overrides)
                var callbacks = ElevenLabsSDK.Callbacks()

                // Create client tools instance
                var clientTools = ElevenLabsSDK.ClientTools()

                // Register a custom tool with an async handler
                clientTools.register("generic_tool") {
                    parameters async throws -> String? in
                    // Parameters is a [String: Any] dictionary
                    print("generic_tool received: \(parameters)")

                    // Check for the "summary" key; if it's not present, return immediately.
                    guard let summary = parameters["summary"] as? String else {
                        return nil
                    }

                    let title = "Notification"

                    print("notification message: \(summary)")

                    // Use the summary as the body of the notification
                    NotificationManager.shared.scheduleNotification(
                        title: title, body: summary)

                    return "done"
                }

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

                self.conversation = try await ElevenLabsSDK.Conversation
                    .startSession(
                        config: config, callbacks: callbacks,
                        clientTools: clientTools)

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
}
