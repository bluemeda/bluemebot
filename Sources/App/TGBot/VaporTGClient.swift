//
//  VaporTGClient.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import SwiftTelegramSdk
import Vapor

public enum TGHTTPMediaType: String, Equatable {
    case formData
    case json
}

private struct TGEmptyParams: Encodable {}

public final class VaporTGClient: TGClientPrtcl {
    public var log: Logging.Logger = .init(label: "VaporTGClient")
    public typealias HTTPMediaType = SwiftTelegramSdk.HTTPMediaType
    private let client: Vapor.Client

    public init(client: Vapor.Client) {
        self.client = client
    }

    @discardableResult
    public func post<Params: Encodable, Response: Decodable>(
        _ url: URL,
        params: Params?,
        as mediaType: SwiftTelegramSdk.HTTPMediaType?
    ) async throws -> Response {


        let clientResponse: ClientResponse = try await client.post(
            URI(string: url.absoluteString), headers: HTTPHeaders()
        ) { clientRequest in
            if mediaType == .formData || mediaType == nil {
                let boundary = "Boundary-\(UUID().uuidString)"
                clientRequest.headers.add(
                    name: .contentType,
                    value: "multipart/form-data; boundary=\(boundary)")

                if let currentParams = params {
                    let multipartData = try FormDataEncoder().encode(
                        currentParams, boundary: boundary)
                    clientRequest.body = ByteBuffer(string: multipartData)
                } else {
                    let multipartData = try FormDataEncoder().encode(
                        TGEmptyParams(), boundary: boundary)
                    clientRequest.body = ByteBuffer(string: multipartData)
                }
            } else {
                let mediaType: Vapor.HTTPMediaType =
                    if let mediaType {
                        .init(
                            type: mediaType.type, subType: mediaType.subType,
                            parameters: mediaType.parameters)
                    } else {
                        .json
                    }

                try clientRequest.content.encode(
                    params ?? TGEmptyParams() as! Params, as: mediaType)
            }
        }

        let telegramContainer: TGTelegramContainer = try clientResponse.content
            .decode(TGTelegramContainer<Response>.self)
        return try processContainer(telegramContainer)
    }

    @discardableResult
    public func post<Response: Decodable>(_ url: URL) async throws -> Response {
        try await post(url, params: TGEmptyParams(), as: nil)
    }

    private func processContainer<T: Decodable>(
        _ container: TGTelegramContainer<T>
    ) throws -> T {
        guard container.ok else {
            let desc = """
                Response marked as `not Ok`, it seems something wrong with request
                Code: \(container.errorCode ?? -1)
                \(container.description ?? "Empty")
                """
            let error = BotError(
                type: .server,
                description: desc
            )
            log.error(error.logMessage)
            throw error
        }

        guard let result = container.result else {
            let error = BotError(
                type: .server,
                reason:
                    "Response marked as `Ok`, but doesn't contain `result` field."
            )
            log.error(error.logMessage)
            throw error
        }

        let logString = """

            Response:
            Code: \(container.errorCode ?? 0)
            Status OK: \(container.ok)
            Description: \(container.description ?? "Empty")

            """
        log.trace(logString.logMessage)
        return result
    }

    
}
