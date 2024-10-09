import Fluent
import FluentSQLiteDriver
import NIOSSL
@preconcurrency import SwiftTelegramSdk
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // Uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    app.logger.logLevel = .info

    // TELEGRAM BOT TOKEN
    guard let telegramBotToken = Environment.get("TELEGRAM_BOT_TOKEN") else {
        throw logAndAbort(
            app.logger,
            errorMessage: "Missing TELEGRAM_BOT_TOKEN environment variable")
    }

    // OPEN AI KEY
    guard let openAIKey = Environment.get("OPENAI_API_KEY") else {
        throw logAndAbort(
            app.logger,
            errorMessage: "Missing OPENAI_API_KEY environment variable")
    }

    // GEMINI API KEY
    guard let geminiApiKey = Environment.get("GEMINI_API_KEY") else {
        throw logAndAbort(
            app.logger,
            errorMessage: "Missing GEMINI_API_KEY environment variable")
    }

    // TELEGRAM CONNECTION TYPE
    let telegramMode = Environment.get("TELEGRAM_MODE") ?? "longpolling"  // Default to long polling

    // Check for valid mode and fetch webhook URL if in webhook mode
    guard
        let connectionType: TGConnectionType = try {
            if telegramMode == "webhook" {
                guard let webhookURL = Environment.get("WEBHOOK_URL"),
                    let url = URL(string: webhookURL)
                else {
                    throw logAndAbort(
                        app.logger,
                        errorMessage:
                            "Missing or invalid WEBHOOK_URL environment variable"
                    )
                }
                return .webhook(webHookURL: url)
            } else if telegramMode == "longpolling" {
                return .longpolling(
                    limit: nil, timeout: nil, allowedUpdates: nil)
            } else {
                return nil
            }
        }()
    else {
        throw logAndAbort(
            app.logger,
            errorMessage:
                "Invalid TELEGRAM_MODE value. Must be 'webhook' or 'longpolling'."
        )
    }

    // Initialize services
    let bot: TGBot = try await .init(
        connectionType: connectionType,
        tgClient: VaporTGClient(client: app.client),
        botId: telegramBotToken,
        log: app.logger
    )

    // System prompt config

    let yamlPath =
        app.directory.workingDirectory + "resources/system_prompts.yaml"

    guard let assistantName = Environment.get("ASSISTANT_NAME") else {
        throw logAndAbort(
            app.logger,
            errorMessage: "Missing ASSISTANT_NAME environment variable")
    }
    let promptConfig = try PromptConfig(
        yamlFile: yamlPath, assistantName: assistantName)

    // OpenAI
    let openAIService = OpenAIService(
        client: app.client,
        apiKey: openAIKey,
        promptConfig: promptConfig)
    app.openAIService = openAIService

    // Message Service
    let messageService = await MessageService(app: app)

    // Gemini AI
    let geminiService = GeminiService(
        client: app.client,
        apiKey: geminiApiKey,
        promptConfig: promptConfig)
    app.geminiService = geminiService

    guard let providerService = Environment.get("PROVIDER") else {
        throw logAndAbort(
            app.logger, errorMessage: "Missing PROVIDER environment variable")
    }

    app.databases.use(
        DatabaseConfigurationFactory.sqlite(.file("resources/db.sqlite")),
        as: .sqlite)
    app.migrations.add(CreateMessage())

    let providerName: ProviderProtocol

    if providerService == "GEMINI" {
        providerName = app.geminiService
    } else if providerService == "OPENAI" {
        providerName = app.openAIService
    } else {
        throw logAndAbort(
            app.logger,
            errorMessage: "Invalid PROVIDER value. Must be 'GEMINI' or 'OPENAI'."
        )
    }

    await app.botActor.setBot(bot)
    await DefaultBotHandlers.addHandlers(
        bot: app.botActor.bot, model: providerName,
        messageService: messageService, promptConfig: promptConfig)

    try await app.botActor.bot.start()
    try routes(app)
}

// Helper function to log errors and throw an abort
private func logAndAbort(_ logger: Logger, errorMessage: String) -> Abort {
    logger.error(Logger.Message(stringLiteral: errorMessage))
    return Abort(.internalServerError, reason: errorMessage)
}
