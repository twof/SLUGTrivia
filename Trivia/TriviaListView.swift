import SwiftUI
import TriviaCore
import ComposableArchitecture

struct TriviaListView: View {
  let store: StoreOf<TriviaListViewModel>
  
  var body: some View {
    List {
      ForEach(store.triviaQuestions) { questionItem in
        TriviaQuestionRow(
          question: questionItem.question,
          answer: Binding(
            get: { questionItem.answer },
            set: { store.send(.answerUpdated(id: questionItem.id, newAnswer: $0)) }
          )
        )
      }
    }
  }
}

struct TriviaQuestionRow: View {
  let question: String
  @Binding var answer: String
  
  var body: some View {
    VStack(alignment: .leading) {
      Text(question)
        .font(.headline)
        .padding(.vertical, 10)
      
      TextField(text: $answer, label: { Text("Answer") })
        .lineLimit(10)
    }
  }
}

#Preview {
  TriviaListView(store: Store(
    initialState: TriviaListViewModel.State(triviaQuestions: [
      .init(question: "When was the iPhone first released?", answer: ""),
      .init(question: "How many Steves founded Apple?", answer: "A very very very very very very very very very very very very very very very very very very long answer")
    ]),
    reducer: { TriviaListViewModel() }
  ))
}
