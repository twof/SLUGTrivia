@preconcurrency import PostgresNIO
import Foundation

actor TeamRepository: CRUDRepository {
  let client: PostgresClient
  let logger: Logger
  
  init(client: PostgresClient, logger: Logger) {
    self.client = client
    self.logger = logger
  }
  
  func createTable() async throws {
    try await client.query(
      """
      CREATE TABLE IF NOT EXISTS teams (
        "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "name" TEXT NOT NULL
      );
      """
    )
  }
  
  func create(_ model: TeamFields) async throws -> Team {
    let stream = try await client.query(
      """
      INSERT INTO teams (name)
      VALUES (\(model.name))
      RETURNING id, name;
      """
    )
    
    for try await (id, name) in stream.decode((UUID, String).self, context: .default) {
      return Team(id: id, name: name)
    }
    
    throw RepositoryError.creationFailed
  }
  
  func get(id: UUID) async throws -> Team? {
    let stream = try await client.query(
      """
      SELECT id, name
      FROM teams
      WHERE id = \(id);
      """
    )
    
    for try await (id, name) in stream.decode((UUID, String).self, context: .default) {
      return Team(id: id, name: name)
    }
    
    return nil
  }
  
  func getAll() async throws -> [Team] {
    let stream = try await client.query(
      """
      SELECT id, name
      FROM teams;
      """
    )
    
    return try await stream.collect().map { row in
      let (id, name) = try row.decode((UUID, String).self, context: .default)
      return Team(id: id, name: name)
    }
  }
  
  func update(_ model: Team) async throws -> Team? {
    let stream = try await client.query(
      """
      UPDATE teams
      SET name = \(model.name)
      WHERE id = \(model.id)
      RETURNING id, name;
      """
    )
    
    for try await (id, name) in stream.decode((UUID, String).self, context: .default) {
      return Team(id: id, name: name)
    }
    
    return nil
  }
  
  func delete(id: UUID) async throws -> Bool {
    try await client.withConnection { [logger] connection in
      let result = try await connection.query(
        """
        DELETE FROM teams
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
      DELETE FROM teams;
      """
    )
  }
  
  // TODO: Test this
  func getScore(id: UUID) async throws -> Int? {
    let stream = try await client.query(
      """
      SELECT COUNT(*) 
      FROM answers 
      WHERE team_id = \(id) 
      AND is_correct = TRUE;
      """
    )
    
    for try await (pointCount) in stream.decode((Int).self, context: .default) {
      return pointCount
    }
    
    return nil
  }
}

struct Team: Codable, Equatable, Identifiable {
  let id: UUID
  let name: String
}

struct TeamFields: Codable, Equatable {
  let name: String
}
