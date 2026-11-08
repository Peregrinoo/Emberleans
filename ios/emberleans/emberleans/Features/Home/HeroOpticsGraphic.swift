import SwiftUI

/// Gráfico proprietário da Home: raios paralelos atravessam a lente e convergem no
/// ponto focal. Estático e decorativo (oculto do VoiceOver).
struct HeroOpticsGraphic: View {
    var body: some View {
        Canvas { context, size in
            draw(in: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let g = FocalMarkGeometry.self
        let lensHeight = min(size.height * 0.64, 190)
        let scale = lensHeight / g.lensHeight
        let center = CGPoint(x: size.width * 0.38, y: size.height / 2 + 4)
        let radius = g.circleRadius * scale
        let halfDistance = g.centerDistance * scale / 2
        let focal = CGPoint(x: center.x + g.dotOffset * scale + 6, y: center.y)
        let focalRadius = g.dotRadius * scale * 0.62

        let rayStyle = GraphicsContext.Shading.color(Palette.rayLine)
        let stroke = StrokeStyle(lineWidth: 1)

        for fraction in [-0.36, -0.18, 0.0, 0.18, 0.36] {
            let y = center.y + CGFloat(fraction) * lensHeight
            let dy = y - center.y
            let reach = sqrt(max(radius * radius - dy * dy, 0))
            // Borda esquerda da lente pertence ao círculo da direita, e vice-versa.
            let entryX = center.x + halfDistance - reach
            let exitX = center.x - halfDistance + reach

            var incoming = Path()
            incoming.move(to: CGPoint(x: 0, y: y))
            incoming.addLine(to: CGPoint(x: entryX, y: y))
            context.stroke(incoming, with: rayStyle, style: stroke)

            var converging = Path()
            converging.move(to: CGPoint(x: exitX, y: y))
            converging.addLine(to: focal)
            context.stroke(converging, with: rayStyle, style: stroke)
        }

        context.fill(g.lensPath(center: center, scale: scale), with: .color(Palette.lensFill))

        var axis = Path()
        axis.move(to: CGPoint(x: focal.x + focalRadius + 10, y: center.y))
        axis.addLine(to: CGPoint(x: size.width, y: center.y))
        context.stroke(axis, with: rayStyle, style: StrokeStyle(lineWidth: 1, dash: [2, 4]))

        context.fill(g.circle(center: focal, radius: focalRadius), with: .color(.accentColor))

        let label = context.resolve(Text("f").font(.caption2.italic()).foregroundStyle(.tertiary))
        context.draw(label, at: CGPoint(x: focal.x, y: focal.y + focalRadius + 16))
    }
}

#Preview {
    HeroOpticsGraphic().frame(height: 300)
}
