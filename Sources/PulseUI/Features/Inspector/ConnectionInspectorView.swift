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
        VStack(spacing: 0){
          
            
            List {
           
                    ConnectionTimingView(task: task)
                
                contents
            }
            .listStyle(.inset)
        }
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
//        Section {
//            ConnectionHeaderView(task: task)
//          
//        }
//        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//        .listRowBackground(Color.clear)
        
    
//            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//            .listRowBackground(Color.clear)

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
//        if task.effectiveDuration > 0 {
//            Section("Timing") {
//               
//            }
//        }
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

// MARK: - Connection Header View (Simplified like macOS)

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionHeaderView: View {
    @ObservedObject var task: NetworkTaskEntity
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
            // Status with indicator
           
                if task.connectionState == .connected {
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

                Text("•")
                    .foregroundColor(.secondary)
                Text(task.httpMethod ?? "TCP")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let ipVersion = task.connectionIPVersion {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(ipVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let connectionProtocol = task.connectionProtocol {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(connectionProtocol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }

            // Transfer summary
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(task.connectionUpload ?? "0 KB")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(task.connectionDownload ?? "0 KB")
                        .font(.subheadline.monospacedDigit())
                        .foregroundColor(.secondary)
                }

                if task.effectiveDuration > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(DurationFormatter.string(from: task.effectiveDuration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
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
//            if task.effectiveDuration > 0 {
                TimingView(viewModel: makeTimingViewModel())
//            }

            // Additional timing info
//            VStack(spacing: 8) {
//                if let start = task.createdAt as Date? {
//                    HStack {
//                        Text("Started")
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Text(start, style: .time)
//                            .font(.system(.body, design: .monospaced))
//                            .foregroundColor(.secondary)
//                    }
//                }
//
//                if task.connectionState == .complete, task.effectiveDuration > 0 {
//                    HStack {
//                        Text("Duration")
//                            .foregroundColor(.secondary)
//                        Spacer()
//                        Text(DurationFormatter.string(from: task.effectiveDuration))
//                            .font(.system(.body, design: .monospaced))
//                            .foregroundColor(.secondary)
//                    }
//
//                    // Transfer rate
//                    if let upload = task.connectionUpload, let download = task.connectionDownload {
//                        let uploadBytes = parseBytes(upload)
//                        let downloadBytes = parseBytes(download)
//                        let totalBytes = uploadBytes + downloadBytes
//                        if totalBytes > 0 {
//                            HStack {
//                                Text("Transfer Rate")
//                                    .foregroundColor(.secondary)
//                                Spacer()
//                                Text(ByteCountFormatter.string(fromByteCount: Int64(Double(totalBytes) / task.effectiveDuration), countStyle: .binary) + "/s")
//                                    .font(.system(.body, design: .monospaced))
//                                    .foregroundColor(.secondary)
//                            }
//                        }
//                    }
//                }
//            }
        }
    }

    private func makeTimingViewModel() -> TimingViewModel {
        let duration = task.effectiveDuration
        let durationStr = DurationFormatter.string(from: duration)

        var rows: [TimingRowViewModel] = []

        // Connection duration bar
        let color: UXColor = task.connectionState == .connected ? .systemOrange : .systemGreen
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
                    color: .systemPurple,
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
    @Environment(\.store) private var store

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            ConnectionTimingViewMac(task: task)
            Divider()
            RichTextView(viewModel: makeSummaryViewModel())
           
            
        }
    }

    private func makeSummaryViewModel() -> RichTextViewModel {
        let renderer = TextRenderer(options: .sharing)
        renderer.renderConnectionFull(task, store: store)
        let viewModel = RichTextViewModel(string: renderer.make())
        viewModel.isFilterEnabled = true
        return viewModel
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack {
            Text(task.connectionDomain ?? task.host ?? "Connection")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            ButtonCloseDetailsView()
        }
        .padding(.horizontal, 10)
        .frame(height: 27, alignment: .center)
    }
}

// MARK: - macOS Timing View

@available(macOS 13, *)
private struct ConnectionTimingViewMac: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        TimingView(viewModel: makeTimingViewModel())
                    .padding()

    }

    private func makeTimingViewModel() -> TimingViewModel {
        let duration = task.effectiveDuration
        let durationStr = DurationFormatter.string(from: duration)

        var rows: [TimingRowViewModel] = []

        // Connection duration bar
        let color: UXColor = task.connectionState == .connected ? .systemOrange : .systemGreen
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
                    color: .systemPurple,
                    start: uploadRatio,
                    length: 1.0 - uploadRatio
                ))
            }
        }

        let section = TimingRowSectionViewModel(title: "Timeline", items: rows)
        return TimingViewModel(sections: [section])
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
