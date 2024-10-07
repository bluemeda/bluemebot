//
//  PromptConfig.swift
//  bluemebot
//
//  Created by bluemeda on 07/10/24.
//

import Vapor
import Yams

struct PromptConfig {
    private let systemPrompts: [String: String]
    private let assistantName: String
    
    init(yamlFile: String, assistantName: String) throws {
        let yamlString = try String(contentsOfFile: yamlFile)
        let yamlData = try Yams.load(yaml: yamlString) as? [String: String] ?? [:]
        self.systemPrompts = yamlData
        self.assistantName = assistantName
    }
    
    func getPrompt() -> String {
        guard let prompt = self.systemPrompts[self.assistantName] else {
            let message = "No prompt found for \(self.assistantName). Please add it to the yaml file."
            fatalError(message)
        }
        return prompt
    }
    
    func getAssistantName() -> String {
        return self.assistantName
    }
}
