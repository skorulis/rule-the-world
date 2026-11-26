import ASKCoordinator
import SwiftUI

struct BannerEditorView: View {
    @Environment(\.coordinator) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var model: BannerEditorViewModel
    private let ink = Color(red: 0.25, green: 0.12, blue: 0.04)

    var body: some View {
        @Bindable var model = model
        StandardListLayout("Banner Editor") {
            Section {
                preview
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            Section {
                ParchmentTabView(
                    tabs: BannerEditorViewModel.Tab.allCases,
                    selection: $model.selectedTab, title: \.rawValue
                ) {
                    switch model.selectedTab {
                    case .pattern: patternOptions
                    case .colors: colorOptions
                    case .emblem: emblemOptions
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            Section {
                if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(BannerColor.ivory.color)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { actions }
                    VStack(spacing: 12) { actions }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: model.draft)
        .sensoryFeedback(.selection, trigger: model.draft)
    }

    private var preview: some View {
        TitledParchmentPanel("Preview") {
            HStack(spacing: 12) {
                BannerView(configuration: model.draft)
                    .frame(maxWidth: .infinity)
                shuffleButton
                    .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var shuffleButton: some View {
        VStack(spacing: 6) {
            Button("Shuffle", systemImage: "dice.fill") { model.shuffle() }
                .buttonStyle(CircularIconButtonStyle())
                .accessibilityHint("Randomizes the draft banner without saving")
            Text("Shuffle")
                .font(.system(.headline, design: .serif, weight: .heavy))
                .foregroundStyle(ink)
                .accessibilityHidden(true)
        }
    }

    private var actions: some View {
        Group {
            Button("Cancel") { coordinator?.pop() }
            Button("Save") {
                if model.save() { coordinator?.pop() }
            }
            .accessibilityHint("Saves this banner on this device")
        }
        .buttonStyle(GoldButtonStyle(fillsWidth: true))
    }

    private var patternOptions: some View {
        VStack(spacing: 12) {
            heading("Background pattern")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(BannerPattern.allCases, id: \.self) { pattern in
                    Button {
                        model.draft.pattern = pattern
                    } label: {
                        VStack(spacing: 4) {
                            BannerView(configuration: thumbnail(pattern: pattern))
                                .frame(height: 74)
                                .accessibilityHidden(true)
                            Text(pattern.title).font(.caption.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        .overlay { selectionOutline(model.draft.pattern == pattern) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.draft.pattern == pattern ? [.isSelected] : [])
                }
            }
        }
        .foregroundStyle(ink)
    }

    private var colorOptions: some View {
        @Bindable var model = model
        return VStack(spacing: 20) {
            swatches("Background color", selection: $model.draft.backgroundColor)
            if model.draft.pattern != .solid {
                swatches("Pattern color", selection: $model.draft.patternColor)
            }
        }
    }

    private var emblemOptions: some View {
        @Bindable var model = model
        return VStack(spacing: 20) {
            heading("Emblem icon")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))], spacing: 12) {
                ForEach(BannerEmblem.allCases, id: \.self) { emblem in
                    Button {
                        model.draft.emblem = emblem
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle().fill(BannerColor.charcoal.color.gradient)
                                if emblem == .none {
                                    Image(systemName: "nosign")
                                        .font(.title2)
                                        .foregroundStyle(BannerColor.ivory.color)
                                } else {
                                    BannerEmblemShape(emblem: emblem)
                                        .fill(model.draft.emblemColor.color.gradient)
                                        .padding(12)
                                }
                            }
                            .frame(width: 60, height: 60)
                            .overlay { selectionOutline(model.draft.emblem == emblem) }
                            Text(emblem.title).font(.caption.bold())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(emblem.title)
                    .accessibilityAddTraits(model.draft.emblem == emblem ? [.isSelected] : [])
                }
            }
            if model.draft.emblem != .none {
                swatches("Emblem color", selection: $model.draft.emblemColor)
            }
        }
        .foregroundStyle(ink)
    }

    private func swatches(_ title: String, selection: Binding<BannerColor>) -> some View {
        VStack(spacing: 12) {
            heading(title)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 12) {
                ForEach(BannerColor.allCases, id: \.self) { color in
                    Button {
                        selection.wrappedValue = color
                    } label: {
                        Circle()
                            .fill(color.color.gradient)
                            .frame(width: 44, height: 44)
                            .overlay { Circle().strokeBorder(ink.opacity(0.7), lineWidth: 2) }
                            .overlay {
                                if selection.wrappedValue == color {
                                    Image(systemName: "checkmark")
                                        .font(.headline.bold())
                                        .foregroundStyle(.white)
                                        .shadow(color: .black, radius: 2)
                                }
                            }
                            .padding(3)
                            .overlay { selectionOutline(selection.wrappedValue == color) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title): \(color.title)")
                    .accessibilityAddTraits(selection.wrappedValue == color ? [.isSelected] : [])
                }
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.system(.title3, design: .serif, weight: .heavy))
            .foregroundStyle(ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func selectionOutline(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(selected ? ink : .clear, lineWidth: 3)
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(BannerColor.ivory.color, ink)
                        .offset(x: 3, y: -3)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func thumbnail(pattern: BannerPattern) -> BannerConfiguration {
        var banner = model.draft
        banner.pattern = pattern
        banner.emblem = .none
        return banner
    }
}
