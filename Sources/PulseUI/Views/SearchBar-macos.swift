// The MIT License (MIT)
//
// Copyright (c) 2020-2024 Alexander Grebenyuk (github.com/kean).

#if os(macOS)

import SwiftUI
import Combine

struct SearchBar: View {
    private let title: String
    private let imageName: String
    @Binding private var text: String

    init(title: String,
         imageName: String = "magnifyingglass",
         text: Binding<String>) {
        self.title = title
        self.imageName = imageName
        self._text = text
    }

    var body: some View {
        HStack {
            Image(systemName: imageName)
            TextField(title, text: $text).textFieldStyle(.plain)
                .onSubmit {
                    if !text.isEmpty {
                        text = ""
                    }
                }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .overlay {
            RoundedRectangle(cornerRadius: 6).foregroundStyle(Color.primary.opacity(0.1))
                .allowsHitTesting(false)
        }
    }
}

#if DEBUG
struct Previews_SearchBar_macos_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarDemo().padding()
    }
}

private struct SearchBarDemo: View {
    @State var value = ""

    var body: some View {
        SearchBar(title: "Search", text: $value)
    }
}
#endif

#endif
