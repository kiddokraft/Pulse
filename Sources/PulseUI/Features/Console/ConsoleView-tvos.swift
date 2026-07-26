// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import CoreData
import Pulse
import Combine

public struct ConsoleView: View {
    @StateObject private var environment: ConsoleEnvironment
    @StateObject private var listViewModel: ConsoleListViewModel
    @StateObject private var searchBarViewModel: ConsoleSearchBarViewModel
    @StateObject private var searchViewModel: ConsoleSearchViewModel

    init(environment: ConsoleEnvironment) {
        let listViewModel = ConsoleListViewModel(environment: environment, filters: environment.filters)
        let searchBarViewModel = ConsoleSearchBarViewModel()
        _environment = StateObject(wrappedValue: environment)
        _listViewModel = StateObject(wrappedValue: listViewModel)
        _searchBarViewModel = StateObject(wrappedValue: searchBarViewModel)
        _searchViewModel = StateObject(wrappedValue: ConsoleSearchViewModel(
            environment: environment,
            source: listViewModel,
            searchBar: searchBarViewModel
        ))
    }

    public var body: some View {
        NavigationView {
            splitView
        }
        .onAppear {
            listViewModel.isViewVisible = true
            searchViewModel.isSearchActive = !searchBarViewModel.text.isEmpty
        }
        .onDisappear {
            listViewModel.isViewVisible = false
            searchViewModel.isSearchActive = false
        }
        .onChange(of: searchBarViewModel.text) { text in
            searchViewModel.isSearchActive = !text.trimmingCharacters(in: .whitespaces).isEmpty
        }
        .injecting(environment)
        .environmentObject(listViewModel)
    }

    private var splitView: some View {
        HStack(spacing: 0) {
            masterPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            ConsoleDetailsView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var masterPane: some View {
        consoleList
    }

    @ViewBuilder
    private var consoleList: some View {
        if #available(tvOS 17, *) {
            List {
                searchHeader
                modePicker
                filterLink
                consoleListContent
            }
            .contentMargins(.horizontal, 40, for: .scrollContent)
        } else {
            List {
                searchHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                modePicker
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                filterLink
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                consoleListContent
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search", text: $searchBarViewModel.text)
                .onSubmit(searchViewModel.onSubmitSearch)
        }
    }

    private var modePicker: some View {
        Picker("View", selection: modeSelection) {
            Text("Connection").tag(ConsoleMode.connection)
            Text("Logs").tag(ConsoleMode.logs)
            Text("All").tag(ConsoleMode.all)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    private var filterLink: some View {
        NavigationLink(destination:
            ConsoleMenuScreen(filters: environment.filters)
                .injecting(environment)
        ) {
            Text("Filter")
        }
    }

    @ViewBuilder
    private var consoleListContent: some View {
        if searchBarViewModel.text.trimmingCharacters(in: .whitespaces).isEmpty {
            ConsoleListContentView()
        } else if searchViewModel.results.isEmpty {
            Text(searchViewModel.isSearching ? "Searching…" : "No Results")
                .foregroundColor(.secondary)
                .focusable()
        } else {
            ForEach(searchViewModel.results) { result in
                ConsoleEntityCell(entity: result.entity)
            }
        }
    }

    private var modeSelection: Binding<ConsoleMode> {
        Binding(
            get: { environment.mode },
            set: { mode in
                environment.router.selectedObjectID = nil
                environment.mode = mode
            }
        )
    }
}

private struct ConsoleDetailsView: View {
    @EnvironmentObject private var router: ConsoleRouter
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    @ViewBuilder
    var body: some View {
        if let objectID = router.selectedObjectID,
           let entity = try? store.viewContext.existingObject(with: objectID) {
            switch LoggerEntity(entity) {
            case .message(let message):
                ConsoleMessageDetailsView(message: message)
            case .task(let task):
                if environment.mode == .connection || isConnection(task) {
                    ConnectionInspectorView(task: task)
                } else {
                    NetworkInspectorView(task: task)
                }
            }
        } else {
            Text("Select an item")
                .foregroundColor(.secondary)
        }
    }

    private func isConnection(_ task: NetworkTaskEntity) -> Bool {
        if task.isConnection ||
            task.originalRequest?.headers["Connection-ID"] != nil ||
            task.originalRequest?.headers["Connection-Network"] != nil ||
            task.response?.headers["Connection-Upload"] != nil {
            return true
        }
        let scheme = URL(string: task.url ?? "")?.scheme?.lowercased()
        return scheme == "tcp" || scheme == "udp"
    }
}

private struct ConsoleMenuScreen: View {
    @ObservedObject var filters: ConsoleFiltersViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        menu
            .environmentObject(filters)
            .navigationTitle("Console Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back", action: dismiss.callAsFunction)
                }
            }
    }

    @ViewBuilder
    private var menu: some View {
        Form {
            ConsoleMenuView()
        }
    }
}

private struct ConsoleMenuView: View {
    @EnvironmentObject private var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    var body: some View {
        Section {
            Toggle(isOn: $viewModel.options.isOnlyErrors) {
                Label("Errors Only", systemImage: "exclamationmark.octagon")
            }.toggleAccentTintCompat()
            Toggle(isOn: environment.bindingForNetworkMode) {
                Label("Network Only", systemImage: "arrow.down.circle")
            }.toggleAccentTintCompat()
            NavigationLink(destination: destinationFilters) {
                Label(environment.bindingForNetworkMode.wrappedValue ? "Network Filters" : "Message Filters", systemImage: "line.3.horizontal.decrease.circle")
            }
        } header: { Text("Quick Filters") }
        if !(store.options.contains(.readonly)) {
            Section {
                NavigationLink(destination: destinationStoreDetails) {
                    Label("Store Info", systemImage: "info.circle")
                }
                Button(role: .destructive, action: {
                    environment.index.clear()
                    store.removeAll()
                }, label: {
                    Label("Remove Logs", systemImage: "trash")
                })
            } header: { Text("Store") }
        }
        Section {
            NavigationLink(destination: destinationSettings) {
                Label("Settings", systemImage: "gear")
            }
        } header: { Text("Settings") }
    }

    private var destinationSettings: some View {
        SettingsView(store: store)
            .consoleBackButton()
    }

    private var destinationStoreDetails: some View {
        StoreDetailsView(source: .store(store))
            .consoleBackButton()
    }

    private var destinationFilters: some View {
        ConsoleFiltersView()
            .consoleBackButton()
    }
}

private extension View {
    func consoleBackButton() -> some View {
        modifier(ConsoleBackButtonModifier())
    }
}

private struct ConsoleBackButtonModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back", action: dismiss.callAsFunction)
            }
        }
    }
}

#if DEBUG
struct ConsoleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConsoleView(store: .mock)
        }
    }
}
#endif
#endif
