protocol CRUDRepository {
  associatedtype Model: Identifiable, Sendable where Model.ID: Sendable
  associatedtype ModelFields: Sendable
  
  func create(_ model: ModelFields) async throws -> Model
  func getAll() async throws -> [Model]
  func get(id: Model.ID) async throws -> Model?
  func update(_ model: Model) async throws -> Model?
  func delete(id: Model.ID) async throws -> Bool
  func deleteAll() async throws
  func dropTable() async throws
}
