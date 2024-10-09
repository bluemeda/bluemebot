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
    
    func addMessage(chatID: Int64,
                    role: String,
                    content: String,
                    assistant: String,
                    provider: String
    ) async throws {
        let newMessage = Message(chatID: chatID,
                                 role: role,
                                 content: content,
                                 assistant: assistant,
                                 provider: provider
        )
        try await newMessage.save(on: self.app.db)

        let messageCount = try await Message.query(on: self.app.db)
            .filter(\.$chatID == chatID)
            .filter(\.$provider == provider)
            .filter(\.$assistant == assistant)
            .count()

        if messageCount > 10 {
            let extraMessages = try await Message.query(on: self.app.db)
                .filter(\.$chatID == chatID)
                .filter(\.$provider == provider)
                .filter(\.$assistant == assistant)
                .sort(\.$createdAt, .ascending)
                .limit(messageCount - 10)
                .all()

            for message in extraMessages {
                try await message.delete(on: self.app.db)
            }
        }
    }
    
    func getLatestMessages(for chatID: Int64, assistant: String) async throws -> [Message] {
        let thirtyMinutesAgo = Date().addingTimeInterval(-30 * 60)
        
        let messages = try await Message.query(on: self.app.db)
            .filter(\.$chatID == chatID)
            .filter(\.$assistant == assistant)
            .filter(\.$createdAt >= thirtyMinutesAgo)
            .sort(\.$createdAt, .descending)
            .limit(10)
            .all()

        return messages.reversed()
    }
}

