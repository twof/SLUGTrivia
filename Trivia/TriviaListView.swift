import SwiftUI
import TriviaCore
import ComposableArchitecture

struct TriviaListView: View {
  let store: StoreOf<TriviaListReducer>
  
  var body: some View {
    List {
      ForEach(store)
    }
  }
}

#Preview {
  TriviaListView()
}
