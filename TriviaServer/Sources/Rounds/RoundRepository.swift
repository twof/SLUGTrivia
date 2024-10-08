@preconcurrency import PostgresNIO
import Foundation

actor RoundRepository: CRUDRepository {
  let client: PostgresClient
  let logger: Logger
  
  init(client: PostgresClient, logger: Logger) {
    self.client = client
    self.logger = logger
  }
  
  func createTable() async throws {
    try await client.query("""
      CREATE TABLE IF NOT EXISTS rounds (
          "id" uuid PRIMARY KEY DEFAULT gen_random_uuid(),
          "title" text NOT NULL,
          "order" integer NOT NULL
      )
    """)
  }
  
  func create(_ model: RoundFields) async throws -> Round {
    let stream = try await client.query(
      """
      INSERT INTO rounds ("order", title)
      VALUES (\(model.order), \(model.title))
      RETURNING id, "order", title;
      """
    )
    
    for try await (id, order, title) in stream.decode((UUID, Int, String).self, context: .default) {
      return Round(id: id, title: title, order: order)
    }
    
    throw RepositoryError.creationFailed
  }
  
  func get(id: UUID) async throws -> Round? {
    let stream = try await client.query(
      """
      SELECT id, "order", title 
      FROM rounds
      WHERE id = \(id);
      """
    )
    
    for try await (id, order, title) in stream.decode((UUID, Int, String).self, context: .default) {
      return Round(id: id, title: title, order: order)
    }
    
    return nil
  }
  
  func getAll() async throws -> [Round] {
    let stream = try await client.query(
      """
      SELECT id, "order", title 
      FROM rounds;
      """
    )
    
    return try await stream.collect().map { row in
      let (id, order, title) = try row.decode((UUID, Int, String).self, context: .default)
      return Round(id: id, title: title, order: order)
    }
  }
  
  func update(_ model: Round) async throws -> Round? {
    let stream = try await client.query(
      """
      UPDATE rounds
      SET "order" = \(model.order), title = \(model.title)
      WHERE id = \(model.id)
      RETURNING id, "order", title;
      """
    )
    
    for try await (id, order, title) in stream.decode((UUID, Int, String).self, context: .default) {
      return Round(id: id, title: title, order: order)
    }
    
    return nil
  }
  
  func delete(id: UUID) async throws -> Bool {
    try await client.withConnection { [logger] connection in
      let result = try await connection.query(
        """
        DELETE FROM rounds
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
      DELETE FROM rounds;
      """
    )
  }
  
  func dropTable() async throws {
    try await client.query(
      """
      DROP TABLE IF EXISTS rounds;
      """
    )
  }
}

struct Round: Identifiable, Equatable {
  let id: UUID
  let title: String
  let order: Int
}

struct RoundFields: Sendable, Equatable {
  let title: String
  let order: Int
}

enum RepositoryError: Error {
  case creationFailed
}
