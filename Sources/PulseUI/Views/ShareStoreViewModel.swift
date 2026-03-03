// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(watchOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@MainActor final class ShareStoreViewModel: ObservableObject {
    // Sharing options
    @Published var sessions: Set<UUID> = []
    @Published var logLevels = Set(LoggerStore.Level.allCases)
    @Published var output: ShareStoreOutput

    @Published private(set) var isPreparingForSharing = false
    @Published private(set) var errorMessage: String?
    @Published var shareItems: ShareItems?

    var store: LoggerStore?

    init() {
        output = UserSettings.shared.sharingOutput
        sanitizeOutput()
    }

    func buttonSharedTapped() {
        guard !isPreparingForSharing else { return }
        isPreparingForSharing = true
        saveSharingOptions()
        prepareForSharing()
    }

    private func saveSharingOptions() {
        sanitizeOutput()
        UserSettings.shared.sharingOutput = output
    }

    private func sanitizeOutput() {
        switch output {
        case .text, .har:
            break
        default:
            output = .text
        }
    }

    func prepareForSharing() {
        guard let store = store else { return }

        isPreparingForSharing = true
        shareItems = nil
        errorMessage = nil

        Task {
            do {
                let options = LoggerStore.ExportOptions(predicate: predicate, sessions: sessions)
                self.shareItems = try await prepareForSharing(store: store, options: options)
            } catch {
                guard !(error is CancellationError) else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isPreparingForSharing = false
        }
    }

    var selectedLevelsTitle: String {
        if logLevels.count == 1 {
            return logLevels.first!.name.uppercased()
        } else if logLevels.count == 0 {
            return "–"
        } else if logLevels == [.error, .critical] {
            return "Errors"
        } else if logLevels == [.warning, .error, .critical] {
            return "Warnings & Errors"
        } else if logLevels.count == LoggerStore.Level.allCases.count {
            return "All"
        } else {
            return "\(logLevels.count)"
        }
    }

    private var predicate: NSPredicate? {
        var predicates: [NSPredicate] = []
        if logLevels != Set(LoggerStore.Level.allCases) {
            predicates.append(.init(format: "level IN %@", logLevels.map(\.rawValue)))
        }
        if !sessions.isEmpty {
            predicates.append(.init(format: "session IN %@", sessions))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func prepareForSharing(store: LoggerStore, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        sanitizeOutput()
        switch output {
        case .store:
            return try await prepareForSharing(store: store, output: .plainText, options: options)
        case .package:
            return try await prepareForSharing(store: store, output: .plainText, options: options)
        case .text, .html:
            return try await prepareForSharing(store: store, output: .plainText, options: options)
        case .har:
            return try await prepareForSharing(store: store, output: .har, options: options)
        }
    }

    private func prepareForSharing(store: LoggerStore, output: ShareOutput, options: LoggerStore.ExportOptions) async throws -> ShareItems {
        let entities = try await withUnsafeThrowingContinuation { continuation in
            store.backgroundContext.perform {
                let request = NSFetchRequest<LoggerMessageEntity>(entityName: "\(LoggerMessageEntity.self)")
                request.predicate = options.predicate // important: contains sessions

                let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: true)
                request.sortDescriptors = [sortDescriptor]

                let result = Result(catching: { try store.backgroundContext.fetch(request) })
                continuation.resume(with: result)
            }
        }
        return try await ShareService.share(entities, store: store, as: output)
    }
}

#endif
