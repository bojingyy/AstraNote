import SwiftUI
import AstraCore

struct NotesWorkspaceView: View {
    let searchAction: (String) async -> [NoteSearchResult]
    let lockAction: () async -> Void

    @State private var query = ""
    @State private var results: [NoteSearchResult] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search note titles", text: $query)
                    .textFieldStyle(.roundedBorder)
                Button("Search") {
                    Task {
                        results = await searchAction(query)
                    }
                }
                Button("Lock") {
                    Task {
                        await lockAction()
                    }
                }
            }

            List(results, id: \.noteId) { result in
                HStack {
                    Text(result.isSecure ? "[Secure]" : "[Normal]")
                    Text(result.matchedTitle)
                }
            }

            Spacer()
        }
        .padding()
    }
}
