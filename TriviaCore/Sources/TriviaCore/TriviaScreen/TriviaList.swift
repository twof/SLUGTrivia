import ComposableArchitecture
import Foundation
import URL

@Reducer
public struct TriviaListReducer: StaticLoggingContext {
  public static let loggingCategory: String = "TriviaListReducer"
  
  public typealias DataSource = HTTPDataSourceReducer<[TriviaQuestion]>
  
  public struct State {
    var websocket: WebsocketClient.State
    var httpDataSource: DataSource.State
    public var viewModel: TriviaListViewModel.State
    
    public init(
      httpDataSource: DataSource.State = .init(),
      viewModel: TriviaListViewModel.State = .init()
    ) {
      self.websocket = .init(endpoint: Self.websocketEndpoint())
      self.httpDataSource = httpDataSource
      self.viewModel = viewModel
    }
    
    static func websocketEndpoint() -> URL {
      return #URL("wss://example.com")
    }
  }
  
  public enum Action {
    case task
    
    // Scoped
    case websocket(WebsocketClient.Action)
    case httpDataSource(DataSource.Action)
    case viewModel(TriviaListViewModel.Action)
  }
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    Scope(state: \.websocket, action: \.websocket) {
      WebsocketClient(errorSourceId: Self.loggingCategory)
    }
    
    Scope(state: \.httpDataSource, action: \.httpDataSource) {
      DataSource(errorSourceId: Self.loggingCategory)
    }
    
    Scope(state: \.viewModel, action: \.viewModel) {
      TriviaListViewModel()
    }
    
    Reduce { state, action in
      switch action {
      case .task:
        return .merge(
          .send(.websocket(.task)),
          .send(.httpDataSource(.fetch(
            url: Self.triviaStatusEndpoint().absoluteString,
            decoder: JSONDecoder()
          )))
        )
        
      case let .httpDataSource(.delegate(.response(response))):
        state.viewModel = .init(response: response)
        return .none
        
      case .websocket, .httpDataSource, .viewModel:
        return .none
      }
    }
  }
  
  static func triviaStatusEndpoint() -> URL {
    return #URL("https://example.com/trivia-status")
  }
}

extension TriviaListViewModel.State {
  init(response: [TriviaQuestion]) {
    self.triviaQuestions = response.map {
      TriviaQuestionViewModel(question: $0.type.text, answer: $0.answer?.text ?? "")
    }.toIdentifiedArray
  }
}

@Reducer
public struct TriviaListViewModel {
  @ObservableState
  public struct State {
    public var triviaQuestions: IdentifiedArrayOf<TriviaQuestionViewModel>
    
    public init(triviaQuestions: IdentifiedArrayOf<TriviaQuestionViewModel> = []) {
      self.triviaQuestions = triviaQuestions
    }
  }
  
  public enum Action {
    public enum Delegate {
      case task
    }
    case delegate(Delegate)
    case answerUpdated(id: TriviaQuestionViewModel.ID, newAnswer: String)
  }
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .answerUpdated(id, newAnswer):
        state.triviaQuestions[id: id]?.answer = newAnswer
        
        return .none
      case .delegate:
        return .none
      }
    }
  }
}

public struct TriviaQuestionViewModel: Identifiable {
  public var id: String { question }
  
  public let question: String
  public var answer: String
  
  public init(question: String, answer: String) {
    self.question = question
    self.answer = answer
  }
}
