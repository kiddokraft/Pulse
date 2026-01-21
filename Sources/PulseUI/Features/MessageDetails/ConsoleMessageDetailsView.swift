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
    var body: some View {
        contents
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
            KeyValueSectionViewModel(title: "Details", color: .primary, items: [
                ("File", message.file.isEmpty ? nil : message.file),
                ("Function", message.function.isEmpty ? nil : message.function),
                ("Line", message.line == 0 ? nil : "\(message.line)"),
            ]),
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
