//
//  Extension+PulseNetwork.swift
//
//  Bridges Libbox connections to Pulse network logging.
//  This file should be included in applications that use both Pulse and Libbox.
//

import Foundation
import Pulse
import Libbox

// MARK: - Libbox Connection Storage

extension LoggerStore {

    /// Stores a Libbox connection as a Pulse network task.
    ///
    /// This method converts a LibboxConnection to the generic ConnectionInfo format
    /// and stores it using Pulse's connection logging system.
    ///
    /// - Parameter connection: The Libbox connection to store.
    func storeConnection(_ connection: LibboxConnection) {
        // Extract chain from iterator
        var chainArray: [String] = []
        if let chainIterator = connection.chain() {
            while chainIterator.hasNext() {
                chainArray.append(chainIterator.next())
            }
        }

        // Convert LibboxConnection to generic ConnectionInfo
        let connectionInfo = ConnectionInfo(
            id: connection.id_,
            network: connection.network,
            source: connection.source,
            destination: connection.destination,
            domain: connection.domain,
            connectionProtocol: connection.`protocol`,
            inbound: connection.inbound,
            inboundType: connection.inboundType,
            outbound: connection.outbound,
            outboundType: connection.outboundType,
            rule: connection.rule,
            ipVersion: connection.ipVersion,
            uplinkTotal: connection.uplinkTotal,
            downlinkTotal: connection.downlinkTotal,
            createdAt: connection.createdAt,
            closedAt: connection.closedAt,
            chain: chainArray
        )

        // Store using the generic method
        storeConnection(connectionInfo)
    }
}

// MARK: - Log Parsing

extension LoggerStore {

    /// Parses and stores a log message from Libbox.
    ///
    /// Expected format: "timestamp level [tag] message"
    /// Example: "2024-01-15 10:30:45 info [router] DNS query resolved"
    ///
    /// - Parameter logString: The raw log string from Libbox.
    func storeParsedLog(from logString: String?) {
        guard let logString = logString, !logString.isEmpty else { return }

        // Parse log level and message
        let (level, message, label) = parseLogString(logString)

        storeMessage(
            label: label,
            level: level,
            message: message
        )
    }

    /// Parses a Libbox log string into components.
    ///
    /// - Parameter logString: The raw log string.
    /// - Returns: Tuple of (level, message, label).
    private func parseLogString(_ logString: String) -> (Level, String, String) {
        // Default values
        var level: Level = .debug
        var message = logString
        var label = "libbox"

        // Try to parse level from common log patterns
        let lowercased = logString.lowercased()

        if lowercased.contains("error") || lowercased.contains("[error]") {
            level = .error
        } else if lowercased.contains("warn") || lowercased.contains("[warn]") {
            level = .warning
        } else if lowercased.contains("info") || lowercased.contains("[info]") {
            level = .info
        } else if lowercased.contains("debug") || lowercased.contains("[debug]") {
            level = .debug
        } else if lowercased.contains("trace") || lowercased.contains("[trace]") {
            level = .trace
        }

        // Try to extract tag/label from [tag] pattern
        if let tagStart = logString.firstIndex(of: "["),
           let tagEnd = logString.firstIndex(of: "]"),
           tagStart < tagEnd {
            let tagRange = logString.index(after: tagStart)..<tagEnd
            let tag = String(logString[tagRange])

            // Use tag as label if it's not a log level
            let levelTags = ["error", "warn", "warning", "info", "debug", "trace"]
            if !levelTags.contains(tag.lowercased()) {
                label = tag
            }

            // Extract message after the tag
            let afterTag = logString.index(after: tagEnd)
            if afterTag < logString.endIndex {
                message = String(logString[afterTag...]).trimmingCharacters(in: .whitespaces)
            }
        }

        return (level, message, label)
    }
}
