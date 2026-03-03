// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(iOS 15, visionOS 1.0, *)
struct ConsoleContextMenu: View {
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.router) private var router

    var body: some View {
        Menu {
            Section {
                Button(action: { router.isShowingSessions = true }) {
                    Label("Sessions", systemImage: "list.bullet.clipboard")
                }
            }
            Section {
                ConsoleSortByMenu()
                ConsoleGroupByMenu()
            }
            Section {
                if !environment.store.isArchive {
                    Button(role: .destructive, action: environment.removeAllLogs) {
                        Label("Remove Logs", systemImage: "trash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}

private struct ConsoleSortByMenu: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Sort By", selection: $environment.listOptions.taskSortBy) {
                    ForEach(ConsoleListOptions.TaskSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            } else {
                Picker("Sort By", selection: $environment.listOptions.messageSortBy) {
                    ForEach(ConsoleListOptions.MessageSortBy.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
            }
            Picker("Ordering", selection: $environment.listOptions.order) {
                Text("Descending").tag(ConsoleListOptions.Ordering.descending)
                Text("Ascending").tag(ConsoleListOptions.Ordering.ascending)
            }
        }, label: {
            Label("Sort By", systemImage: "arrow.up.arrow.down")
        })
    }
}
#endif

#if os(iOS) || os(macOS) || os(visionOS)
import SwiftUI

struct ConsoleGroupByMenu: View {
    @EnvironmentObject private var environment: ConsoleEnvironment

    var body: some View {
        Menu(content: {
            if environment.mode == .network {
                Picker("Group By", selection: $environment.listOptions.taskGroupBy) {
                    Group {
                        Text("URL").tag(ConsoleListOptions.TaskGroupBy.url)
                        Text("Host").tag(ConsoleListOptions.TaskGroupBy.host)
                        Text("Method").tag(ConsoleListOptions.TaskGroupBy.method)
                    }
                    Group {
                        Divider()
                        Text("Content Type").tag(ConsoleListOptions.TaskGroupBy.responseContentType)
                        Text("Status Code").tag(ConsoleListOptions.TaskGroupBy.statusCode)
                        Text("Error Code").tag(ConsoleListOptions.TaskGroupBy.errorCode)
                        Divider()
                        Text("Task State").tag(ConsoleListOptions.TaskGroupBy.requestState)
                        Text("Task Type").tag(ConsoleListOptions.TaskGroupBy.taskType)
                        Divider()
                        Text("Session").tag(ConsoleListOptions.TaskGroupBy.session)
                    }
                    Group {
                        Divider()
                        Text("None").tag(ConsoleListOptions.TaskGroupBy.noGrouping)
                    }
                }
            } else {
                Picker("Group By", selection: $environment.listOptions.messageGroupBy) {
                    ForEach(ConsoleListOptions.MessageGroupBy.allCases.filter { $0 != .noGrouping }, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                    Divider()
                    Text("None").tag(ConsoleListOptions.MessageGroupBy.noGrouping)
                }
            }
        }, label: {
            Label("Group By", systemImage: "rectangle.3.group")
        })
    }
}
#endif
