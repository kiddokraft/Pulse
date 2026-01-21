// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import Foundation

// MARK: - Connection Data Types

extension LoggerStore {

    /// Represents connection data from a proxy/VPN service like sing-box.
    /// This structure captures all relevant connection metadata for logging.
    public struct ConnectionInfo {
        public let id: String
        public let network: String          // "tcp" or "udp"
        public let source: String
        public let destination: String
        public let domain: String
        public let connectionProtocol: String
        public let inbound: String
        public let inboundType: String
        public let outbound: String
        public let outboundType: String
        public let rule: String
        public let ipVersion: Int32
        public let uplinkTotal: Int64
        public let downlinkTotal: Int64
        public let createdAt: Int64
        public let closedAt: Int64
        public let chain: [String]

        public init(
            id: String,
            network: String,
            source: String,
            destination: String,
            domain: String,
            connectionProtocol: String,
            inbound: String,
            inboundType: String,
            outbound: String,
            outboundType: String,
            rule: String,
            ipVersion: Int32,
            uplinkTotal: Int64,
            downlinkTotal: Int64,
            createdAt: Int64,
            closedAt: Int64,
            chain: [String] = []
        ) {
            self.id = id
            self.network = network
            self.source = source
            self.destination = destination
            self.domain = domain
            self.connectionProtocol = connectionProtocol
            self.inbound = inbound
            self.inboundType = inboundType
            self.outbound = outbound
            self.outboundType = outboundType
            self.rule = rule
            self.ipVersion = ipVersion
            self.uplinkTotal = uplinkTotal
            self.downlinkTotal = downlinkTotal
            self.createdAt = createdAt
            self.closedAt = closedAt
            self.chain = chain
        }
    }

    /// Stores a proxy/VPN connection as a network task entry.
    ///
    /// Connection tasks are differentiated from regular HTTP network tasks by using
    /// TCP/UDP as the HTTP method. This allows filtering in the Console UI.
    ///
    /// - Parameter connection: The connection info to store.
    public func storeConnection(_ connection: ConnectionInfo) {
        // Skip DNS connections as they are typically internal
        guard connection.outboundType != "dns" else { return }

        // Build URL from connection info
        let urlString = buildConnectionURL(from: connection)
        guard let url = URL(string: urlString) else { return }

        // Create URLRequest with connection metadata in headers
        var request = URLRequest(url: url)
        request.httpMethod = connection.network.uppercased()  // TCP or UDP

        // Store connection metadata in request headers
        request.setValue(connection.network, forHTTPHeaderField: "X-Network")
        request.setValue("IPv\(connection.ipVersion)", forHTTPHeaderField: "X-IP-Version")
        request.setValue(connection.source, forHTTPHeaderField: "X-Source")
        request.setValue(connection.destination, forHTTPHeaderField: "X-Destination")
        if !connection.domain.isEmpty {
            request.setValue(connection.domain, forHTTPHeaderField: "X-Domain")
        }
        if !connection.connectionProtocol.isEmpty {
            request.setValue(connection.connectionProtocol, forHTTPHeaderField: "X-Protocol")
        }
        request.setValue(connection.inbound, forHTTPHeaderField: "X-Inbound")
        request.setValue(connection.inboundType, forHTTPHeaderField: "X-Inbound-Type")

        // Create response with outbound/routing info in headers
        var responseHeaders: [String: String] = [:]
        responseHeaders["X-Outbound"] = connection.outbound
        responseHeaders["X-Outbound-Type"] = connection.outboundType
        responseHeaders["X-Rule"] = connection.rule
        responseHeaders["X-Upload"] = formatBytes(connection.uplinkTotal)
        responseHeaders["X-Download"] = formatBytes(connection.downlinkTotal)
        if !connection.chain.isEmpty {
            responseHeaders["X-Chain"] = connection.chain.joined(separator: " → ")
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: connection.closedAt > 0 ? 200 : 102,  // 102 = Processing (ongoing)
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )

        // Build descriptive task description
        let taskDescription = buildTaskDescription(from: connection)
        let label = "\(connection.inbound)/\(connection.inboundType)"

        // Store using the existing network task storage mechanism
        storeRequest(
            request,
            response: response,
            error: nil,
            data: nil,
            metrics: nil,
            label: label,
            taskDescription: taskDescription
        )
    }

    // MARK: - Private Helpers

    private func buildConnectionURL(from connection: ConnectionInfo) -> String {
        let scheme = connection.network  // "tcp" or "udp"
        let host: String
        if !connection.domain.isEmpty {
            host = connection.domain
        } else {
            // Clean destination for URL (remove IPv6 brackets)
            host = connection.destination
                .replacingOccurrences(of: "[", with: "")
                .replacingOccurrences(of: "]", with: "")
        }
        let encodedHost = host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? host
        return "\(scheme)://\(encodedHost)"
    }

    private func buildTaskDescription(from connection: ConnectionInfo) -> String {
        var parts: [String] = []

        // Use domain if available, otherwise destination
        if !connection.domain.isEmpty {
            parts.append(connection.domain)
        } else {
            parts.append(connection.destination)
        }

        if !connection.rule.isEmpty {
            parts.append("→ \(connection.rule)")
        }
        parts.append("→ \(connection.outbound)")

        return parts.joined(separator: " ")
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}
