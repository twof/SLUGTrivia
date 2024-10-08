@preconcurrency import PostgresNIO
import Foundation

actor AnswerRepository: CRUDRepository {
  let client: PostgresClient
  let logger: Logger
  
  init(client: PostgresClient, logger: Logger) {
    self.client = client
    self.logger = logger
  }
  
  func createTable() async throws {
    try await client.query("""
      CREATE TABLE answers (
        "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "question_id" UUID NOT NULL REFERENCES questions,
        "team_id" UUID NOT NULL REFERENCES teams,
        "text" TEXT NOT NULL,
        "is_correct" BOOL NOT NULL DEFAULT FALSE
      );
    """)
  }
  
  func create(_ model: AnswerFields) async throws -> Answer {
    let stream = try await client.query(
      """
      INSERT INTO answers (question_id, team_id, text, is_correct)
      VALUES (\(model.questionId), \(model.teamId), \(model.text), \(model.isCorrect))
      RETURNING id, question_id, team_id, text, is_correct;
      """
    )
    
    for try await (id, questionId, teamId, text, isCorrect) in stream.decode((UUID, UUID, UUID, String, Bool).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text, isCorrect: isCorrect)
    }
    
    throw RepositoryError.creationFailed
  }
  
  func get(id: UUID) async throws -> Answer? {
    let stream = try await client.query(
      """
      SELECT id, question_id, team_id, text, is_correct
      FROM answers
      WHERE id = \(id);
      """
    )
    
    for try await (id, questionId, teamId, text, isCorrect) in stream.decode((UUID, UUID, UUID, String, Bool).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text, isCorrect: isCorrect)
    }
    
    return nil
  }
  
  func getAll() async throws -> [Answer] {
    let stream = try await client.query(
      """
      SELECT id, question_id, team_id, text, is_correct
      FROM answers;
      """
    )
    
    return try await stream.collect().map { row in
      let (id, questionId, teamId, text, isCorrect) = try row.decode((UUID, UUID, UUID, String, Bool).self, context: .default)
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text, isCorrect: isCorrect)
    }
  }
  
  func update(_ model: Answer) async throws -> Answer? {
    let stream = try await client.query(
      """
      UPDATE answers
      SET text = \(model.text),
      is_correct = \(model.isCorrect)
      WHERE id = \(model.id)
      RETURNING id, question_id, team_id, text, is_correct;
      """
    )
    
    for try await (id, questionId, teamId, text, isCorrect) in stream.decode((UUID, UUID, UUID, String, Bool).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text, isCorrect: isCorrect)
    }
    
    return nil
  }
  
  func delete(id: UUID) async throws -> Bool {
    try await client.withConnection { [logger] connection in
      let result = try await connection.query(
        """
        DELETE FROM answers
        WHERE id = \(id);
        """,
        logger: logger
      ).get()
      
      return result.metadata.rows == 1
    }
  }
  
  func deleteAll() async throws {
    try await client.query(
      """
      DELETE FROM answers;
      """
    )
  }
  
  func dropTable() async throws {
    try await client.query(
      """
      DROP TABLE IF EXISTS answers;
      """
    )
  }
}

struct Answer: Codable, Identifiable, Equatable {
  let id: UUID
  let questionId: UUID
  let teamId: UUID
  let text: String
  let isCorrect: Bool
}

struct AnswerFields: Codable, Equatable {
  let questionId: UUID
  let teamId: UUID
  let text: String
  let isCorrect: Bool
}
