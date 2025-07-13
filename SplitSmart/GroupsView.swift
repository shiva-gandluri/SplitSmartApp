import SwiftUI

struct GroupsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Groups")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                Text("Groups feature coming soon!")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    GroupsView()
}