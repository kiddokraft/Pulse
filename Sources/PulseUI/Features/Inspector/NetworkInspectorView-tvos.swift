// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(tvOS)

import SwiftUI
import CoreData
import Pulse
import Combine

struct NetworkInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @ObservedObject private var settings: UserSettings = .shared
    @Environment(\.store) private var store
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.router) private var router

    @ViewBuilder
    var body: some View {
        if environment.mode == .connection || isConnectionTask {
            ConnectionInspectorView(task: task)
        } else {
            VStack(spacing: 0) {
                HStack {
                    Button("Back", action: goBack)
                    Spacer()
                    Text(environment.delegate.getShortTitle(for: task))
                        .font(.headline)
                        .lineLimit(1)
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 12)

                Divider()
                networkContents
            }
        }
    }

    @ViewBuilder
    private var networkContents: some View {
        if #available(tvOS 17, *) {
            List {
                contents
            }
            .contentMargins(.horizontal, 40, for: .scrollContent)
        } else {
            List {
                contents
                    .listRowInsets(EdgeInsets(top: 8, leading: 40, bottom: 8, trailing: 40))
            }
        }
    }

    private var isConnectionTask: Bool {
        if task.isConnection ||
            task.originalRequest?.headers["Connection-ID"] != nil ||
            task.originalRequest?.headers["Connection-Network"] != nil ||
            task.response?.headers["Connection-Upload"] != nil {
            return true
        }
        let scheme = URL(string: task.url ?? "")?.scheme?.lowercased()
        return scheme == "tcp" || scheme == "udp"
    }

    private func goBack() {
        if router.selectedObjectID != nil {
            router.selectedObjectID = nil
        } else {
            dismiss()
        }
    }

    @ViewBuilder
    private var contents: some View {
        Section {
            NetworkInspectorView.makeHeaderView(task: task, store: store)
        }

        Section {
            NetworkRequestStatusSectionView(viewModel: .init(task: task, store: store))
        }
        Section {
            NetworkInspectorRequestTypePicker(isCurrentRequest: $settings.isShowingCurrentRequest)
            NetworkInspectorView.makeRequestSection(task: task, isCurrentRequest: settings.isShowingCurrentRequest)
        } header: { Text("Request") }
        if task.state != .pending {
            Section {
                NetworkInspectorView.makeResponseSection(task: task)
            } header: { Text("Response") }

        }
        Section {
            NetworkCURLCell(task: task)
        } header: { Text("Transactions") }
    }
}

#if DEBUG
struct NetworkInspectorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            NetworkInspectorView(task: LoggerStore.preview.entity(for: .login))
        }
        .injecting(ConsoleEnvironment(store: .preview))
    }
}
#endif

#endif
