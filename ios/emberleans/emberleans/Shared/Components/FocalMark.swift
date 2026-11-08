import SwiftUI

/// Geometria do símbolo "Ponto focal": lente biconvexa (interseção de dois círculos de
/// raio 60 com centros a 60 unidades) e o ponto focal (raio 16, a 13 unidades da lente).
/// Mesma construção de `design/source/symbol.py`.
nonisolated enum FocalMarkGeometry {
    static let circleRadius: CGFloat = 60
    static let centerDistance: CGFloat = 60
    static let dotRadius: CGFloat = 16
    static let gap: CGFloat = 13

    static var lensWidth: CGFloat { 2 * circleRadius - centerDistance }
    static var lensHeight: CGFloat {
        2 * sqrt(circleRadius * circleRadius - (centerDistance / 2) * (centerDistance / 2))
    }
    static var totalWidth: CGFloat { lensWidth + gap + 2 * dotRadius }
    /// Distância horizontal do centro da lente ao centro do ponto focal.
    static var dotOffset: CGFloat { lensWidth / 2 + gap + dotRadius }

    /// Lente centrada em `center`, na escala indicada.
    static func lensPath(center: CGPoint, scale: CGFloat) -> Path {
        let radius = circleRadius * scale
        let half = centerDistance * scale / 2
        let left = Path(ellipseIn: CGRect(x: center.x - half - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        let right = Path(ellipseIn: CGRect(x: center.x + half - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
        return left.intersection(right)
    }

    static func circle(center: CGPoint, radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    }
}

/// Símbolo proprietário do EmberLens.
struct FocalMarkSymbol: View {
    var lensColor: Color = Palette.brandInk
    var dotColor: Color = .accentColor

    var body: some View {
        Canvas { context, size in
            let g = FocalMarkGeometry.self
            let scale = min(size.width / g.totalWidth, size.height / g.lensHeight)
            let originX = (size.width - g.totalWidth * scale) / 2
            let lensCenter = CGPoint(x: originX + g.lensWidth * scale / 2, y: size.height / 2)
            context.fill(g.lensPath(center: lensCenter, scale: scale), with: .color(lensColor))
            let dotCenter = CGPoint(x: lensCenter.x + g.dotOffset * scale, y: lensCenter.y)
            context.fill(g.circle(center: dotCenter, radius: g.dotRadius * scale), with: .color(dotColor))
        }
        .aspectRatio(FocalMarkGeometry.totalWidth / FocalMarkGeometry.lensHeight, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Marca da barra de navegação: símbolo + nome.
struct BrandMark: View {
    @ScaledMetric(relativeTo: .headline) private var symbolHeight: CGFloat = 21

    var body: some View {
        HStack(spacing: Spacing.xs) {
            FocalMarkSymbol()
                .frame(height: symbolHeight)
            Text("EmberLens")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("EmberLens")
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    VStack(spacing: 24) {
        FocalMarkSymbol().frame(height: 120)
        BrandMark()
    }
    .padding()
}
