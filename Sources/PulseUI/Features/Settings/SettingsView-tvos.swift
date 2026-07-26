// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import Pulse

public struct SettingsView: View {
    private let store: LoggerStore
    private let onBack: (() -> Void)?
    private let showStoreDetails: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Namespace private var focusNamespace

    public init(store: LoggerStore = .shared) {
        self.store = store
        self.onBack = nil
        self.showStoreDetails = nil
    }

    init(
        store: LoggerStore,
        onBack: @escaping () -> Void,
        showStoreDetails: @escaping () -> Void
    ) {
        self.store = store
        self.onBack = onBack
        self.showStoreDetails = showStoreDetails
    }

    public var body: some View {
        settingsList
    }

    @ViewBuilder
    private var settingsList: some View {
        if #available(tvOS 17, *) {
            List {
                backButton
                titleHeader
                    .prefersDefaultFocus(true, in: focusNamespace)
                settings
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
                settings
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
            Text("Settings")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var settings: some View {
        if store === RemoteLogger.shared.store {
            RemoteLoggerSettingsView(viewModel: .shared)
        }
        Section {
            sectionRow("Store")
            if let showStoreDetails {
                Button("Store Info", action: showStoreDetails)
            } else {
                NavigationLink(destination: StoreDetailsView(source: .store(store))) {
                    Text("Store Info")
                }
            }
            if !store.options.contains(.readonly) {
                Button(role: .destructive, action: { store.removeAll() }) {
                    Text("Remove Logs")
                }
            }
        }
    }

    private func goBack() {
        if let onBack {
            onBack()
        } else {
            dismiss()
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
}

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView(store: .mock)
        }.navigationViewStyle(.stack)
    }
}
#endif
#endif
