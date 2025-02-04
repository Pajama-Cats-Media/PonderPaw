import SwiftUI

// Define a simple Story model.
struct Story: Identifiable, Hashable {
    let id: String
    let title: String
    let firebaseLink: URL?
}

struct HomeView: View {
    // Dummy list of recent stories.
    @State private var recentStories: [Story] = [
        Story(id: "1", title: "First Story", firebaseLink: URL(string: "https://example.com/story?storyID=1cd1708e-67f0-4148-a417-b9839e55716e")),
        Story(id: "2", title: "Second Story", firebaseLink: URL(string: "https://example.com/story?storyID=1cd1708e-67f0-4148-a417-b9839e55716e")),
        Story(id: "3", title: "Third Story", firebaseLink: URL(string: "https://example.com/story?storyID=1cd1708e-67f0-4148-a417-b9839e55716e"))
    ]
    
    // NavigationPath to allow programmatic navigation when a dynamic link is opened.
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List(recentStories) { story in
                // Each list row is a NavigationLink that pushes ContentView for the selected story.
                NavigationLink(value: story) {
                    Text(story.title)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("Recent Stories")
            // Handle Firebase Dynamic Link URL open events.
            .onOpenURL { url in
                // Example URL: https://example.com/story?storyID=1
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let queryItems = components.queryItems,
                   let storyIDItem = queryItems.first(where: { $0.name == "storyID" }),
                   let storyID = storyIDItem.value,
                   let matchedStory = recentStories.first(where: { $0.id == storyID }) {
                    // Navigate to the matched story.
                    navigationPath.append(matchedStory)
                }
            }
            // Define the destination view for a Story.
            .navigationDestination(for: Story.self) { story in
                // ContentView should be modified to accept a story identifier.
                ContentView(storyID: story.id)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
