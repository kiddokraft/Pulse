//
// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

import SwiftUI
import CoreData
import Pulse
import Combine

#if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)

struct PinButton: View {
    @ObservedObject var viewModel: PinButtonViewModel
    var isTextNeeded: Bool = true
    var isSwipeAction = false

    var body: some View {
        Button(action: viewModel.togglePin) {
            if isSwipeAction {
                SwipeActionLabel(
                    title: viewModel.isPinned ? "Unpin" : "Pin",
                    systemImage: viewModel.isPinned ? "pin.fill" : "pin"
                )
            } else if isTextNeeded {
                Label(viewModel.isPinned ? "Unpin" : "Pin", systemImage: viewModel.isPinned ? "pin.fill" : "pin")
            } else {
                Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
            }
        }
    }
}

/// Uses the existing pin state and visual placement, while allowing a host to
/// make pin/unpin perform a reversible connection-specific action.
struct ConnectionPinButton: View {
    @ObservedObject private var viewModel: PinButtonViewModel
    private let task: NetworkTaskEntity
    var isTextNeeded: Bool = true
    var isSwipeAction = false
    @EnvironmentObject private var environment: ConsoleEnvironment
    @State private var isUpdating = false

    init(task: NetworkTaskEntity, isTextNeeded: Bool = true, isSwipeAction: Bool = false) {
        self.task = task
        self.isTextNeeded = isTextNeeded
        self.isSwipeAction = isSwipeAction
        _viewModel = ObservedObject(wrappedValue: .init(task))
    }

    var body: some View {
        Button {
            guard !isUpdating else { return }
            guard let action = environment.connectionPinAction else {
                viewModel.togglePin()
                return
            }
            isUpdating = true
            let shouldPause = !viewModel.isPinned
            Task {
                defer { isUpdating = false }
                do {
                    try await action(.init(task), shouldPause)
                    viewModel.togglePin()
                } catch {
                    // The host presents its own error UI. Keep the pin state
                    // unchanged when the network action fails.
                }
            }
        } label: {
            if isSwipeAction {
                SwipeActionLabel(
                    title: viewModel.isPinned ? "Resume" : "Pause",
                    systemImage: viewModel.isPinned ? "pin.fill" : "pin"
                )
            } else if isTextNeeded {
                Label(
                    viewModel.isPinned ? "Resume" : "Pause",
                    systemImage: viewModel.isPinned ? "pin.fill" : "pin"
                )
            } else {
                Image(systemName: viewModel.isPinned ? "pin.fill" : "pin")
            }
        }
        .disabled(isUpdating)
    }
}

private struct SwipeActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .foregroundStyle(.gray)
                .frame(width: 28, height: 28)
                .background(.white, in: Circle())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white)
        }
        .frame(width: 48)
    }
}

struct PinView: View {
    private var message: LoggerMessageEntity?
    @State private var isPinned = false

    init(message: LoggerMessageEntity?) {
        self.message = message
    }

    init(task: NetworkTaskEntity) {
        self.init(message: task.message)
    }

    var body: some View {
        if let message = message {
            Image(systemName: "pin")
                .font(ConsoleConstants.fontTitle)
                .foregroundColor(.pink)
                .opacity(isPinned ? 1 : 0)
                .frame(width: 8, height: 8)
                .onReceive(message.publisher(for: \.isPinned).removeDuplicates()) {
                    isPinned = $0
                }
        }
    }
}

final class PinButtonViewModel: ObservableObject {
    @Published private(set) var isPinned = false
    private let message: LoggerMessageEntity?
    private let pins: LoggerStore.Pins?
    private var cancellables: [AnyCancellable] = []

    init(_ message: LoggerMessageEntity) {
        self.message = message
        self.pins = message.managedObjectContext?.userInfo[pinServiceKey] as? LoggerStore.Pins
        self.subscribe()
    }

    init(_ task: NetworkTaskEntity) {
        self.message = task.message
        self.pins = task.managedObjectContext?.userInfo[pinServiceKey] as? LoggerStore.Pins
        self.subscribe()
    }

    private func subscribe() {
        guard let message = message else { return } // Should never happen
        message.publisher(for: \.isPinned).sink { [weak self] in
            guard let self = self else { return }
            self.isPinned = $0
        }.store(in: &cancellables)
    }

    func togglePin() {
        guard let message = message else { return } // Should never happen
        pins?.togglePin(for: message)
    }
}
#endif

private let pinServiceKey = "com.github.kean.pulse.pin-service"
