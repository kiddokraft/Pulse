// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI

struct RichTextViewSearchToobar: View {
    @ObservedObject var viewModel: RichTextViewModel

    var isSearchOptionsHidden = false

    var body: some View {
        HStack {
            if !viewModel.matches.isEmpty {
                HStack(spacing: 8) {
                    Button(action: viewModel.previousMatch) {
                        Image(systemName: "chevron.left")
//                            .foregroundColor(.secondary)
                    }
//                    .buttonStyle(.plain)
                    .disabled(viewModel.matches.isEmpty)
//                    .padding(.horizontal, 8).padding(.vertical, 4)
//                    .background {
//                        RoundedRectangle(cornerRadius: 6).foregroundStyle(Color.primary.opacity(0.1))
//                    }

                    Text(viewModel.matches.isEmpty ? "0 / 0" : "\(viewModel.selectedMatchIndex+1) / \(viewModel.matches.count)")
                        .font(Font.body.monospacedDigit())
//                        .foregroundColor(.secondary)
//                        .padding(.horizontal, 8).padding(.vertical, 4)
//                        .background {
//                            RoundedRectangle(cornerRadius: 6).foregroundStyle(Color.primary.opacity(0.1))
//                        }

                    Button(action: viewModel.nextMatch) {
                        Image(systemName: "chevron.right")
//                            .foregroundColor(.secondary)
                    }
//                    .buttonStyle(.plain)
                    .disabled(viewModel.matches.isEmpty)
//                    .padding(.horizontal, 8).padding(.vertical, 4)
//                    .background {
//                        RoundedRectangle(cornerRadius: 6).foregroundStyle(Color.primary.opacity(0.1))
//                    }
                    
                }
//                .padding(.horizontal, 8).padding(.vertical, 4)
//                .background {
//                    RoundedRectangle(cornerRadius: 6).foregroundStyle(Color.primary.opacity(0.1))
//                }
            }

            Spacer()

            if viewModel.isFilterEnabled {
                SearchBar(title: "Filter", imageName: "line.3.horizontal.decrease.circle", text: $viewModel.filterTerm).frame(maxWidth: 130)
            }

            SearchBar(title: "Search", text: $viewModel.searchTerm).frame(maxWidth: 130)

            StringSearchOptionsMenu(options: $viewModel.searchOptions, isKindNeeded: false)
                    .fixedSize()
        }
        .padding()
    }
}

#endif
