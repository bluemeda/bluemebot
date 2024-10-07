//
//  OpenAIService.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Vapor

final class OpenAIService: Sendable {
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
        let model: String
        let messages: [Message]
        let max_completion_tokens: Int?
        let temperature: Double?

        struct Message: Content {
            let role: String
            let content: String
        }
    }

    // Method to generate a response from OpenAI
    func generateResponse(messages: [Message]) async throws -> String {
        let url = URI(string: "https://api.openai.com/v1/chat/completions")
        let systemPrompt = promptConfig.getPrompt()

        var requestMessages: [RequestBody.Message] = [
            RequestBody.Message(role: "system", content: systemPrompt)
        ]

        for message in messages {
            requestMessages.append(
                RequestBody.Message(
                    role: message.role, content: message.content))
        }

        // Create the request body
        let requestBody = RequestBody(
                    model: "gpt-4o-mini",
                    messages: requestMessages,
                    max_completion_tokens: 500,
                    temperature: 0.7
                )   

        // Make the POST request using the Vapor Client
        let response = try await client.post(
            url,
            headers: HTTPHeaders([
                ("Authorization", "Bearer \(apiKey)"),
                ("Content-Type", "application/json"),
            ]), content: requestBody)

        // Check for successful response
        guard response.status == .ok else {
            throw Abort(
                .badRequest,
                reason:
                    "Failed to get a valid response from OpenAI. Status: \(response.status)"
            )
        }

        // Parse the response to extract the message
        let responseBody = try response.content.decode(OpenAIResponse.self)
        guard let message = responseBody.choices.first?.message.content else {
            throw Abort(
                .badRequest, reason: "No message found in OpenAI response.")
        }

        return message
    }
}

// Response model for decoding OpenAI API response
struct OpenAIResponse: Content {
    struct Choice: Content {
        let message: Message
    }

    struct Message: Content {
        let role: String
        let content: String
    }

    let choices: [Choice]
}

extension Application {
    private struct OpenAIServiceKey: StorageKey {
        typealias Value = OpenAIService
    }

    var openAIService: OpenAIService {
        get {
            guard let service = storage[OpenAIServiceKey.self] else {
                fatalError("OpenAIService not configured")
            }
            return service
        }
        set {
            storage[OpenAIServiceKey.self] = newValue
        }
    }
}
