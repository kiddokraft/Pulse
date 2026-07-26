// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import PulseUI

@main
struct Pulse_tvOSApp: App {
    init() {
        UserSettings.shared.mode = .connection
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
