import ComposableArchitecture
import Foundation

/// Ensures that websocket messages do not come in out of order, and that no websocket message is missing
///
/// Requires that websocket messages conform to `WebsocketMessageIdentification`
@Reducer public struct WebsocketContinuityManager: LoggingContext {
  public typealias HTTPDataSource = HTTPDataSourceReducer<TriviaStateResponse>
  public struct State {
    var previousMessageId: UUID?
    var websocket: WebsocketClient.State
    var httpDataSource: HTTPDataSource.State
  }
  
  public enum Action {
    // Scoped
    case websocket(WebsocketClient.Action)
    case httpDataSource(HTTPDataSource.Action)
    
    case task
    case sendMessage(URLSessionWebSocketTask.Message)
    case messageReceived(URLSessionWebSocketTask.Message)
  }
  
  public var loggingCategory: String
  
  public var body: some ReducerOf<Self> {
    Scope(state: \.websocket, action: \.websocket) {
      WebsocketClient(errorSourceId: loggingCategory)
    }
    Scope(state: \.httpDataSource, action: \.httpDataSource) {
      HTTPDataSource(errorSourceId: loggingCategory)
    }
    
    Reduce { state, action in
      switch action {
      case .task:
        return Effect.send(Action.websocket(.task))
      case let .websocket(.messageReceived(message)):
        guard let data = message.toData else {
          return .none
        }
        guard let messageType = (try? logErrors {
          try JSONDecoder().decode(IncomingMessageType.self, from: data)
        }) else {
          return .none
        }
        switch messageType {
        case .request:
          // Look for metadata and check that the ID is missing, which indicates a notification
          guard
            let metadataMessage = (try? logErrors {
              try JSONDecoder().decode(RequestMessage<WebsocketMessageIdentification>.self, from: data)
            }),
            metadataMessage.id == nil,
            let metadata = metadataMessage.params?.metadata
          else {
            return .none
          }
          
          // Check that the previous ID matches the recorded previous ID, otherwise we've missed
          // a message and need to request current state in order to get ourselves up to speed
          if metadata.prevMessageId != state.previousMessageId {
            return .run { send in
              
            }
          }
          
          return .none
          
        case .response:
          guard let metadata = (try? logErrors {
            try JSONDecoder().decode(ResponseMessage<WebsocketMessageIdentification>.self, from: data)
          }) else {
            return .none
          }
        }
        
        return .send(.messageReceived(message))
        
      case let .httpDataSource(.delegate(.response(response))):
        return .none
      
      case let .sendMessage(message):
        return .send(.websocket(.sendMessage(message)))
        
      case .websocket, .messageReceived, .httpDataSource:
        return .none
      }
    }
  }
  
  /// Sets up the initial client state and reset when the client falls behind
  ///
  /// Makes a request to 
  func syncronize() async throws {
  }
}

public struct WebsocketMessageIdentification: Codable, Equatable {
  public let metadata: WebsocketMetadata
}

extension URLSessionWebSocketTask.Message {
  var toData: Data? {
    switch self {
    case let .data(data):
      return data
    case let .string(string):
      return string.data(using: .utf8)
    @unknown default:
      @Dependency(\.loggingClient) var loggingClient
      
      loggingClient.log(
        level: .warning(message: "Unknown websocket message type"),
        category: "Networking"
      )
      return nil
    }
  }
}
