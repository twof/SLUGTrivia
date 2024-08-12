import SwiftUI

struct TeamRegistration: View {
  @State var teamName: String = ""
  
  var body: some View {
    VStack {
      TextField(text: $teamName, label: { Text("Team Name") })
      Button {
        <#code#>
      } label: {
        Text("Submit")
      }
    }
  }
}
