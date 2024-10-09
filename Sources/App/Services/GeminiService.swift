//
//  GeminiServices.swift
//  bluemebot
//
//  Created by bluemeda on 09/10/24.
//

import GoogleGenerativeAI
import Vapor

final class GeminiService: ProviderProtocol {
    let providerName: String = "GEMINI"
    
    private let client: Client
    private let apiKey: String
    private let promptConfig: PromptConfig

    init(client: Client, apiKey: String, promptConfig: PromptConfig) {
        self.client = client
        self.apiKey = apiKey
        self.promptConfig = promptConfig
    }

    // Define a struct for the request body
    struct RequestBody: Content {
        let contents: Contents

        struct Contents: Content {
            let role: String
            let parts: TextParts

            struct TextParts: Content {
                let text: String
            }
        }
    }

    // Method to generate a response from OpenAI
    func generateResponse(messages: [Message]) async throws -> String {
        let modelName = "gemini-1.5-flash-002"

        let config = GenerationConfig(
            temperature: 0.75,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 8192,
            responseMIMEType: "text/plain"
        )

        let systemPrompt = self.promptConfig.getPrompt()

        let safetySettings: [SafetySetting] = [
            SafetySetting(
                harmCategory: .dangerousContent, threshold: .blockNone),
            SafetySetting(harmCategory: .harassment, threshold: .blockNone),
            SafetySetting(harmCategory: .hateSpeech, threshold: .blockNone),
            SafetySetting(
                harmCategory: .sexuallyExplicit, threshold: .blockNone),
        ]

        let model = GenerativeModel(
            name: modelName,
            apiKey: self.apiKey,
            generationConfig: config,
            safetySettings: safetySettings,
            systemInstruction: systemPrompt
        )

        var requestMessages: [ModelContent] = []

        for message in messages.dropLast() {
            requestMessages.append(
                ModelContent(
                    role: message.role, parts: [.text(message.content)])
            )
        }

        let chat = model.startChat(history: requestMessages)

        Task {
            do {
                let message = messages.last?.content
                let response = try await chat.sendMessage(message ?? "")
                print(response.text ?? "No response received")
                return response.text
            } catch {
                print(error)
            }
            return ""
        }
        return ""
    }
}

extension Application {
    private struct GeminiServiceKey: StorageKey {
        typealias Value = GeminiService
    }

    var geminiService: GeminiService {
        get {
            guard let service = storage[GeminiServiceKey.self] else {
                fatalError("GeminiService not configured")
            }
            return service
        }
        set {
            storage[GeminiServiceKey.self] = newValue
        }
    }
}
