import SwiftUI
import ComposableArchitecture
import TriviaCore

@main
struct TriviaApp: App {
  let store = Store(initialState: TriviaListReducer.State(), reducer: { TriviaListReducer() })
  
  var body: some Scene {
    WindowGroup {
      TriviaListView(store: store.scope(state: \.viewModel, action: \.viewModel))
    }
  }
}
