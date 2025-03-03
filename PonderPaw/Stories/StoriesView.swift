import SwiftUI

/// A view that displays a list of stories for a given user.
struct StoriesView: View {
    // The view model is initialized with the input userId.
    @StateObject private var viewModel: StoriesViewModel

    /// Initialize StoriesView with a Firebase userId.
    init(userId: String) {
        _viewModel = StateObject(wrappedValue: StoriesViewModel(userId: userId))
    }
    
    var body: some View {
        Group {
            if viewModel.stories.isEmpty {
                // Show a message when there are no items.
                Text("No items here...")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // Display the list of stories with pull-to-refresh.
                List(viewModel.stories) { story in
                    NavigationLink(destination: StoryPlayView(storyID: story.id)) {
                        Text(story.doc_title)
                            .padding(.vertical, 8)
                    }
                }
                .refreshable {
                    viewModel.loadStories()
                }
            }
        }
        .navigationTitle("Stories")
    }
}
