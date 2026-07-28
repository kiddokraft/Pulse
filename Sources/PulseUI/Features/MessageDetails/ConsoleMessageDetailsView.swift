// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if !PULSE_STANDALONE_APP

import SwiftUI
import Pulse

@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageDetailsView: View {
    let message: LoggerMessageEntity

#if os(iOS) || os(visionOS)
    var body: some View {
        contents
            .navigationBarTitle("", displayMode: .inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    trailingNavigationBarItems
                }
            }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
            Image(systemName: "info.circle")
        }
        PinButton(viewModel: .init(message), isTextNeeded: false)
    }
#elseif os(watchOS)
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                NavigationLink(destination: ConsoleMessageMetadataView(message: message)) {
                    Label("Details", systemImage: "info.circle")
                }
                contents
            }
        }
    }
#elseif os(tvOS)
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    var body: some View {
        detailsList
    }

    @ViewBuilder
    private var detailsList: some View {
        if #available(tvOS 17, *) {
            List {
                backButton
                titleHeader
                PinButton(viewModel: .init(message))
                details
            }
            .contentMargins(.horizontal, 40, for: .scrollContent)
            .contentMargins(.top, 40, for: .scrollContent)
        } else {
            List {
                backButton
                    .listRowInsets(EdgeInsets(top: 40, leading: 40, bottom: 8, trailing: 40))
                titleHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                PinButton(viewModel: .init(message))
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                details
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
        }
    }

    private var backButton: some View {
        Button("Back", action: goBack)
    }

    private var titleHeader: some View {
        Button(action: {}) {
            Text("Log Details")
                .font(.headline)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var details: some View {
        Section {
            sectionRow("Message")
            Button(action: {}) {
                Text(message.text)
                    .font(.body.monospaced())
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        Section {
            sectionRow("Summary")
            detailRow("Date", value: DateFormatter.fullDateFormatter.string(from: message.createdAt))
            detailRow("Level", value: LoggerStore.Level(rawValue: message.level)?.name)
            detailRow("Label", value: message.label.isEmpty ? nil : message.label)
        }

        Section {
            sectionRow("Details")
            detailRow("File", value: message.file.isEmpty ? nil : message.file)
            detailRow("Function", value: message.function.isEmpty ? nil : message.function)
            detailRow("Line", value: message.line == 0 ? nil : "\(message.line)")
        }

        if !message.metadata.isEmpty {
            Section {
                sectionRow("Metadata")
                ForEach(message.metadata.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                    detailRow(item.key, value: item.value)
                }
            }
        }
    }

    private func sectionRow(_ title: String) -> some View {
        Button(action: {}) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func detailRow(_ title: String, value: String?) -> some View {
        if let value, !value.isEmpty {
            Button(action: {}) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(value)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func goBack() {
        if router.selectedObjectID != nil {
            router.selectedObjectID = nil
        } else {
            dismiss()
        }
    }
#elseif os(macOS)
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            // Combined message and metadata in single text view
            RichTextView(viewModel: makeFullTextViewModel())
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Log Details")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            ButtonCloseDetailsView()
        }
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
    }

    private func makeFullTextViewModel() -> RichTextViewModel {
        // Create combined string: message text + metadata
        let combined = NSMutableAttributedString()

        // Message text
        let messageRenderer = TextRenderer()
        combined.append(messageRenderer.preformatted(message.text))
        combined.append(NSAttributedString(string: "\n\n"))

        // Metadata sections
        let metadataRenderer = TextRenderer()
        let sections = [
            KeyValueSectionViewModel(title: "Summary", color: .textColor(for: message.logLevel), items: [
                ("Date", DateFormatter.fullDateFormatter.string(from: message.createdAt)),
                ("Level", LoggerStore.Level(rawValue: message.level)?.name),
                ("Label", message.label.isEmpty ? nil : message.label)
            ]),
//            KeyValueSectionViewModel(title: "Details", color: .primary, items: [
//                ("File", message.file.isEmpty ? nil : message.file),
//                ("Function", message.function.isEmpty ? nil : message.function),
//                ("Line", message.line == 0 ? nil : "\(message.line)"),
//            ]),
            KeyValueSectionViewModel(title: "Metadata", color: .indigo, items: message.metadata.sorted(by: { $0.key < $1.key }).map { ($0.key, $0.value )})
        ]
        metadataRenderer.render(sections)
        combined.append(metadataRenderer.make())

        let viewModel = RichTextViewModel(string: combined)
        viewModel.isFilterEnabled = true
        return viewModel
    }
#endif

    private var contents: some View {
        VStack {
            RichTextView(viewModel: makeTextViewModel())
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func makeTextViewModel() -> RichTextViewModel {
        let viewModel = RichTextViewModel(string: TextRenderer().preformatted(message.text))
        viewModel.isFilterEnabled = true
        return viewModel
    }
}

#if DEBUG
@available(iOS 15, visionOS 1.0, *)
struct ConsoleMessageDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleMessageDetailsView(message: makeMockMessage())
        }
    }
}

func makeMockMessage() -> LoggerMessageEntity {
    let entity = LoggerMessageEntity(context: LoggerStore.mock.viewContext)
    entity.text = "test"
    entity.createdAt = Date()
    entity.label = "auth"
    entity.level = LoggerStore.Level.critical.rawValue
    entity.file = "LoggerStore.swift"
    entity.function = "createMockMessage()"
    entity.line = 12
    entity.rawMetadata = "customKey: customValue"
    return entity
}
#endif

#endif
