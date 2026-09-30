import Foundation

extension Marketplace {
    /// Translate the bundled catalog's display text when it reaches the app. Protocol ids,
    /// server addresses, variable names, and the account's existing bots stay as stored.
    func localized() -> Marketplace {
        Marketplace(
            plugins: plugins.map { plugin in
                var result = plugin
                result.name = L(plugin.name)
                result.description = L(plugin.description)
                result.skills = plugin.skills.map { .init(name: L($0.name), description: L($0.description)) }
                result.variables = plugin.variables.map {
                    .init(name: $0.name, description: L($0.description), secret: $0.secret, required: $0.required)
                }
                return result
            },
            bots: bots.map { template in
                var result = template
                result.name = L(template.name)
                result.summary = L(template.summary)
                result.description = L(template.description)
                result.routines = template.routines.map {
                    .init(name: L($0.name), scheduleText: $0.scheduleText, prompt: L($0.prompt))
                }
                result.memory = template.memory.map { L($0) }
                return result
            })
    }
}
