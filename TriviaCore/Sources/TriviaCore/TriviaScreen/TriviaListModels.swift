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
  case newAnswer(TriviaQuestion)
}

public struct TriviaRound: Codable, Equatable, Identifiable {
  public let id: UUID
  public let description: String
  public let questions: IdentifiedArrayOf<TriviaQuestion>
}

public struct TriviaQuestion: Codable, Equatable, Identifiable {
  public let id: UUID
  public let type: TriviaQuestionType
  public let answer: AnswerType?
}

public enum TriviaQuestionType: Codable, Equatable {
  case text(TriviaTextQuestion)
  
  var text: String {
    switch self {
    case let .text(textQuestion): textQuestion.prompt
    }
  }
}

public struct TriviaTextQuestion: Codable, Equatable {
  public let prompt: String
}

public enum AnswerType: Codable, Equatable {
  case text(String)
  
  var text: String {
    switch self {
    case let .text(string): string
    }
  }
}

public struct TriviaStateResponse: Codable, Equatable {
  let mostRecentMessageId: UUID
  let currentRound: TriviaRound
}
