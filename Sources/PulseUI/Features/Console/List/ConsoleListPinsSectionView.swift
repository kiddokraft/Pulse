// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(iOS) || os(macOS) || os(tvOS) || os(visionOS)

import CoreData
import Pulse
import Combine
import SwiftUI

@available(iOS 15, macOS 13, tvOS 15, visionOS 1.0, *)
struct ConsoleListPinsSectionView: View {
    @ObservedObject var viewModel: ConsoleListViewModel

    var body: some View {
        let prefix = Array(viewModel.pins.prefix(3))

#if os(iOS) || os(visionOS) || os(macOS)
        PlainListExpandableSectionHeader(title: "Pins", count: viewModel.pins.count, destination: {
            ConsoleStaticList(entities: viewModel.pins)
                .inlineNavigationTitle("Pins")
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: viewModel.buttonRemovePinsTapped) {
                            Image(systemName: "trash")
                        }
                    }
                }
        }, isSeeAllHidden: prefix.count == viewModel.pins.count)

        ForEach(prefix, id: \.pinCellID, content: ConsoleEntityCell.init)
            .listRowSeparator(.hidden)
        #if os(macOS)
    
            .listRowBackground(Color.separator.opacity(0.2))
        #endif

        Button(action: viewModel.buttonRemovePinsTapped) {
            Text("Remove Pins")
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.separator.opacity(0.2))
        .listRowSeparator(.hidden)
        .listRowSeparator(.hidden, edges: .bottom)
        
#else
        Text("Pins")
            .font(.subheadline.weight(.semibold))
            .foregroundColor(.secondary)


        ForEach(prefix, id: \.pinCellID) { entity in
            ConsoleEntityCell(entity: entity)

        }

        Button(action: viewModel.buttonRemovePinsTapped) {
            Text("Remove Pins")
                .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)

#endif
    }
}

private extension NSManagedObject {
    var pinCellID: PinCellId { PinCellId(id: objectID) }
}

private struct PinCellId: Hashable {
    let id: NSManagedObjectID
}

#endif
