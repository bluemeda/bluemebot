//
//  MessageService.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Vapor
import Fluent

@MainActor
final class MessageService {
    private let app: Application
    init(app: Application) {
        self.app = app
    }
    
    func addMessage(chatID: Int64, role: String, content: String, assistant: String) async throws {
        let newMessage = Message(chatID: chatID, role: role, content: content, assistant: assistant)
        try await newMessage.save(on: self.app.db)

        let messageCount = try await Message.query(on: self.app.db)
            .filter(\.$chatID == chatID)
            .count()

        if messageCount > 10 {
            let extraMessages = try await Message.query(on: self.app.db)
                .filter(\.$chatID == chatID)
                .sort(\.$createdAt, .ascending)
                .limit(messageCount - 10)
                .all()

            for message in extraMessages {
                try await message.delete(on: self.app.db)
            }
        }
    }
    
    func getLatestMessages(for chatID: Int64, assistant: String) async throws -> [Message] {
        let messages = try await Message.query(on: self.app.db)
            .filter(\.$chatID == chatID)
            .filter(\.$assistant == assistant)
            .sort(\.$createdAt, .descending)
            .limit(10)
            .all()

        return messages.reversed()
    }
}

