import ComposableArchitecture
import Foundation

/// Ensures that websocket messages do not come in out of order, and that no websocket message is missing
///
/// Requires that websocket messages conform to `WebsocketMessageIdentification`
@Reducer public struct WebsocketContinuityManager {
  public struct State {
    var previousMessageId: UUID?
    var websocket: WebsocketClient.State
  }
  
  public enum Action {
    case websocket(WebsocketClient.Action)
  }
  
  public let errorId: String
  
  public var body: some ReducerOf<Self> {
    Scope(state: \.websocket, action: \.websocket) {
      WebsocketClient(errorSourceId: errorId)
    }
    
    Reduce { state, action in
      <#code#>
    }
  }
}

public struct WebsocketMessageIdentification: Codable, Equatable {
  public let metadata: WebsocketMetadata
}
