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
        if task.connectionState == .complete {
            Section("Traffic") {
                ConnectionTrafficView(task: task)
            }
        }

        // Timing
        if task.effectiveDuration > 0 {
            Section("Timing") {
                ConnectionTimingView(task: task)
            }
        }
    }

    @ViewBuilder
    private var trailingNavigationBarItems: some View {
        PinButton(viewModel: PinButtonViewModel(task), isTextNeeded: false)
        Menu(content: {
            AttributedStringShareMenu(shareItems: $shareItems) {
                TextRenderer(options: .sharing).make {
                    $0.renderConnectionSummary(task, store: store)
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
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 16) {
            // Connection state with gentle indicator for connected state
            HStack(spacing: 8) {
                if task.connectionState == .connected {
                    // Gentle breathing indicator - slow and calming
                    Circle()
                        .fill(task.connectionState.tintColor)
                        .frame(width: 10, height: 10)
                        .opacity(isPulsing ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isPulsing)
                        .onAppear { isPulsing = true }
                } else {
                    Circle()
                        .fill(task.connectionState.tintColor)
                        .frame(width: 10, height: 10)
                }
                Text(task.connectionState.title)
                    .font(.headline)
                    .foregroundColor(task.connectionState.tintColor)
            }

            // Protocol badges
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

            // Transfer info or activity spinner for active connections
            if task.connectionState == .connected {
                ConnectionActiveIndicatorView(task: task)
            } else {
                ConnectionTransferInfoView(task: task)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

// MARK: - Connection Active Indicator View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionActiveIndicatorView: View {
    @ObservedObject var task: NetworkTaskEntity
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 12) {
            // Calm connected icon with gentle animation
            Image(systemName: "link.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear { isAnimating = true }

            // Show live traffic stats
            HStack(spacing: 24) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(task.connectionUpload ?? "0 KB")
                        .font(.subheadline.monospacedDigit())
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundColor(.secondary)
                    Text(task.connectionDownload ?? "0 KB")
                        .font(.subheadline.monospacedDigit())
                }
            }
        }
        .padding(.top, 4)
    }
}

// MARK: - Connection Transfer Info View (Network Style)

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionTransferInfoView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        HStack {
            Spacer()
            uploadView
            Spacer()

            Divider()
                .frame(height: 50)

            Spacer()
            downloadView
            Spacer()
        }
    }

    private var uploadView: some View {
        VStack {
            HStack(alignment: .center, spacing: nil) {
                Image(systemName: "arrow.up.circle")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Sent").font(.headline)
                    Text(task.connectionUpload ?? "0 KB").font(.headline)
                }
            }
            .fixedSize()
            .padding(2)
        }
    }

    private var downloadView: some View {
        VStack {
            HStack(alignment: .center, spacing: nil) {
                Image(systemName: "arrow.down.circle")
                    .font(.largeTitle)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Received").font(.headline)
                    Text(task.connectionDownload ?? "0 KB").font(.headline)
                }
            }
            .fixedSize()
            .padding(2)
        }
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

        if task.effectiveDuration > 0 {
            HStack {
                Text("Duration")
                Spacer()
                Text(DurationFormatter.string(from: task.effectiveDuration))
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

// MARK: - Connection Timing View

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionTimingView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        VStack(spacing: 16) {
            // Use TimingView for the timeline chart
            if task.effectiveDuration > 0 {
                TimingView(viewModel: makeTimingViewModel())
            }

            // Additional timing info
            VStack(spacing: 8) {
                if let start = task.createdAt as Date? {
                    HStack {
                        Text("Started")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(start, style: .time)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                if task.connectionState == .complete, task.effectiveDuration > 0 {
                    HStack {
                        Text("Duration")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(DurationFormatter.string(from: task.effectiveDuration))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    // Transfer rate
                    if let upload = task.connectionUpload, let download = task.connectionDownload {
                        let uploadBytes = parseBytes(upload)
                        let downloadBytes = parseBytes(download)
                        let totalBytes = uploadBytes + downloadBytes
                        if totalBytes > 0 {
                            HStack {
                                Text("Transfer Rate")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: Int64(Double(totalBytes) / task.effectiveDuration), countStyle: .binary) + "/s")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func makeTimingViewModel() -> TimingViewModel {
        let duration = task.effectiveDuration
        let durationStr = DurationFormatter.string(from: duration)

        var rows: [TimingRowViewModel] = []

        // Connection duration bar
        let color: UXColor = task.connectionState == .connected ? .systemGreen : .systemGray
        rows.append(TimingRowViewModel(
            title: "Connection",
            value: durationStr,
            color: color,
            start: 0.0,
            length: 1.0
        ))

        // Add upload/download visualization if we have data
        if task.connectionState == .complete,
           let upload = task.connectionUpload,
           let download = task.connectionDownload {
            let uploadBytes = parseBytes(upload)
            let downloadBytes = parseBytes(download)
            let totalBytes = uploadBytes + downloadBytes

            if totalBytes > 0 {
                let uploadRatio = CGFloat(uploadBytes) / CGFloat(totalBytes)

                rows.append(TimingRowViewModel(
                    title: "Upload",
                    value: upload,
                    color: .systemBlue,
                    start: 0.0,
                    length: uploadRatio
                ))

                rows.append(TimingRowViewModel(
                    title: "Download",
                    value: download,
                    color: .systemBlue,
                    start: uploadRatio,
                    length: 1.0 - uploadRatio
                ))
            }
        }

        let section = TimingRowSectionViewModel(title: "Timeline", items: rows)
        return TimingViewModel(sections: [section])
    }

    private func parseBytes(_ string: String) -> Int64 {
        // Parse strings like "1.5 MB", "256 KB", etc.
        let components = string.components(separatedBy: " ")
        guard components.count >= 2,
              let value = Double(components[0]) else {
            return 0
        }

        let unit = components[1].uppercased()
        let multiplier: Int64
        switch unit {
        case "B", "BYTES": multiplier = 1
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return Int64(value * Double(multiplier))
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
    @State var selectedTab: ConnectionInspectorTab = .summary
    @Environment(\.store) private var store

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            selectedTabView
        }
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            InlineTabBar(items: ConnectionInspectorTab.allCases, selection: $selectedTab)
            Spacer()
            ButtonCloseDetailsView()
        }
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
    }

    @ViewBuilder
    private var selectedTabView: some View {
        switch selectedTab {
        case .summary:
            ConnectionSummaryTabView(task: task, store: store)
        case .details:
            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).make { $0.renderConnectionDetails(task) }))
        case .routing:
            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).make { $0.renderConnectionRouting(task) }))
        case .traffic:
            ConnectionTrafficTabView(task: task)
        case .timing:
            List {
                Section("Timing") {
                    ConnectionTimingView(task: task)
                }
            }
        }
    }
}

// MARK: - macOS Summary Tab with Connected Indicator

@available(macOS 13, *)
private struct ConnectionSummaryTabView: View {
    @ObservedObject var task: NetworkTaskEntity
    let store: LoggerStore
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with calm status indicator for connected state
            if task.connectionState == .connected {
                VStack(spacing: 8) {
                    // Calm connected indicator
                    HStack(spacing: 6) {
                        Image(systemName: "link.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                            .opacity(isAnimating ? 0.6 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                            .onAppear { isAnimating = true }
                        Text(task.connectionState.title)
                            .font(.headline)
                            .foregroundColor(task.connectionState.tintColor)
                    }
                    .padding(.top, 8)

                    // Live traffic stats
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(task.connectionUpload ?? "0 KB")
                                .font(.system(.caption, design: .monospaced))
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(task.connectionDownload ?? "0 KB")
                                .font(.system(.caption, design: .monospaced))
                        }
                    }
                    .padding(.bottom, 8)

                    Divider()
                }
            }

            // Summary content
            RichTextView(viewModel: .init(string: TextRenderer(options: .sharing).make { $0.renderConnectionSummary(task, store: store) }))
        }
    }
}

// MARK: - macOS Traffic Tab with Network Style

@available(macOS 13, *)
private struct ConnectionTrafficTabView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        List {
            Section {
                // Network-style transfer info header
                ConnectionTransferInfoMacView(task: task)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section("Transfer Details") {
                if let upload = task.connectionUpload {
                    HStack {
                        Label("Sent", systemImage: "arrow.up.circle")
                        Spacer()
                        Text(upload)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                if let download = task.connectionDownload {
                    HStack {
                        Label("Received", systemImage: "arrow.down.circle")
                        Spacer()
                        Text(download)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }

                if task.effectiveDuration > 0 {
                    HStack {
                        Label("Duration", systemImage: "clock")
                        Spacer()
                        Text(DurationFormatter.string(from: task.effectiveDuration))
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }

                    // Transfer rate
                    if let upload = task.connectionUpload, let download = task.connectionDownload {
                        let uploadBytes = parseBytes(upload)
                        let downloadBytes = parseBytes(download)
                        let totalBytes = uploadBytes + downloadBytes
                        if totalBytes > 0 {
                            HStack {
                                Label("Transfer Rate", systemImage: "speedometer")
                                Spacer()
                                Text(ByteCountFormatter.string(fromByteCount: Int64(Double(totalBytes) / task.effectiveDuration), countStyle: .binary) + "/s")
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private func parseBytes(_ string: String) -> Int64 {
        let components = string.components(separatedBy: " ")
        guard components.count >= 2,
              let value = Double(components[0]) else {
            return 0
        }

        let unit = components[1].uppercased()
        let multiplier: Int64
        switch unit {
        case "B", "BYTES": multiplier = 1
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return Int64(value * Double(multiplier))
    }
}

// MARK: - macOS Transfer Info View (Network Style)

@available(macOS 13, *)
private struct ConnectionTransferInfoMacView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        HStack {
            // Sent
            VStack {
                HStack(alignment: .center) {
                    Image(systemName: "arrow.up.circle")
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Sent").font(.headline)
                        Text(task.connectionUpload ?? "0 KB").font(.headline)
                    }
                }
                .fixedSize()
            }

            Spacer()

            // Received
            VStack {
                HStack(alignment: .center) {
                    Image(systemName: "arrow.down.circle")
                        .font(.largeTitle)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Received").font(.headline)
                        Text(task.connectionDownload ?? "0 KB").font(.headline)
                    }
                }
                .fixedSize()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

/// Tab options for connection inspector (no Request, Response, Headers, Metrics, cURL)
enum ConnectionInspectorTab: String, Identifiable, CaseIterable, CustomStringConvertible {
    case summary = "Summary"
    case details = "Details"
    case routing = "Routing"
    case traffic = "Traffic"
    case timing = "Timing"

    var id: ConnectionInspectorTab { self }
    var description: String { self.rawValue }
}

// MARK: - macOS Helper Views

@available(macOS 13, *)
private struct ConnectionHeaderView: View {
    @ObservedObject var task: NetworkTaskEntity
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 8) {
            if task.connectionState == .connected {
                // Gentle breathing animation for connected state
                Image(systemName: task.connectionState.iconSystemName)
                    .font(.system(size: 32))
                    .foregroundColor(task.connectionState.tintColor)
                    .opacity(isAnimating ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    .onAppear { isAnimating = true }
            } else {
                Image(systemName: task.connectionState.iconSystemName)
                    .font(.system(size: 32))
                    .foregroundColor(task.connectionState.tintColor)
            }

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

        if task.effectiveDuration > 0 {
            HStack {
                Text("Duration")
                Spacer()
                Text(DurationFormatter.string(from: task.effectiveDuration))
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
private struct ConnectionTimingView: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        VStack(spacing: 16) {
            // Use TimingView for the timeline chart
            if task.effectiveDuration > 0 {
                TimingView(viewModel: makeTimingViewModel())
            }

            // Additional timing info
            if let time = task.createdAt as Date? {
                ConnectionRow(title: "Started", value: DateFormatter.localizedString(from: time, dateStyle: .none, timeStyle: .medium))
            }

            if task.connectionState == .complete, task.effectiveDuration > 0 {
                ConnectionRow(title: "Duration", value: DurationFormatter.string(from: task.effectiveDuration))

                // Transfer rate
                if let upload = task.connectionUpload, let download = task.connectionDownload {
                    let uploadBytes = parseBytes(upload)
                    let downloadBytes = parseBytes(download)
                    let totalBytes = uploadBytes + downloadBytes
                    if totalBytes > 0 {
                        ConnectionRow(title: "Transfer Rate", value: ByteCountFormatter.string(fromByteCount: Int64(Double(totalBytes) / task.effectiveDuration), countStyle: .binary) + "/s")
                    }
                }
            }
        }
    }

    private func makeTimingViewModel() -> TimingViewModel {
        let duration = task.effectiveDuration
        let durationStr = DurationFormatter.string(from: duration)

        var rows: [TimingRowViewModel] = []

        // Connection duration bar
        let color: UXColor = task.connectionState == .connected ? .systemGreen : .systemGray
        rows.append(TimingRowViewModel(
            title: "Connection",
            value: durationStr,
            color: color,
            start: 0.0,
            length: 1.0
        ))

        // Add upload/download visualization if we have data
        if task.connectionState == .complete,
           let upload = task.connectionUpload,
           let download = task.connectionDownload {
            let uploadBytes = parseBytes(upload)
            let downloadBytes = parseBytes(download)
            let totalBytes = uploadBytes + downloadBytes

            if totalBytes > 0 {
                let uploadRatio = CGFloat(uploadBytes) / CGFloat(totalBytes)

                rows.append(TimingRowViewModel(
                    title: "Upload",
                    value: upload,
                    color: .systemBlue,
                    start: 0.0,
                    length: uploadRatio
                ))

                rows.append(TimingRowViewModel(
                    title: "Download",
                    value: download,
                    color: .systemBlue,
                    start: uploadRatio,
                    length: 1.0 - uploadRatio
                ))
            }
        }

        let section = TimingRowSectionViewModel(title: "Timeline", items: rows)
        return TimingViewModel(sections: [section])
    }

    private func parseBytes(_ string: String) -> Int64 {
        // Parse strings like "1.5 MB", "256 KB", etc.
        let components = string.components(separatedBy: " ")
        guard components.count >= 2,
              let value = Double(components[0]) else {
            return 0
        }

        let unit = components[1].uppercased()
        let multiplier: Int64
        switch unit {
        case "B", "BYTES": multiplier = 1
        case "KB": multiplier = 1024
        case "MB": multiplier = 1024 * 1024
        case "GB": multiplier = 1024 * 1024 * 1024
        default: multiplier = 1
        }

        return Int64(value * Double(multiplier))
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
