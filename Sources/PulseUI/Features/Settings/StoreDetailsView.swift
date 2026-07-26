// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse

struct StoreDetailsView: View {
    @StateObject private var viewModel = StoreDetailsViewModel()

    let source: Source
#if os(tvOS)
    private let onBack: (() -> Void)?

    init(source: Source, onBack: (() -> Void)? = nil) {
        self.source = source
        self.onBack = onBack
    }
#endif

    enum Source {
        /// Loads the info when the view appears on screen.
        case store(LoggerStore)
        /// Opens the info for the given archive.
        case archive(url: URL)
        /// Displays prefetched info.
        case info(LoggerStore.Info)
    }

    var body: some View {
#if os(tvOS)
        StoreDetailsTVView(viewModel: viewModel, onBack: onBack)
            .onAppear { viewModel.load(from: source) }
#else
        StoreDetailsContentsView(viewModel: viewModel)
            .onAppear { viewModel.load(from: source) }
            .inlineNavigationTitle("Store Details")
#endif
    }
}

#if os(tvOS)
private struct StoreDetailsTVView: View {
    @ObservedObject var viewModel: StoreDetailsViewModel
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Namespace private var focusNamespace

    var body: some View {
        detailsList
    }

    @ViewBuilder
    private var detailsList: some View {
        if #available(tvOS 17, *) {
            List {
                backButton
                titleHeader
                    .prefersDefaultFocus(true, in: focusNamespace)
                details
            }
            .contentMargins(.horizontal, 40, for: .scrollContent)
            .contentMargins(.top, 40, for: .scrollContent)
            .focusScope(focusNamespace)
        } else {
            List {
                backButton
                    .listRowInsets(EdgeInsets(top: 40, leading: 40, bottom: 8, trailing: 40))
                titleHeader
                    .prefersDefaultFocus(true, in: focusNamespace)
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                details
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
            .focusScope(focusNamespace)
        }
    }

    private var backButton: some View {
        Button("Back", action: goBack)
    }

    private var titleHeader: some View {
        Button(action: {}) {
            Text("Store Details")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var details: some View {
        if let error = viewModel.errorMessage {
            Button(action: {}) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load info")
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            if #available(tvOS 16, *), let info = viewModel.info {
                LoggerStoreSizeChart(info: info, sizeLimit: viewModel.storeSizeLimit)
                    .padding(.vertical)
                    .focusable()
            }
            ForEach(viewModel.sections, id: \.title) { section in
                Section {
                    sectionRow(section.title)
                    ForEach(section.items.enumerated().map(KeyValueRow.init)) { item in
                        Button(action: {}) {
                            InfoRow(title: item.title, details: item.details)
                        }
                    }
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

    private func goBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
        }
    }
}
#endif

 struct StoreDetailsContentsView: View {
     @ObservedObject var viewModel: StoreDetailsViewModel
     @Environment(\.store) var store
     var isShowingActions = true

     var body: some View {
         // important: zstack fixed infinite onAppear loop on iOS 14
         ZStack {
             if let error = viewModel.errorMessage {
                 PlaceholderView(imageName: "exclamationmark.circle", title: "Failed to load info", subtitle: error)
             } else {
                 form
             }
         }
     }

     @ViewBuilder
     private var form: some View {
         Form {
             if #available(iOS 16.0, tvOS 16.0, macOS 13.0, watchOS 9.0, *), let info = viewModel.info {
                 LoggerStoreSizeChart(info: info, sizeLimit: viewModel.storeSizeLimit)
#if os(tvOS)
                     .padding(.vertical)
                     .focusable()
#endif
#if os(macOS)
                     .padding(12)
#endif
             }
             ForEach(viewModel.sections, id: \.title) { section in
                 ConsoleSection(header: {
#if os(macOS)
                     SectionHeaderView(title: section.title)
#else
                     Text(section.title)
#endif
                 }, content: {
                     ForEach(section.items.enumerated().map(KeyValueRow.init)) { item in
                         InfoRow(title: item.title, details: item.details)
#if os(tvOS)
                             .focusable()
#endif
                     }
                 })
             }
#if os(macOS)
             if isShowingActions {
                 ConsoleSection(header: { EmptyView() }, content: {
                     HStack {
                         Button("Show in Finder") {
                             NSWorkspace.shared.activateFileViewerSelecting([store.storeURL])
                         }
                         if !(store.options.contains(.readonly)) {
                             Button("Remove Logs") {
                                 store.removeAll()
                             }
                         }
                     }
                 })
             }
#endif
         }
     }
 }

// MARK: - ViewModel

final class StoreDetailsViewModel: ObservableObject {
    @Published private(set) var storeSizeLimit: Int64?
    @Published private(set) var sections: [KeyValueSectionViewModel] = []
    @Published private(set) var info: LoggerStore.Info?
    @Published private(set) var errorMessage: String?

    func load(from source: StoreDetailsView.Source) {
        do {
            switch source {
            case .store(let store):
                loadInfo(for: store)
            case .archive(let storeURL):
                display(try LoggerStore.Info.make(storeURL: storeURL))
            case .info(let value):
                display(value)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadInfo(for store: LoggerStore) {
        do {
            let info = try store.info()
            if store === LoggerStore.shared {
                self.storeSizeLimit = store.configuration.sizeLimit
            }
            self.display(info)
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func display(_ info: LoggerStore.Info) {
        self.info = info
        self.sections = [
            makeSizeSection(for: info),
            makeInfoSection(for: info)
        ]
    }

    private func makeInfoSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        let device = info.deviceInfo
        let app = info.appInfo
        return KeyValueSectionViewModel(title: "App Info", color: .gray, items: [
            ("App", "\(app.name ?? "–") \(app.version ?? "–") (\(app.build ?? "–"))"),
            ("Device", "\(device.name) (\(device.systemName) \(device.systemVersion))")
        ])
    }

    private func makeSizeSection(for info: LoggerStore.Info) -> KeyValueSectionViewModel {
        KeyValueSectionViewModel(title: "Statistics", color: .gray, items: [
            ("Created", dateFormatter.string(from: info.creationDate)),
            ("Messages", info.messageCount.description),
            ("Requests", info.taskCount.description),
            ("Blobs Size", ByteCountFormatter.string(fromByteCount: info.blobsSize)),
            makeDecompressedRow(for: info),
        ].compactMap { $0 })
    }

    private func makeDecompressedRow(for info: LoggerStore.Info) -> (String, String?)? {
        if info.blobsDecompressedSize == info.blobsSize {
            return nil
        }
        return ("Blobs Size Decompressed", ByteCountFormatter.string(fromByteCount: info.blobsDecompressedSize))
    }
}

private let dateFormatter = DateFormatter(dateStyle: .medium, timeStyle: .medium)

#if DEBUG
struct StoreDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        StoreDetailsView(source: .store(.mock))
            .frame(width: 280)
    }
}
#endif
