import CoreGraphics
import Foundation

/// Colours for the globe, as plain RGBA so the renderer stays Sendable.
struct GlobePalette: Sendable {
    var ocean    = (r: 0.07, g: 0.11, b: 0.20, a: 1.0)
    var land     = (r: 0.93, g: 0.89, b: 0.80, a: 1.0)     // countries you can play
    var inactive = (r: 0.42, g: 0.46, b: 0.54, a: 1.0)     // countries with no quiz yet
    var border   = (r: 0.47, g: 0.43, b: 0.37, a: 0.9)
    var inactiveBorder = (r: 0.30, g: 0.33, b: 0.40, a: 0.9)
    var selected = (r: 0.98, g: 0.45, b: 0.36, a: 1.0)
    var selectedBorder = (r: 1.0, g: 0.85, b: 0.78, a: 1.0)
    var discovered = (r: 0.99, g: 0.80, b: 0.38, a: 1.0)     // unlocked countries glow gold
    var discoveredBorder = (r: 0.80, g: 0.58, b: 0.15, a: 1.0)
}

/// Paints every country onto an equirectangular image (the classic flat world map),
/// which is then wrapped around the sphere. Re-run it whenever the selection changes.
struct GlobeTextureRenderer: Sendable {
    var width = 4096
    var height = 2048
    var palette = GlobePalette()
    /// Countries that have quiz content. Everything else is drawn grey.
    var playableIDs: Set<String> = Set(ContentLibrary.answerCountries.map(\.id))

    func render(countries: [Country], selectedID: String?, discoveredIDs: Set<String> = []) -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        ctx.setLineJoin(.round)

        ctx.setFillColor(color(palette.ocean))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw the selected country last so its border sits on top of its neighbours.
        let ordered = countries.filter { $0.id != selectedID } + countries.filter { $0.id == selectedID }
        for country in ordered {
            let isSelected = country.id == selectedID
            let isDiscovered = discoveredIDs.contains(country.id)
            let isPlayable = playableIDs.contains(country.id)
            let path = CGMutablePath()
            for rings in country.polygons {
                for ring in rings {
                    guard let first = ring.first else { continue }
                    path.move(to: point(first))
                    for c in ring.dropFirst() { path.addLine(to: point(c)) }
                    path.closeSubpath()
                }
            }
            ctx.addPath(path)
            let fill: (r: Double, g: Double, b: Double, a: Double)
            let stroke: (r: Double, g: Double, b: Double, a: Double)
            if isSelected {
                fill = palette.selected; stroke = palette.selectedBorder
            } else if isDiscovered {
                fill = palette.discovered; stroke = palette.discoveredBorder
            } else if isPlayable {
                fill = palette.land; stroke = palette.border
            } else {
                fill = palette.inactive; stroke = palette.inactiveBorder
            }
            ctx.setFillColor(color(fill))
            ctx.fillPath(using: .evenOdd)

            ctx.addPath(path)
            ctx.setStrokeColor(color(stroke))
            ctx.setLineWidth(isSelected ? 4 : 1.5)
            ctx.strokePath()
        }
        return ctx.makeImage()
    }

    // Core Graphics has its origin at the bottom-left, so latitude -90 is y = 0 and the
    // finished image has north at the top.
    private func point(_ c: Coordinate) -> CGPoint {
        CGPoint(x: (c.lon + 180) / 360 * Double(width),
                y: (c.lat + 90) / 180 * Double(height))
    }

    private func color(_ c: (r: Double, g: Double, b: Double, a: Double)) -> CGColor {
        CGColor(red: c.r, green: c.g, blue: c.b, alpha: c.a)
    }
}
