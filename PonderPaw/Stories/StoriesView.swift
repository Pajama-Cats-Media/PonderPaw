import SwiftUI

/// A view that displays a list of stories for a given user.
struct StoriesView: View {
    @StateObject private var viewModel: StoriesViewModel

    init(userId: String) {
        _viewModel = StateObject(wrappedValue: StoriesViewModel(userId: userId))
    }
    
    var body: some View {
        Group {
            if viewModel.stories.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.gray.opacity(0.7))
                    
                    Text("No stories available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Check back later or try refreshing.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                List(viewModel.stories) { story in
                    NavigationLink(destination: StoryPlayView(storyID: story.id)) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text(story.doc_title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Tap to read")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    viewModel.loadStories()
                }
            }
        }
        .navigationTitle("Documents")
        .navigationBarTitleDisplayMode(.inline)
    }
}
