import Foundation

/// Formatação de valores exibidos ao usuário.
nonisolated enum ResultFormatting {
    /// "72%"; valores positivos menores que 0,5% aparecem como "<1%".
    static func percent(_ probability: Double) -> String {
        let clamped = min(max(probability, 0), 1)
        let rounded = Int((clamped * 100).rounded())
        if rounded == 0 && clamped > 0 { return "<1%" }
        return "\(rounded)%"
    }

    /// "18 ms"; durações abaixo de 1 ms aparecem como "<1 ms".
    static func milliseconds(_ duration: Duration) -> String {
        let components = duration.components
        let milliseconds = Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
        let rounded = Int(milliseconds.rounded())
        if rounded == 0 { return "<1 ms" }
        return "\(rounded) ms"
    }
}
