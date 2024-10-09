//
//  CreateMessage.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Fluent

struct CreateMessage: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("messages")
            .id()
            .field("chat_id", .int64, .required)
            .field("role", .string, .required)
            .field("content", .string, .required)
            .field("assistant", .string, .required)
            .field("created_at", .datetime, .required)
            .field("provider", .string)
            .create()
    }


    func revert(on database: Database) async throws {
        try await database.schema("messages").delete()
    }

}
