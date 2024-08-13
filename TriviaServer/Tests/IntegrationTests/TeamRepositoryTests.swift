import Testing
@testable import Server
import PostgresNIO
import Foundation

struct TeamRepositoryTests {
  @Test
  func scoreZeroNoAnswers() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreZeroNoTeam() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let score = try await teamRepo.getScore(id: UUID())
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreIncorrectAnswersZero() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for question in questions {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: false))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 0)
    }
  }
  
  @Test
  func scoreAllCorrect() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for question in questions {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: true))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == questions.count)
    }
  }
  
  @Test
  func scoreMixedCorrectness() async throws {
    try await repoHarness { teamRepo, answerRepo, questionRepo, roundRepo in
      let round = try await roundRepo.create(RoundFields(title: "Test round", order: 0))
      let team = try await teamRepo.create(TeamFields(name: "Test team"))
      
      let questions = try await (0...3).asyncMap { index in
        let questionFields = QuestionFields(roundId: round.id, order: index, text: "Question \(index)", correctAnswer: "")
        return try await questionRepo.create(questionFields)
      }
      
      for (id, question) in questions.enumerated() {
        _ = try await answerRepo.create(AnswerFields(questionId: question.id, teamId: team.id, text: "", isCorrect: id % 2 == 0))
      }
      
      let score = try await teamRepo.getScore(id: team.id)
      #expect(score == 2)
    }
  }
  
  private func repoHarness(operation: @Sendable @escaping (TeamRepository, AnswerRepository, QuestionRepository, RoundRepository) async throws -> Void) async throws {
    let client = PostgresClient(
      configuration: .init(host: "localhost", username: "postgres", password: "", database: "Trivia", tls: .disable),
      backgroundLogger: Logger(label: "test-client")
    )
    let teamRepo = TeamRepository(client: client, logger: Logger(label: "test-repo"))
    let answerRepo = AnswerRepository(client: client, logger: Logger(label: "test-repo"))
    let questionRepo = QuestionRepository(client: client, logger: Logger(label: "test-repo"))
    let roundRepo = RoundRepository(client: client, logger: Logger(label: "test-repo"))
    
    await withThrowingTaskGroup(of: Void.self) { group in
      group.addTask {
        await client.run()
      }
      
      do {
        try await answerRepo.dropTable()
        try await questionRepo.dropTable()
        try await teamRepo.dropTable()
        try await roundRepo.dropTable()
        
        try await teamRepo.createTable()
        try await roundRepo.createTable()
        try await questionRepo.createTable()
        try await answerRepo.createTable()
        
        try await operation(teamRepo, answerRepo, questionRepo, roundRepo)
        
        try await answerRepo.dropTable()
        try await questionRepo.dropTable()
        try await teamRepo.dropTable()
        try await roundRepo.dropTable()
      } catch {
        Issue.record("Failed to setup database: \(String(reflecting: error))")
        group.cancelAll()
        return
      }
      
      group.cancelAll()
    }
  }
}
