//
//  TGBotActor.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import SwiftTelegramSdk
import Vapor

actor TGBotActor {
    private var _bot: TGBot!

    var bot: TGBot {
        self._bot
    }
    
    func setBot(_ bot: TGBot) {
        self._bot = bot
    }
}

extension Application {
    struct TGBotActorKey: StorageKey {
        typealias Value = TGBotActor
    }

    var botActor: TGBotActor {
        get {
            guard let actor = self.storage[TGBotActorKey.self] else {
                fatalError("TGBotActor has not been initialized.")
            }
            return actor
        }
        set {
            self.storage[TGBotActorKey.self] = newValue
        }
    }
}
