// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment

    init(environment: ConsoleEnvironment) {
        _environment = StateObject(wrappedValue: environment)
    }

    public var body: some View {
        if #available(macOS 13, *) {
            NavigationStack {
                ConsoleMainView(environment: environment)
            }
            .injecting(environment)
            .navigationTitle("Console")
        } else {
            PlaceholderView(imageName: "xmark.octagon", title: "Unsupported", subtitle: "Pulse requires macOS 13 or later").padding()
        }
    }
}

/// This view contains the console itself along with the details (no sidebar).
@available(macOS 13, *)
@MainActor
private struct ConsoleMainView: View {
    let environment: ConsoleEnvironment

    @State private var isSharingStore = false
    @State private var isShowingFilters = false
    @State private var isShowingSessions = false
    @State private var isShowingSettings = false

    var body: some View {
        HSplitView {
            contentView.layoutPriority(1)
            detailsView
        }
    }

    private var contentView: some View {
        ConsoleListView()
            .frame(minWidth: 300, idealWidth: 600, minHeight: 120, idealHeight: 480)
//            .toolbar {
//                ToolbarItemGroup(placement: .automatic) {
//                    contentToolbarNavigationItems
//                }
//                ToolbarItemGroup(placement: .automatic) {
//                    Button(action: { isShowingFilters = true }) {
//                        Label("Filter", systemImage: "line.3.horizontal.decrease")
//                    }
//                    .popover(isPresented: $isShowingFilters) {
//                        ConsoleFiltersView()
//                            
//                            .frame(width: 500, height: 650)
//                    }
////                    Button(action: { isShowingSessions = true }) {
////                        Label("Show Sessions", systemImage: "tray.full")
////                    }
////                    .popover(isPresented: $isShowingSessions) {
////                        SessionsView().frame(width: 300, height: 420)
////                    }
////                    Button(action: { isShowingSettings = true }) {
////                        Label("More", systemImage: "ellipsis")
////                    }
////                    .popover(isPresented: $isShowingSettings) {
////                        SettingsView().frame(width: 300, height: 210)
////                    }
//                }
//            }
    }

    private var detailsView: some View {
        _ConsoleDetailsView()
    }

    @ViewBuilder
    private var contentToolbarNavigationItems: some View {
        if !(environment.store.options.contains(.readonly)) {
            Button(action: { isSharingStore = true }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .popover(isPresented: $isSharingStore, arrowEdge: .bottom) {
                List {
                    ShareStoreView(onDismiss: {})
                        .padding(10)
                        .frame(width: 300, height: 140)
                }.listStyle(.plain)
                .frame(width: 320, height: 160)
            }
            Button(action: { environment.store.removeAll() }) {
                Label("Clear", systemImage: "trash")
            }
        }
    }
}

@available(iOS 15, macOS 13, *)
private struct _ConsoleDetailsView: View {
    @EnvironmentObject private var router: ConsoleRouter

    var body: some View {
        if let selection = router.selection {
            ConsoleEntityDetailsRouterView(selection: selection)
                .background(Color(UXColor.textBackgroundColor))
                .frame(minWidth: 400, idealWidth: 500, minHeight: 120, idealHeight: 480)
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        ConsoleView(store: .mock)
            .previewLayout(.fixed(width: 700, height: 400))
    }
}
#endif
#endif
