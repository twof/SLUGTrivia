@preconcurrency import PostgresNIO
import Foundation

actor QuestionRepository: CRUDRepository {
  let client: PostgresClient
  let logger: Logger
  
  init(client: PostgresClient, logger: Logger) {
    self.client = client
    self.logger = logger
  }
  
  func createTable() async throws {
    try await client.query("""
      CREATE TABLE IF NOT EXISTS questions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        round_id UUID NOT NULL,
        "order" INTEGER NOT NULL,
        text TEXT NOT NULL,
        correct_answer TEXT NOT NULL,
        FOREIGN KEY (round_id) REFERENCES rounds(id)
      );
    """)
  }
  
  func create(_ model: QuestionFields) async throws -> Question {
    let stream = try await client.query(
      """
      INSERT INTO questions (round_id, "order", text, correct_answer)
      VALUES (\(model.roundId), \(model.order), \(model.text), \(model.correctAnswer)
      RETURNING id, round_id, "order", text, correct_answer;
      """
    )
    
    for try await (id, roundId, order, text, correctAnswer) in stream.decode((UUID, UUID, Int, String, String).self, context: .default) {
      return Question(id: id, roundId: roundId, order: order, text: text, correctAnswer: correctAnswer)
    }
    
    throw RepositoryError.creationFailed
  }
  
  func get(id: UUID) async throws -> Question? {
    let stream = try await client.query(
      """
      SELECT id, round_id, "order", text, correct_answer
      FROM questions
      WHERE id = \(id);
      """
    )
    
    for try await (id, roundId, order, text, correctAnswer) in stream.decode((UUID, UUID, Int, String, String).self, context: .default) {
      return Question(id: id, roundId: roundId, order: order, text: text, correctAnswer: correctAnswer)
    }
    
    return nil
  }
  
  func getAll() async throws -> [Question] {
    let stream = try await client.query(
      """
      SELECT id, round_id, "order", text, correct_answer
      FROM questions;
      """
    )
    
    return try await stream.collect().map { row in
      let (id, roundId, order, text, correctAnswer) = try row.decode((UUID, UUID, Int, String, String).self, context: .default)
      return Question(id: id, roundId: roundId, order: order, text: text, correctAnswer: correctAnswer)
    }
  }
  
  func update(_ model: Question) async throws -> Question? {
    let stream = try await client.query(
      """
      UPDATE questions
      SET "order" = \(model.order), 
      text = \(model.text), 
      correct_answer = \(model.correctAnswer)
      WHERE id = \(model.id)
      RETURNING id, round_id, "order", text, correct_answer;
      """
    )
    
    for try await (id, roundId, order, text, correctAnswer) in stream.decode((UUID, UUID, Int, String, String).self, context: .default) {
      return Question(id: id, roundId: roundId, order: order, text: text, correctAnswer: correctAnswer)
    }
    
    return nil
  }
  
  func delete(id: UUID) async throws -> Bool {
    try await client.withConnection { [logger] connection in
      let result = try await connection.query(
        """
        DELETE FROM questions
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
      DELETE FROM questions;
      """
    )
  }
}

struct Question: Codable, Identifiable, Equatable {
  let id: UUID
  let roundId: UUID
  let order: Int
  let text: String
  let correctAnswer: String
}

struct QuestionFields: Codable, Equatable {
  let roundId: UUID
  let order: Int
  let text: String
  let correctAnswer: String
}
