import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "mic.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Talk to Text")
                .font(.title)
            Text("Use the menu bar icon to start recording")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}