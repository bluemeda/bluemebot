//
//  Message.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Fluent
import Vapor

final class Message: Model, @unchecked Sendable {
    static let schema = "messages"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "chat_id")
    var chatID: Int64
    
    @Field(key: "role")
    var role: String
    
    @Field(key: "content")
    var content: String
    
    @Field(key: "assistant")
    var assistant: String
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, chatID: Int64, role: String, content: String, assistant: String) {
        self.id = id
        self.chatID = chatID
        self.role = role
        self.content = content
        self.assistant = assistant
    }

}
