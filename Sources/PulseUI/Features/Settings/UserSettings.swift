// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import Pulse
import Combine

/// Asset catalog color names used to customize connection UI elements.
public struct ConnectionColorAssetNames {
    /// The asset name for an active connection. Defaults to `connected`.
    public var connected: String?

    /// The asset name for a completed connection. Defaults to `complete`.
    public var complete: String?

    /// The asset name for upload traffic. Defaults to `upload`.
    public var upload: String?

    /// The asset name for download traffic. Defaults to `download`.
    public var download: String?

    public init(
        connected: String? = "connected",
        complete: String? = "complete",
        upload: String? = "upload",
        download: String? = "download"
    ) {
        self.connected = connected
        self.complete = complete
        self.upload = upload
        self.download = download
    }
}

/// Allows you to control Pulse appearance and other settings programmatically.
public final class UserSettings: ObservableObject {
    public static let shared = UserSettings()

    /// The console default mode.
    @AppStorage("com.github.kean.pulse.console.mode")
    public var mode: ConsoleMode = .network

    /// The line limit for messages in the console. By default, `3`.
    @AppStorage("com.github.kean.pulse.console.cell.line.limit")
    public var lineLimit: Int = 3

    /// Enables link detection in the response viewier. By default, `false`.
    @AppStorage("com.github.kean.pulse.link.detection")
    public var isLinkDetectionEnabled = false

    /// The default sharing output type. By default, ``ShareStoreOutput/text``.
    @AppStorage("com.github.kean.pulse.sharing.output")
    public var sharingOutput: ShareStoreOutput = .text

    /// Asset catalog color names used by active connections and traffic charts.
    ///
    /// Pulse looks up these colors in the host application's main bundle. Missing
    /// assets fall back to Pulse's system colors.
    public var connectionColorAssetNames = ConnectionColorAssetNames()

    /// HTTP headers to display in a Console. By default, empty.
    public var displayHeaders: [String] {
        get {
            let data = rawDisplayHeaders.data(using: .utf8) ?? Data()
            return (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            rawDisplayHeaders = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    @AppStorage("com.github.kean.pulse.display.headers")
    var rawDisplayHeaders: String = "[]"

    /// If `true`, the network inspector will show the current request by default.
    /// If `false`, show the original request.
    @AppStorage("com.github.kean.pulse.show-current-request")
    public var isShowingCurrentRequest = true
}
