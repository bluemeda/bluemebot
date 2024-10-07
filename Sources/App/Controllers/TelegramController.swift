//
//  TelegramController.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Vapor
@preconcurrency import SwiftTelegramSdk

struct TelegramController: RouteCollection {
    
    let botActor: TGBotActor
    
    init(botActor: TGBotActor) {
        self.botActor = botActor
    }
    
    func boot(routes: RoutesBuilder) throws {
        routes.post("telegramWebHook", use: self.telegramWebHook)
    }
    
    @Sendable
    func telegramWebHook(_ req: Request) async throws -> Bool {
        let update: TGUpdate = try req.content.decode(TGUpdate.self)
        Task { await botActor.bot.dispatcher.process([update]) }
        return true
    }
}

    
