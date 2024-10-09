//
//  GeminiServices.swift
//  bluemebot
//
//  Created by bluemeda on 09/10/24.
//

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
        let url = URI(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelName):generateContent?key=\(apiKey)")

        let generationConfig = GeminiRequest.GenerationConfig(
            temperature: 0.75,
            topK: 40,
            topP: 0.95,
            responseMimeType: "application/json",
            maxOutputTokens: 8192
        )

        let systemPrompt = self.promptConfig.getPrompt()
        let systemInstruction = GeminiRequest.SystemInstruction(
            parts: [
                GeminiRequest.SystemInstruction.Part(
                    text: systemPrompt)
            ],
            role: "user")

        let safetySettings: [GeminiRequest.SafetySetting] = [
            GeminiRequest.SafetySetting.init(
                category: "HARM_CATEGORY_HARASSMENT", threshold: "OFF"),
            GeminiRequest.SafetySetting.init(
                category: "HARM_CATEGORY_HATE_SPEECH", threshold: "OFF"),
            GeminiRequest.SafetySetting.init(
                category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "OFF"),
            GeminiRequest.SafetySetting.init(
                category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "OFF"),

        ]
        

        var requestMessages: [GeminiRequest.GeminiContent] = []

        for message in messages {
            requestMessages.append(
                GeminiRequest.GeminiContent(
                    parts: [GeminiRequest.GeminiContent.Part(
                        text: message.content)
                    ],
                    role: message.role
                )
            )
            
        }
        
        let requestBody = GeminiRequest(
            generationConfig: generationConfig,
            systemInstruction: systemInstruction,
            contents: requestMessages,
            safetySettings: safetySettings)
        
        // Make the POST request using the Vapor Client
        let response = try await client.post(
            url,
            headers: HTTPHeaders([
                ("Content-Type", "application/json")
            ]), content: requestBody)
        
        guard response.status == .ok else {
            throw Abort(
                .badRequest,
                reason:
                    "Failed to get a valid response from OpenAI. Status: \(response.status)"
            )
        }
        
        let responseBody = try response.content.decode(GeminiResponse.self)
        guard let message = responseBody.candidates.first?.content.parts.first?.text else {
            throw Abort(
                .badRequest, reason: "No message found in OpenAI response.")
        }

        return message
    }
}

struct GeminiRequest: Content {
    let generationConfig: GenerationConfig
    let systemInstruction: SystemInstruction
    let contents: [GeminiContent]
    let safetySettings: [SafetySetting]

    struct GenerationConfig: Content {
        let temperature: Double
        let topK: Int
        let topP: Double
        let responseMimeType: String
        let maxOutputTokens: Int
    }

    struct SystemInstruction: Content {
        let parts: [Part]
        let role: String

        struct Part: Content {
            let text: String
        }
    }

    struct GeminiContent: Content {
        let parts: [Part]
        let role: String

        struct Part: Content {
            let text: String
        }
    }

    struct SafetySetting: Content {
        let category: String
        let threshold: String
    }
}

struct GeminiResponse: Content {
    let candidates: [Candidate]
    let usageMetadata: UsageMetadata

    struct Candidate: Content {
        let content: GeminiContent
        let finishReason: String
        let avgLogprobs: Double

        struct GeminiContent: Content {
            let parts: [Part]
            let role: String

            struct Part: Content {
                let text: String
            }
        }
    }

    struct UsageMetadata: Content {
        let promptTokenCount: Int
        let candidatesTokenCount: Int
        let totalTokenCount: Int
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
