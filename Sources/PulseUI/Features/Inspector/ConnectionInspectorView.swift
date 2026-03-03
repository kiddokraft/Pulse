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
    @State private var tick: UInt = 0
    @EnvironmentObject private var environment: ConsoleEnvironment
    @Environment(\.store) private var store

    var body: some View {
        let _ = tick
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if task.connectionState == .connected {
                tick &+= 1
            }
        }
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
            ConnectionDetailsSection(task: task)
        }

        // Routing Information
        Section("Routing") {
            ConnectionRoutingView(task: task)
        }

        // Traffic Statistics
        Section("Traffic") {
            ConnectionTrafficView(task: task)
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

// MARK: - Connection Details Section

@available(iOS 15, visionOS 1.0, *)
private struct ConnectionDetailsSection: View {
    @ObservedObject var task: NetworkTaskEntity

    var body: some View {
        // Network type (TCP/UDP)
        if let network = task.httpMethod {
            ConnectionDetailRow(title: "Network", value: network.uppercased())
        }

        if let ipVersion = task.connectionIPVersion, !ipVersion.isEmpty {
            ConnectionDetailRow(title: "IP Version", value: ipVersion)
        }

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

        if let user = task.connectionUser, !user.isEmpty {
            ConnectionDetailRow(title: "User", value: user)
        }

        if let fromOutbound = task.connectionFromOutbound, !fromOutbound.isEmpty {
            ConnectionDetailRow(title: "From Outbound", value: fromOutbound)
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
        // Upload total
        if let upload = task.connectionUpload {
            HStack {
                Label("Upload", systemImage: "arrow.up").foregroundColor(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(upload)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    if task.connectionState == .connected,
                       let rate = task.connectionUploadRate {
                        Text(rate)
                            .font(.caption)
                            .foregroundColor(Color(red: 0.620, green: 0.224, blue: 0.000))
                            .monospacedDigit()
                    }
                }
            }
        }

        // Download total
        if let download = task.connectionDownload {
            HStack {
                Label("Download", systemImage: "arrow.down").foregroundColor(.primary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(download)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                    if task.connectionState == .connected,
                       let rate = task.connectionDownloadRate {
                        Text(rate)
                            .font(.caption)
                            .foregroundColor(Color(red: 1.000, green: 0.541, blue: 0.000))
                            .monospacedDigit()
                    }
                }
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
            TimingView(viewModel: ConnectionTimingBuilder.makeTimingViewModel(for: task))
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
    @State private var tick: UInt = 0
    @Environment(\.store) private var store

    var body: some View {
        let _ = tick
        VStack(spacing: 0) {
            toolbar
            Divider()
            ConnectionTimingViewMac(task: task)
            Divider()
            RichTextView(viewModel: makeSummaryViewModel())


        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if task.connectionState == .connected {
                tick &+= 1
            }
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
        TimingView(viewModel: ConnectionTimingBuilder.makeTimingViewModel(for: task))
            .padding()
    }
}

#endif

// MARK: - Shared Timing Builder (all platforms)

/// Shared timing view model builder used by both iOS and macOS.
enum ConnectionTimingBuilder {
    static func makeTimingViewModel(for task: NetworkTaskEntity) -> TimingViewModel {
        let uploadBytes = task.connectionUploadBytes ?? 0
        let downloadBytes = task.connectionDownloadBytes ?? 0
        let totalBytes = uploadBytes + downloadBytes
        let isActive = task.connectionState == .connected

        var rows: [TimingRowViewModel] = []

        // Upload bar — starts at 0, length = upload share of total
        let uploadStr: String
        if isActive, let rate = task.connectionUploadRate {
            uploadStr = (task.connectionUpload ?? "0 B") + " (\(rate))"
        } else {
            uploadStr = task.connectionUpload ?? "0 B"
        }
        let uploadFraction: CGFloat = totalBytes > 0 ? CGFloat(uploadBytes) / CGFloat(totalBytes) : 0.5
        rows.append(TimingRowViewModel(
            title: "Upload",
            value: uploadStr,
            color: UXColor(red: 0.620, green: 0.224, blue: 0.000, alpha: 1.0),
            start: 0.0,
            length: max(0.02, uploadFraction)
        ))

        // Download bar — starts where upload ends, length = download share of total
        let downloadStr: String
        if isActive, let rate = task.connectionDownloadRate {
            downloadStr = (task.connectionDownload ?? "0 B") + " (\(rate))"
        } else {
            downloadStr = task.connectionDownload ?? "0 B"
        }
        let downloadFraction: CGFloat = totalBytes > 0 ? CGFloat(downloadBytes) / CGFloat(totalBytes) : 0.5
        rows.append(TimingRowViewModel(
            title: "Download",
            value: downloadStr,
            color: UXColor(red: 1.000, green: 0.541, blue: 0.000, alpha: 1.0),
            start: totalBytes > 0 ? uploadFraction : 0.5,
            length: max(0.02, downloadFraction)
        ))

        let section = TimingRowSectionViewModel(
            title: isActive ? "Active Connection" : "Connection",
            items: rows
        )
        return TimingViewModel(sections: [section])
    }
}

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
