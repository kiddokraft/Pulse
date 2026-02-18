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
        public let uplinkRate: Int64        // Current upload speed (bytes/s)
        public let downlinkRate: Int64      // Current download speed (bytes/s)
        public let createdAt: Int64
        public let closedAt: Int64
        public let chain: [String]
        public let user: String
        public let fromOutbound: String

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
            chain: [String] = [],
            uplinkRate: Int64 = 0,
            downlinkRate: Int64 = 0,
            user: String = "",
            fromOutbound: String = ""
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
            self.uplinkRate = uplinkRate
            self.downlinkRate = downlinkRate
            self.createdAt = createdAt
            self.closedAt = closedAt
            self.chain = chain
            self.user = user
            self.fromOutbound = fromOutbound
        }
    }

    /// Stores or updates a proxy/VPN connection as a network task entry.
    ///
    /// This method uses a stable UUID derived from the connection ID, allowing
    /// the same connection to be updated when its state changes (active → closed).
    ///
    /// - Parameter connection: The connection info to store or update.
    public func storeConnection(_ connection: ConnectionInfo) {
        // Skip DNS connections as they are typically internal
        guard connection.outboundType != "dns" else { return }

        // Generate stable UUID from connection ID for update support
        let taskId = stableUUID(from: connection.id)

        // Build URL from connection info
        let urlString = buildConnectionURL(from: connection)
        guard let url = URL(string: urlString) else { return }

        // Create URLRequest with connection metadata in headers
        var request = URLRequest(url: url)
        request.httpMethod = connection.network.uppercased()  // TCP or UDP

        // Store connection metadata in request headers
        request.setValue(connection.id, forHTTPHeaderField: "Connection-ID")
        request.setValue(connection.network, forHTTPHeaderField: "Connection-Network")

        // IP version: 0 = FakeIP (DNS technique), 4 = IPv4, 6 = IPv6
        let ipVersionString: String
        switch connection.ipVersion {
        case 0: ipVersionString = "FakeIP"
        case 4: ipVersionString = "IPv4"
        case 6: ipVersionString = "IPv6"
        default: ipVersionString = "IPv\(connection.ipVersion)"
        }
        request.setValue(ipVersionString, forHTTPHeaderField: "Connection-IP-Version")
        request.setValue(connection.source, forHTTPHeaderField: "Connection-Source")
        request.setValue(connection.destination, forHTTPHeaderField: "Connection-Destination")
        if !connection.domain.isEmpty {
            request.setValue(connection.domain, forHTTPHeaderField: "Connection-Domain")
        }
        if !connection.connectionProtocol.isEmpty {
            request.setValue(connection.connectionProtocol, forHTTPHeaderField: "Connection-Protocol")
        }
        request.setValue(connection.inbound, forHTTPHeaderField: "Connection-Inbound")
        request.setValue(connection.inboundType, forHTTPHeaderField: "Connection-Inbound-Type")
        if !connection.user.isEmpty {
            request.setValue(connection.user, forHTTPHeaderField: "Connection-User")
        }
        if !connection.fromOutbound.isEmpty {
            request.setValue(connection.fromOutbound, forHTTPHeaderField: "Connection-From-Outbound")
        }

        // Create response with outbound/routing info in headers
        var responseHeaders: [String: String] = [:]
        responseHeaders["Connection-Outbound"] = connection.outbound
        responseHeaders["Connection-Outbound-Type"] = connection.outboundType
        responseHeaders["Connection-Rule"] = connection.rule
        responseHeaders["Connection-Upload"] = formatBytes(connection.uplinkTotal)
        responseHeaders["Connection-Download"] = formatBytes(connection.downlinkTotal)
        responseHeaders["Connection-Upload-Bytes"] = String(connection.uplinkTotal)
        responseHeaders["Connection-Download-Bytes"] = String(connection.downlinkTotal)
        if connection.uplinkRate > 0 {
            responseHeaders["Connection-Upload-Rate"] = formatBytes(connection.uplinkRate) + "/s"
        }
        if connection.downlinkRate > 0 {
            responseHeaders["Connection-Download-Rate"] = formatBytes(connection.downlinkRate) + "/s"
        }
        if !connection.chain.isEmpty {
            responseHeaders["Connection-Chain"] = connection.chain.joined(separator: " → ")
        }

        // Store timing info (timestamps are in milliseconds from sing-box)
        responseHeaders["Connection-Start"] = String(connection.createdAt)
        let isComplete = connection.closedAt > 0
        if isComplete {
            // Closed connection: calculate final duration
            let durationMs = connection.closedAt - connection.createdAt
            let durationSeconds = Double(durationMs) / 1000.0
            responseHeaders["Connection-Duration"] = String(format: "%.3f", durationSeconds)
        } else if connection.createdAt > 0 {
            // Active connection: calculate elapsed duration from creation to now
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let durationMs = nowMs - connection.createdAt
            let durationSeconds = Double(durationMs) / 1000.0
            responseHeaders["Connection-Duration"] = String(format: "%.3f", durationSeconds)
        }

        // Build NetworkLogger.Response directly instead of going through HTTPURLResponse,
        // which can return nil for non-HTTP URL schemes (tcp://, udp://).
        var networkResponse = NetworkLogger.Response(
            URLResponse(url: url, mimeType: nil, expectedContentLength: -1, textEncodingName: nil)
        )
        networkResponse.statusCode = isComplete ? 200 : 102  // 102 = Processing (active), 200 = Complete
        networkResponse.headers = responseHeaders

        // Build descriptive task description
        let taskDescription = buildTaskDescription(from: connection)
        let label = "\(connection.inbound)/\(connection.inboundType)"

        // Use Pulse's event system with stable taskId for update support
        handle(.networkTaskCompleted(.init(
            taskId: taskId,
            taskType: .dataTask,
            createdAt: Date(timeIntervalSince1970: Double(connection.createdAt) / 1000.0),
            originalRequest: NetworkLogger.Request(request),
            currentRequest: NetworkLogger.Request(request),
            response: networkResponse,
            error: nil,
            requestBody: nil,
            responseBody: nil,
            metrics: nil,
            label: label,
            taskDescription: taskDescription
        )))
    }

    // MARK: - Private Helpers

    /// Generates a stable UUID from a string identifier.
    /// This ensures the same connection ID always produces the same UUID.
    private func stableUUID(from string: String) -> UUID {
        // Use UUID v5 (name-based, SHA-1) with a custom namespace
        // Namespace UUID for Pulse connections
        let namespace = UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")! // DNS namespace
        return UUID(name: string, namespace: namespace)
    }

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

// MARK: - UUID v5 Extension

extension UUID {
    /// Creates a UUID v5 (name-based, SHA-1) from a name and namespace.
    init(name: String, namespace: UUID) {
        // Convert namespace UUID to bytes
        var namespaceBytes = [UInt8](repeating: 0, count: 16)
        let uuid = namespace.uuid
        namespaceBytes[0] = uuid.0
        namespaceBytes[1] = uuid.1
        namespaceBytes[2] = uuid.2
        namespaceBytes[3] = uuid.3
        namespaceBytes[4] = uuid.4
        namespaceBytes[5] = uuid.5
        namespaceBytes[6] = uuid.6
        namespaceBytes[7] = uuid.7
        namespaceBytes[8] = uuid.8
        namespaceBytes[9] = uuid.9
        namespaceBytes[10] = uuid.10
        namespaceBytes[11] = uuid.11
        namespaceBytes[12] = uuid.12
        namespaceBytes[13] = uuid.13
        namespaceBytes[14] = uuid.14
        namespaceBytes[15] = uuid.15

        // Concatenate namespace and name
        let nameBytes = [UInt8](name.utf8)
        let data = namespaceBytes + nameBytes

        // Compute SHA-1 hash
        var hash = [UInt8](repeating: 0, count: 20)
        data.withUnsafeBytes { dataPtr in
            hash.withUnsafeMutableBytes { hashPtr in
                _ = CC_SHA1(dataPtr.baseAddress, CC_LONG(data.count), hashPtr.baseAddress?.assumingMemoryBound(to: UInt8.self))
            }
        }

        // Set version (5) and variant bits
        hash[6] = (hash[6] & 0x0F) | 0x50  // Version 5
        hash[8] = (hash[8] & 0x3F) | 0x80  // Variant

        // Create UUID from first 16 bytes of hash
        self.init(uuid: (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        ))
    }
}

// Import CommonCrypto for SHA-1
import CommonCrypto
