// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation
import SwiftUI
import Pulse
import CoreData

@available(iOS 15, macOS 13, visionOS 1.0, *)
struct ConsoleEntityCell: View {
    let entity: NSManagedObject

    var body: some View {
        switch LoggerEntity(entity) {
        case .message(let message):
            _ConsoleMessageCell(message: message)
#if os(macOS)
                .listRowSeparator(.visible)
                .frame(height: 42, alignment: .top)
#endif
        case .task(let task):
            _ConsoleTaskCell(task: task)
#if os(macOS)
                .listRowSeparator(.visible)
                .frame(height: 42, alignment: .top)
#endif
        }
    }
}

@available(iOS 15, macOS 13, visionOS 1.0, *)
private struct _ConsoleMessageCell: View {
    let message: LoggerMessageEntity

    @State private var shareItems: ShareItems?
    @Environment(\.router) private var router

    var body: some View {
#if os(iOS) || os(visionOS)
        let cell = ConsoleMessageCell(message: message, isDisclosureNeeded: true)
            .background(NavigationLink("", destination: ConsoleMessageDetailsView(message: message)).opacity(0))
#elseif os(macOS)
        let cell = ConsoleMessageCell(message: message)
            .tag(ConsoleSelectedItem.entity(message.objectID))
#elseif os(tvOS)
        let cell = Button {
            router.selectedObjectID = message.objectID
        } label: {
            ConsoleMessageCell(message: message)
        }
#else
        // `id` is a workaround for macOS (needs to be fixed)
        let cell = NavigationLink(destination: ConsoleMessageDetailsView(message: message)) {
            ConsoleMessageCell(message: message)
        }
#endif

#if os(iOS) || os(macOS) || os(visionOS)
        cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
#if os(macOS)
            PinButton(viewModel: .init(message), isSwipeAction: true).tint(.gray)
#else
            PinButton(viewModel: .init(message), isTextNeeded: false).tint(.pink)
#endif
        }
#if os(iOS) || os(visionOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: { shareItems = ShareService.share(message, as: .html) }) {
                Label("Share", systemImage: "square.and.arrow.up.fill")
            }.tint(.blue)
        }
#endif
        .contextMenu {
            ContextMenu.MessageContextMenu(message: message, shareItems: $shareItems)
        }
#if os(iOS) || os(visionOS)
        .sheet(item: $shareItems, content: ShareView.init)
#else
        .popover(item: $shareItems, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareView($0) }
#endif
#else
        cell
#endif
    }
}

@available(iOS 15, macOS 13, visionOS 1.0, *)
private struct _ConsoleTaskCell: View {
    let task: NetworkTaskEntity
    @State private var shareItems: ShareItems?
    @State private var sharedTask: NetworkTaskEntity?
    @Environment(\.store) private var store
    @Environment(\.router) private var router
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
#if os(iOS) || os(visionOS)
        let cell = ConsoleTaskCell(task: task, isDisclosureNeeded: true)
            .background(NavigationLink("", destination: inspector).opacity(0))
#elseif os(macOS)
        let cell = ConsoleTaskCell(task: task)
            .tag(ConsoleSelectedItem.entity(task.objectID))
#elseif os(tvOS)
        let cell = Button {
            router.selectedObjectID = task.objectID
        } label: {
            ConsoleTaskCell(task: task)
        }
#else
        let cell = NavigationLink(destination: inspector) {
            ConsoleTaskCell(task: task)
        }
#endif

#if os(iOS) || os(macOS) || os(visionOS)
        cell.swipeActions(edge: .leading, allowsFullSwipe: true) {
            if task.isConnection {
#if os(macOS)
                ConnectionPinButton(task: task, isSwipeAction: true).tint(.gray)
#else
                ConnectionPinButton(task: task, isTextNeeded: false).tint(.pink)
#endif
            } else {
#if os(macOS)
                PinButton(viewModel: .init(task), isSwipeAction: true).tint(.gray)
#else
                PinButton(viewModel: .init(task), isTextNeeded: false).tint(.pink)
#endif
            }
        }
#if os(iOS) || os(visionOS)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: {
                shareItems = ShareService.share(task, as: .html, store: store)
            }) {
                Label("Share", systemImage: "square.and.arrow.up.fill")
            }.tint(.blue)
        }
#endif
        .contextMenu {
            // Use connection-specific context menu for connections
            if task.isConnection {
#if os(iOS) || os(visionOS)
                ContextMenu.ConnectionContextMenuItems(task: task, sharedItems: $shareItems)
#else
                ContextMenu.ConnectionContextMenuItems(task: task)
#endif
            } else {
#if os(iOS) || os(visionOS)
                ContextMenu.NetworkTaskContextMenuItems(task: task, sharedItems: $shareItems)
#else
                ContextMenu.NetworkTaskContextMenuItems(task: task, sharedTask: $sharedTask)
#endif
            }
        }
#if os(iOS) || os(visionOS)
        .sheet(item: $shareItems, content: ShareView.init)
#else
        .popover(item: $sharedTask, attachmentAnchor: .point(.leading), arrowEdge: .leading) { ShareNetworkTaskView(task: $0) }
#endif
#else
        cell
#endif
    }

    @ViewBuilder
    private var inspector: some View {
        // We don't own NavigationView, so we have to inject the dependencies
        // Route to ConnectionInspectorView for TCP/UDP connections
#if os(tvOS)
        if environment.mode == .connection || isTVOSConnection {
            ConnectionInspectorView(task: task)
                .injecting(environment)
        } else {
            NetworkInspectorView(task: task)
                .injecting(environment)
        }
#else
        if task.isConnection {
            ConnectionInspectorView(task: task)
                .injecting(environment)
        } else {
            NetworkInspectorView(task: task)
                .injecting(environment)
        }
#endif
    }

#if os(tvOS)
    private var isTVOSConnection: Bool {
        if task.isConnection ||
            task.originalRequest?.headers["Connection-ID"] != nil ||
            task.originalRequest?.headers["Connection-Network"] != nil ||
            task.response?.headers["Connection-Upload"] != nil {
            return true
        }
        let scheme = URL(string: task.url ?? "")?.scheme?.lowercased()
        return scheme == "tcp" || scheme == "udp"
    }
#endif
}
