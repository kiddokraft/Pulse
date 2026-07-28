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
    @State private var isFilterPresented = false

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
        .onReceive(environment.router.$selectedObjectID) { objectID in
            if objectID != nil {
                isFilterPresented = false
            }
        }
        .injecting(environment)
        .environmentObject(listViewModel)
    }

    private var splitView: some View {
        HStack(spacing: 0) {
            masterPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            Divider()

            ConsoleDetailsView(
                isFilterPresented: isFilterPresented,
                dismissFilter: dismissConsoleSettings,
                searchText: $searchBarViewModel.text,
                onSubmitSearch: searchViewModel.onSubmitSearch
            )
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
                filterLink
                consoleListContent
            }
            .contentMargins(.horizontal, 40, for: .scrollContent)
        } else {
            List {
                filterLink
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
                consoleListContent
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
        }
    }

    private var filterLink: some View {

          

            Button {
                environment.router.selectedObjectID = nil
                isFilterPresented = true
            } label: {
                HStack{
                    Text("Filter")
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                    Spacer()
                    Image(systemName: "line.3.horizontal.decrease")
                }
            }
        }
    

    private func dismissConsoleSettings() {
        isFilterPresented = false
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

}

private struct ConsoleDetailsView: View {
    let isFilterPresented: Bool
    let dismissFilter: () -> Void
    @Binding var searchText: String
    let onSubmitSearch: () -> Void

    @EnvironmentObject private var router: ConsoleRouter
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    @ViewBuilder
    var body: some View {
        if isFilterPresented {
            ConsoleMenuScreen(
                filters: environment.filters,
                onBack: dismissFilter,
                searchText: $searchText,
                onSubmitSearch: onSubmitSearch
            )
            .injecting(environment)
        } else if let objectID = router.selectedObjectID,
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
            Text("Choose a log or connection to view details")
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

private enum ConsoleMenuDestination {
    case filters
    case storeDetails
}

private struct ConsoleMenuScreen: View {
    @ObservedObject var filters: ConsoleFiltersViewModel
    let onBack: () -> Void
    @Binding var searchText: String
    let onSubmitSearch: () -> Void
    @State private var path: [ConsoleMenuDestination] = []
    @Environment(\.store) private var store
    @Namespace private var focusNamespace

    @ViewBuilder
    var body: some View {
        ZStack {
            menu
                .environmentObject(filters)
                .opacity(path.isEmpty ? 1 : 0)
                .disabled(!path.isEmpty)

            if path.last == .filters {
                ConsoleFiltersView(onBack: goBack)
                    .environmentObject(filters)
            } else if path.last == .storeDetails {
                StoreDetailsView(source: .store(store), onBack: goBack)
            }
        }
    }

    @ViewBuilder
    private var menu: some View {
        if #available(tvOS 17, *) {
            List {
                backButton
                titleHeader
                    .prefersDefaultFocus(true, in: focusNamespace)
                ConsoleMenuView(
                    searchText: $searchText,
                    onSubmitSearch: onSubmitSearch,
                    showFilters: { show(.filters) },
                    showStoreDetails: { show(.storeDetails) }
                )
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
                ConsoleMenuView(
                    searchText: $searchText,
                    onSubmitSearch: onSubmitSearch,
                    showFilters: { show(.filters) },
                    showStoreDetails: { show(.storeDetails) }
                )
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
            .focusScope(focusNamespace)
        }
    }

    private var backButton: some View {
        Button("Back", action: onBack)
    }

    private var titleHeader: some View {
      
            Text("Console")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    

    private func show(_ destination: ConsoleMenuDestination) {
        path.append(destination)
    }

    private func goBack() {
        guard path.popLast() != nil else {
            onBack()
            return
        }
    }
}

private struct ConsoleMenuView: View {
    @Binding var searchText: String
    let onSubmitSearch: () -> Void
    let showFilters: () -> Void
    let showStoreDetails: () -> Void

    @EnvironmentObject private var viewModel: ConsoleFiltersViewModel
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    var body: some View {
        Section {
            sectionRow("Quick Filters")
            TextField("Search", text: $searchText)
                .onSubmit(onSubmitSearch)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            Picker("Content", selection: modeSelection) {
                Text("Connection").tag(ConsoleMode.connection)
                Text("Logs").tag(ConsoleMode.logs)
                Text("All").tag(ConsoleMode.all)
            }
            Toggle(isOn: $viewModel.options.isOnlyErrors) {
                Text("Errors Only")
            }.toggleAccentTintCompat()
            Button(action: showFilters) {
                Text(environment.mode == .connection ? "Network Filters" : "Message Filters")
            }
        }
        if !(store.options.contains(.readonly)) {
            Section {
                sectionRow("Store")
                Button(action: showStoreDetails) {
                    Text("Store Info")
                }
                Button(role: .destructive, action: {
                    environment.index.clear()
                    store.removeAll()
                }, label: {
                    Text("Remove Logs")
                })
            }
        }
    }

    private func sectionRow(_ title: String) -> some View {
     
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        
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
