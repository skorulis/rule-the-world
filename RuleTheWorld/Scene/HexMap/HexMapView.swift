import MapKit
import SwiftUI

struct HexMapView: View {
    @State var model: HexMapViewModel

    var body: some View {
        MapReader { proxy in
            Map(position: $model.cameraPosition) {
                ForEach(model.tiles) { tile in
                    MapPolygon(coordinates: tile.boundary)
                        .foregroundStyle(fill(for: tile))
                        .stroke(stroke(for: tile), lineWidth: 1)
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .onMapCameraChange(frequency: .onEnd) { context in
                model.cameraChanged(context.region)
            }
            .onTapGesture { position in
                if let coordinate = proxy.convert(position, from: .local) {
                    model.tapped(coordinate: coordinate)
                }
            }
            .overlay(alignment: .top) {
                HexMapHUD(
                    resolution: model.displayedResolution,
                    tileCount: model.tiles.count,
                    lastTappedCell: model.lastTappedCell,
                    showGrid: $model.showGrid
                )
            }
        }
    }

    private func fill(for tile: HexTile) -> Color {
        if let color = tile.state.color {
            return color.opacity(0.45)
        }
        return .clear
    }

    private func stroke(for tile: HexTile) -> Color {
        if let color = tile.state.color {
            return color
        }
        return model.showGrid ? .gray.opacity(0.6) : .clear
    }
}
