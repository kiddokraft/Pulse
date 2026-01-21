// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(visionOS)

import SwiftUI
import CoreData
import Pulse
import Combine

/// A specialized inspector view for proxy/VPN connections (TCP/UDP).
/// Unlike NetworkInspectorView, this view shows connection-specific information
/// without HTTP-specific fields like request/response body and cURL.
@available(iOS 15, visionOS 1.0, *)
struct ConnectionInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @State private var shareItems: ShareItems?
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    var body: some View {
        List {
            contents
        }
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                trailingNavigationBarItems
            }
        }
        .inlineNavigationTitle(task.connectionDomain ?? task.host ?? "Connection")
        .sheet(item: $shareItems, content: ShareView.init)
    }

    @ViewBuilder
    private var contents: some View {
        // Header with connection state
        Section {
            ConnectionHeaderView(task: task)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowBackground(Color.clear)

        // Connection Status
        Section {
            ConnectionStatusView(task: task)
        }

        // Connection Details
        Section("Connection") {
            ConnectionDetailsView(task: task)
        }

        // Routing Information
        Section("Routing") {
            ConnectionRoutingView(task: task)
        }

        // Traffic Statistics
        if task.connectionState == .closed {
            Section("Traffic") {
                ConnectionTrafficView(task: task)
            }
        }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        PinButton(viewModel: PinButtonViewModel(task), isTextNeeded: false)
        Menu(content: {
            AttributedStringShareMenu(shareItems: $shareItems) {
                TextRenderer(options: .sharing).make {
                    $0.render(task, content: .sharing, store: store)
                }
            }
        }, label: {
            Image(systemName: "square.and.arrow.up")
        })
    }
}

// MARK: - Connection Header View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionHeaderView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        VStack(spacing: 12) {
            // Connection state icon
            Image(systemName: task.connectionState.iconSystemName)
                .font(.system(size: 48))
                .foregroundColor(task.connectionState.tintColor)

            // Connection state label
            Text(task.connectionState.title)
                .font(.headline)
                .foregroundColor(task.connectionState.tintColor)

            // Protocol badge
            HStack(spacing: 8) {
                Text(task.httpMethod ?? "TCP")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)

                if let ipVersion = task.connectionIPVersion {
                    Text(ipVersion)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Connection Status View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionStatusView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        HStack {
            Text("Status")
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(task.connectionState.tintColor)
                    .frame(width: 8, height: 8)
                Text(task.connectionState.title)
                    .foregroundColor(task.connectionState.tintColor)
                    .fontWeight(.medium)
            }
        }

        if let time = task.createdAt as Date? {
            HStack {
                Text("Started")
                Spacer()
                Text(time, style: .time)
                    .foregroundColor(.secondary)
            }
        }

        if task.duration > 0 {
            HStack {
                Text("Duration")
                Spacer()
                Text(DurationFormatter.string(from: task.duration))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Connection Details View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionDetailsView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let source = task.connectionSource, !source.isEmpty {
            ConnectionDetailRow(title: "Source", value: source)
        }

        if let destination = task.connectionDestination, !destination.isEmpty {
            ConnectionDetailRow(title: "Destination", value: destination)
        }

        if let domain = task.connectionDomain, !domain.isEmpty {
            ConnectionDetailRow(title: "Domain", value: domain)
        }

        if let proto = task.connectionProtocol, !proto.isEmpty {
            ConnectionDetailRow(title: "Protocol", value: proto)
        }

        if let inbound = task.connectionInbound, !inbound.isEmpty {
            HStack {
                Text("Inbound")
                Spacer()
                VStack(alignment: .trailing) {
                    Text(inbound)
                        .foregroundColor(.secondary)
                    if let inboundType = task.connectionInboundType, !inboundType.isEmpty {
                        Text(inboundType)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }
    }
}

// MARK: - Connection Routing View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionRoutingView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let rule = task.connectionRule, !rule.isEmpty {
            ConnectionDetailRow(title: "Rule", value: rule)
        }

        if let outbound = task.connectionOutbound, !outbound.isEmpty {
            HStack {
                Text("Outbound")
                Spacer()
                VStack(alignment: .trailing) {
                    Text(outbound)
                        .foregroundColor(.secondary)
                    if let outboundType = task.connectionOutboundType, !outboundType.isEmpty {
                        Text(outboundType)
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
            }
        }

        if let chain = task.connectionChain, !chain.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain")
                Text(chain)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Connection Traffic View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionTrafficView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let upload = task.connectionUpload {
            HStack {
                Label("Upload", systemImage: "arrow.up")
                Spacer()
                Text(upload)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }

        if let download = task.connectionDownload {
            HStack {
                Label("Download", systemImage: "arrow.down")
                Spacer()
                Text(download)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Helper Views

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

#endif

// MARK: - macOS Implementation

#if os(macOS)

import SwiftUI
import CoreData
import Pulse
import Combine

@available(macOS 13, *)
struct ConnectionInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    @State private var shareItems: ShareItems?
    @Environment(\.store) private var store

    var body: some View {
        List {
            contents
        }
    }

    @ViewBuilder
    private var contents: some View {
        // Header with connection state
        Section {
            ConnectionHeaderView(task: task)
        }

        // Connection Status
        Section("Status") {
            ConnectionStatusView(task: task)
        }

        // Connection Details
        Section("Connection") {
            ConnectionDetailsView(task: task)
        }

        // Routing Information
        Section("Routing") {
            ConnectionRoutingView(task: task)
        }

        // Traffic Statistics
        if task.connectionState == .closed {
            Section("Traffic") {
                ConnectionTrafficView(task: task)
            }
        }
    }
}

// MARK: - macOS Helper Views

@available(macOS 13, *)
private struct ConnectionHeaderView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: task.connectionState.iconSystemName)
                .font(.system(size: 32))
                .foregroundColor(task.connectionState.tintColor)

            Text(task.connectionState.title)
                .font(.headline)
                .foregroundColor(task.connectionState.tintColor)

            HStack(spacing: 6) {
                Text(task.httpMethod ?? "TCP")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(3)

                if let ipVersion = task.connectionIPVersion {
                    Text(ipVersion)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

@available(macOS 13, *)
private struct ConnectionStatusView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        HStack {
            Text("Status")
            Spacer()
            HStack(spacing: 4) {
                Circle()
                    .fill(task.connectionState.tintColor)
                    .frame(width: 6, height: 6)
                Text(task.connectionState.title)
                    .foregroundColor(task.connectionState.tintColor)
            }
        }

        if let time = task.createdAt as Date? {
            HStack {
                Text("Started")
                Spacer()
                Text(time, style: .time)
                    .foregroundColor(.secondary)
            }
        }

        if task.duration > 0 {
            HStack {
                Text("Duration")
                Spacer()
                Text(DurationFormatter.string(from: task.duration))
                    .foregroundColor(.secondary)
            }
        }
    }
}

@available(macOS 13, *)
private struct ConnectionDetailsView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let source = task.connectionSource, !source.isEmpty {
            ConnectionRow(title: "Source", value: source)
        }

        if let destination = task.connectionDestination, !destination.isEmpty {
            ConnectionRow(title: "Destination", value: destination)
        }

        if let domain = task.connectionDomain, !domain.isEmpty {
            ConnectionRow(title: "Domain", value: domain)
        }

        if let proto = task.connectionProtocol, !proto.isEmpty {
            ConnectionRow(title: "Protocol", value: proto)
        }

        if let inbound = task.connectionInbound, !inbound.isEmpty {
            ConnectionRow(title: "Inbound", value: inbound)
        }
    }
}

@available(macOS 13, *)
private struct ConnectionRoutingView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let rule = task.connectionRule, !rule.isEmpty {
            ConnectionRow(title: "Rule", value: rule)
        }

        if let outbound = task.connectionOutbound, !outbound.isEmpty {
            ConnectionRow(title: "Outbound", value: outbound)
        }

        if let chain = task.connectionChain, !chain.isEmpty {
            ConnectionRow(title: "Chain", value: chain)
        }
    }
}

@available(macOS 13, *)
private struct ConnectionTrafficView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        if let upload = task.connectionUpload {
            ConnectionRow(title: "Upload", value: upload)
        }

        if let download = task.connectionDownload {
            ConnectionRow(title: "Download", value: download)
        }
    }
}

@available(macOS 13, *)
private struct ConnectionRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

#endif

// MARK: - watchOS & tvOS Stubs

#if os(watchOS) || os(tvOS)

import SwiftUI
import Pulse

struct ConnectionInspectorView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(task.connectionState.title)
                        .foregroundColor(task.connectionState.tintColor)
                }
            }

            Section("Connection") {
                if let domain = task.connectionDomain ?? task.host {
                    HStack {
                        Text("Domain")
                        Spacer()
                        Text(domain)
                            .foregroundColor(.secondary)
                    }
                }
                if let destination = task.connectionDestination {
                    HStack {
                        Text("Destination")
                        Spacer()
                        Text(destination)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Routing") {
                if let rule = task.connectionRule {
                    HStack {
                        Text("Rule")
                        Spacer()
                        Text(rule)
                            .foregroundColor(.secondary)
                    }
                }
                if let outbound = task.connectionOutbound {
                    HStack {
                        Text("Outbound")
                        Spacer()
                        Text(outbound)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Connection")
    }
}

#endif
