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
      CREATE TABLE IF NOT EXISTS answers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        question_id UUID NOT NULL,
        team_id UUID NOT NULL,
        text TEXT NOT NULL,
        FOREIGN KEY (question_id) REFERENCES questions(id),
        FOREIGN KEY (team_id) REFERENCES teams(id)
      );
    """)
  }
  
  func create(_ model: AnswerFields) async throws -> Answer {
    let stream = try await client.query(
      """
      INSERT INTO answers (question_id, team_id, text)
      VALUES (\(model.questionId), \(model.teamId), \(model.text)
      RETURNING id, question_id, team_id, text;
      """
    )
    
    for try await (id, questionId, teamId, text) in stream.decode((UUID, UUID, UUID, String).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text)
    }
    
    throw RepositoryError.creationFailed
  }
  
  func get(id: UUID) async throws -> Answer? {
    let stream = try await client.query(
      """
      SELECT id, question_id, team_id, text
      FROM answers
      WHERE id = \(id);
      """
    )
    
    for try await (id, questionId, teamId, text) in stream.decode((UUID, UUID, UUID, String).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text)
    }
    
    return nil
  }
  
  func getAll() async throws -> [Answer] {
    let stream = try await client.query(
      """
      SELECT id, question_id, team_id, text
      FROM answers;
      """
    )
    
    return try await stream.collect().map { row in
      let (id, questionId, teamId, text) = try row.decode((UUID, UUID, UUID, String).self, context: .default)
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text)
    }
  }
  
  func update(_ model: Answer) async throws -> Answer? {
    let stream = try await client.query(
      """
      UPDATE answers
      SET text = \(model.text)
      WHERE id = \(model.id)
      RETURNING id, question_id, team_id, text;
      """
    )
    
    for try await (id, questionId, teamId, text) in stream.decode((UUID, UUID, UUID, String).self, context: .default) {
      return Answer(id: id, questionId: questionId, teamId: teamId, text: text)
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
    let stream = try await client.query(
      """
      DELETE FROM answers;
      """
    )
  }
}

struct Answer: Codable, Identifiable, Equatable {
  let id: UUID
  let questionId: UUID
  let teamId: UUID
  let text: String
}

struct AnswerFields: Codable, Equatable {
  let questionId: UUID
  let teamId: UUID
  let text: String
}
