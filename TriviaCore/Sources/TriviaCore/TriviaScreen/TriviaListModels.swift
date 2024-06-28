import Foundation
import IdentifiedCollections

public struct WebsocketMessage: Codable, Equatable {
  public let metadata: WebsocketMetadata
  public let content: TriviaAction
}

public struct WebsocketMetadata: Codable, Equatable {
  public let messageId: UUID
  public let prevMessageId: UUID?
}

public enum TriviaAction: Codable, Equatable {
  case newQuestion(TriviaQuestion)
  case newRound(TriviaRound)
}

public struct TriviaRound: Codable, Equatable, Identifiable {
  public let id: UUID
  public let description: String
  public let questions: IdentifiedArrayOf<TriviaQuestion>
}

public struct TriviaQuestion: Codable, Equatable, Identifiable {
  public let id: UUID
  public let type: TriviaQuestionType
}

public enum TriviaQuestionType: Codable, Equatable {
  case text(TriviaTextQuestion)
}

public struct TriviaTextQuestion: Codable, Equatable {
  public let prompt: String
}
