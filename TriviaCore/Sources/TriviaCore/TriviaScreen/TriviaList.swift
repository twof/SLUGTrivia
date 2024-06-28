import ComposableArchitecture
import Foundation

@Reducer
public struct TriviaListReducer: StaticLoggingContext {
  public static let loggingCategory: String = "TriviaListReducer"
  
  public typealias DataSource = HTTPDataSourceReducer<[TriviaQuestion]>
  
  @ObservableState
  public struct State {
    var websocket: WebsocketClient.State
    var httpDataSource: DataSource.State
    var triviaItems: IdentifiedArrayOf<TriviaQuestion> = []
    
    public init(
      httpDataSource: DataSource.State = .init(),
      triviaItems: IdentifiedArrayOf<TriviaQuestion> = []
    ) {
      self.websocket = .init(endpoint: Self.websocketEndpoint())
      self.httpDataSource = httpDataSource
      self.triviaItems = triviaItems
    }
    
    static func websocketEndpoint() -> URL {
      return URL(string: "wss://example.com")!
    }
  }
  
  public enum Action {
    case task
    
    // Scoped
    case websocket(WebsocketClient.Action)
    case httpDataSource(DataSource.Action)
  }
  
  var body: some ReducerOf<Self> {
    Scope(state: \.websocket, action: \.websocket) {
      WebsocketClient(errorSourceId: Self.loggingCategory)
    }
    
    Scope(state: \.httpDataSource, action: \.httpDataSource) {
      DataSource(errorSourceId: Self.loggingCategory)
    }
    
    Reduce { state, action in
      <#code#>
    }
  }
}
