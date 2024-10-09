//
//  ProviderProtocol.swift
//  bluemebot
//
//  Created by bluemeda on 09/10/24.
//

import Foundation

protocol ProviderProtocol: Sendable {
    var providerName: String { get }
    func generateResponse(messages: [Message]) async throws -> String
}
