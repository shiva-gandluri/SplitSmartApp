import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("History")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                Text("Transaction history coming soon!")
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HistoryView()
}