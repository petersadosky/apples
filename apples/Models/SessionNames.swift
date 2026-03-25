import Foundation

enum SessionNames {
    static let names = [
        "Espresso", "Mocha", "Latte", "Cappuccino", "Macchiato",
        "Americano", "Cortado", "Affogato",
        "Matcha", "Chai"
    ]

    static func random() -> String {
        names.randomElement() ?? "Espresso"
    }
}
