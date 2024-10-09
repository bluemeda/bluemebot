//
//  DefaultBotHandlers.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Foundation
@preconcurrency import SwiftTelegramSdk
import Vapor

final class DefaultBotHandlers {

    static func addHandlers(
        bot: TGBot,
        model: ProviderProtocol,
        messageService: MessageService,
        promptConfig: PromptConfig
    ) async {
        await messageHandler(
            bot: bot,
            model: model,
            messageService: messageService,
            promptConfig: promptConfig)
        
        await commandStartHandler(bot: bot)
    }

    private static func messageHandler(
        bot: TGBot,
        model: ProviderProtocol,
        messageService: MessageService,
        promptConfig: PromptConfig
    )
        async
    {
        await bot.dispatcher.add(
            TGMessageHandler(filters: (.all && !.command.names(["/start"]))) {
                update in
                // Safely unwrap the incoming message
                guard let message = update.message else { return }

                // Prepare parameters for sending a message
                let userMessage = message.text ?? ""
                let chatID = message.chat.id
                let assistantName = promptConfig.getAssistantName()

                try await messageService.addMessage(
                    chatID: chatID,
                    role: "user",
                    content: userMessage,
                    assistant: promptConfig.getAssistantName(),
                    provider: model.providerName
                )

                let contextMessages =
                    try await messageService.getLatestMessages(
                        for: chatID, assistant: assistantName
                    )

                let openAIResponse = try await model.generateResponse(
                    messages: contextMessages
                )

                try await messageService.addMessage(
                    chatID: chatID,
                    role: "assistant",
                    content: openAIResponse,
                    assistant: assistantName,
                    provider: model.providerName
                )

                let sanitizedResponse = sanitizeText(openAIResponse)

                let params = TGSendMessageParams(
                    chatId: .chat(message.chat.id),
                    text: sanitizedResponse,
                    parseMode: .markdownV2
                )

                // Send the message asynchronously
                try await bot.sendMessage(params: params)
            })
    }

    private static func commandStartHandler(bot: TGBot) async {
        await bot.dispatcher.add(
            TGCommandHandler(commands: ["/start"]) { update in
                try await update.message?.reply(
                    text: "Selamat datang", bot: bot)
            })
    }

    private static func sanitizeText(_ input: String) -> String {
        // Define the characters to escape and their corresponding escape sequences
        let escapeChars: [Character] = [
            "\\", "`", ")", "_", "*", "[", "]", "(", "~", ">", "#", "+", "-",
            "=", "|", "{", "}", ".", "!",
        ]

        // Helper function to escape characters
        func escape(_ char: Character) -> String {
            return escapeChars.contains(char) ? "\\\(char)" : String(char)
        }

        // Use a StringBuilder (represented by an array here) for efficient string concatenation
        var sanitized = [String]()

        // Process each character in the input string
        for char in input {
            let escapedChar = escape(char)
            sanitized.append(escapedChar)
        }

        // Handle specific rules for italic/underline and custom emoji
        let result = sanitized.joined().replacingOccurrences(
            of: "__", with: "__**")  // Handle underline and italic ambiguity

        // Return the final sanitized result
        return result
    }

}
