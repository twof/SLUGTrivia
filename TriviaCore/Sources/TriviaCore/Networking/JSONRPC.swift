import Foundation
// Implementation of JSONRPC 2.0 spec
// https://www.jsonrpc.org/specification

public enum IncomingMessageType: Decodable, Equatable {
  case request
  case response
  
  enum CodingKeys: CodingKey {
    case method
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: IncomingMessageType.CodingKeys.self)
    // We can check if an incoming message is a request or response by looking for the method field
    if try container.decodeIfPresent(String.self, forKey: .method) != nil {
      self = .request
    } else {
      self = .response
    }
  }
}
/// Response messages are always in response to a request, and their ID will always match the ID of the request
public struct ResponseMessage<
  Result: Codable & Equatable
>: Codable, Equatable {
  public let jsonrpc: String
  /// The ID will always match the ID of the request
  public let id: UUID
  public let responseType: ResponseType<Result>
  
  public enum CodingKeys: CodingKey {
    case jsonrpc
    case id
    case error
    case result
  }
  
  enum Errors: Error {
    case invalidMessage
  }
  
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ResponseMessage<Result>.CodingKeys.self)
    self.jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
    self.id = try container.decode(UUID.self, forKey: .id)
    if let error = try container.decodeIfPresent(MessageError.self, forKey: .error) {
      self.responseType = .error(error)
    } else if let result = try container.decodeIfPresent(Result.self, forKey: .result) {
      self.responseType = .response(result)
    } else {
      throw Errors.invalidMessage
    }
  }
  
  public func encode(to encoder: any Encoder) throws {
    var container: KeyedEncodingContainer<ResponseMessage<Result>.CodingKeys> = encoder.container(keyedBy: ResponseMessage<Result>.CodingKeys.self)
    try container.encode(jsonrpc, forKey: .jsonrpc)
    try container.encode(id, forKey: .id)
    if case .error(let error) = responseType {
      try container.encode(error, forKey: .error)
    } else if case .response(let result) = responseType {
      try container.encode(result, forKey: .result)
    }
  }
}

public enum ResponseType<Result: Codable & Equatable>: Codable, Equatable {
  case response(Result)
  case error(MessageError)
}

public struct MessageError: Codable, Equatable {
  public let code: ErrorCode
  public let message: String
  public let data: Data?
}

public struct RequestMessage<Params: Codable & Equatable>: Codable, Equatable {
  /// Respones to this request will have a matching ID
  ///
  /// A request without an ID is a notification, and it indicates that no response is expected
  public let id: UUID?
  public let jsonrpc: String
  public let method: String
  public let params: Params?
  
  public init(id: UUID?, method: String, params: Params? = nil) {
    self.id = id
    self.jsonrpc = "2.0"
    self.method = method
    self.params = params
  }
}

public struct EmptyParams: Codable, Equatable {}

/// Parsed error codes for you convenience
public enum ErrorCode: RawRepresentable, Codable, Equatable {
  /// Invalid JSON was received by the server.
  /// An error occurred on the server while parsing the JSON text.
  case parseError
  /// The JSON sent is not a valid Request object.
  case invalidRequest
  /// The method does not exist / is not available.
  case methodNotFound
  /// Invalid method parameter(s).
  case invalidParams
  /// Internal JSON-RPC error.
  case internalError
  /// Reserved for implementation-defined server-errors.
  case serverError(Int)
  /// The remainder of the space is available for application defined errors.
  case other(Int)
  
  public var rawValue: Int {
    switch self {
    case .parseError:
      -32700
    case .invalidRequest:
      -32600
    case .methodNotFound:
      -32601
    case .invalidParams:
      -32602
    case .internalError:
      -32603
    case let .serverError(code):
      code
    case let .other(code):
      code
    }
  }
  
  public init?(rawValue: Int) {
    switch rawValue {
    case -32700:
      self = .parseError
    case -32600:
      self = .invalidRequest
    case -32601:
      self = .methodNotFound
    case -32602:
      self = .invalidParams
    case -32603:
      self = .internalError
    case ((-32000)...(-32099)):
      self = .serverError(rawValue)
    default:
      self = .other(rawValue)
    }
  }
}
