import ComposableArchitecture
import Foundation

/// Abstract data source which fetches data from a URL.
/// Handles logging and error handling under the hood.
@Reducer
public struct HTTPDataSourceReducer<ResponseType: Codable & Equatable>: ErrorProducer, Sendable {
  public struct State: Codable, Equatable, Sendable { public init() { } }
  
  public enum Action: Equatable {
    public enum Delegate: Equatable {
      case response(ResponseType)
      case error(EquatableError, sourceId: String, errorId: UUID)
      case clearError(sourceId: String, errorId: UUID)
    }
    case fetch(
      url: String,
      cachePolicy: NSURLRequest.CachePolicy = .useProtocolCachePolicy,
      retry: Int = 0,
      requestId: UUID? = nil,
      decoder: JSONDecoder = .init()
    )
    case request(
      urlRequest: URLRequest,
      retry: Int = 0,
      requestId: UUID? = nil,
      decoder: JSONDecoder = .init()
    )
    case delegate(Delegate)
  }
  
  public enum RequestError: Error {
    /// Hit max retries, not retrying any more
    case maxRetries
  }
  
  var errorSourceId: String
  let maxRetries: Int
  let sessionConfig: SessionConfig
  
  public init(errorSourceId: String, maxRetries: Int = 5, sessionConfig: SessionConfig = .cached) {
    self.errorSourceId = errorSourceId
    self.maxRetries = maxRetries
    self.sessionConfig = sessionConfig
  }
  
  @Dependency(DataRequestClient<ResponseType>.self) var fetchDataClient
  @Dependency(\.continuousClock) var clock
  @Dependency(\.uuid) var uuid
  
  public var body: some ReducerOf<Self> {
    Reduce { _, action in
      switch action {
      case let .fetch(urlString, cachePolicy, retry, requestId, jsonDecoder):
        return .run { send in
          try await request(
            send: send,
            urlString: urlString,
            cachePolicy: cachePolicy,
            retry: retry,
            requestId: requestId,
            jsonDecoder: jsonDecoder
          )
        } catch: { error, send in
          await runRetries(
            send: send,
            error: error,
            requestId: requestId,
            retry: retry,
            urlString: urlString,
            cachePolicy: cachePolicy,
            jsonDecoder: jsonDecoder
          )
        }
      case let .request(urlRequest, retry, requestId, jsonDecoder):
        return .run { send in
          try await request(send: send, urlRequest: urlRequest, retry: retry, requestId: requestId, jsonDecoder: jsonDecoder)
        } catch: { error, send in
          await runRetries(
            send: send,
            error: error,
            requestId: requestId,
            retry: retry,
            urlRequest: urlRequest,
            jsonDecoder: jsonDecoder
          )
        }
      case .delegate:
        // This action acts as a delegate. The data source doesn't do anything with the data itself.
        return .none
      }
    }
  }
  
  func request(
    send: Send<Action>,
    urlString: String,
    cachePolicy: NSURLRequest.CachePolicy,
    retry: Int,
    requestId: UUID?,
    jsonDecoder: JSONDecoder
  ) async throws {
    // Use an ephemeral URLSession instead of the shared instance if that's what the
    // caller selected. The ephemeral instance removes the built in URLCache. Useful if
    // another caching mechanism is being used or low memory usage is a priority.
    let response = try await withDependencies { dependencies in
      dependencies.networkRequest = switch sessionConfig {
      case .ephemeral:
        Dependency(\.ephemeralNetworkRequest).wrappedValue
      case .cached:
        Dependency(\.networkRequest).wrappedValue
      }
    } operation: {
      try await fetchDataClient.request(
        urlString: urlString,
        cachePolicy: cachePolicy,
        jsonDecoder: jsonDecoder
      )
    }
    
    // Got a successful response, clear any existing errors for this request
    if let requestId = requestId {
      await send(.delegate(.clearError(sourceId: errorSourceId, errorId: requestId)))
    }
    
    await send(.delegate(.response(response)))
  }
  
  func request(
    send: Send<Action>,
    urlRequest: URLRequest,
    retry: Int,
    requestId: UUID?,
    jsonDecoder: JSONDecoder
  ) async throws {
    // Use an ephemeral URLSession instead of the shared instance if that's what the
    // caller selected. The ephemeral instance removes the built in URLCache. Useful if
    // another caching mechanism is being used or low memory usage is a priority.
    let response = try await withDependencies { dependencies in
      dependencies.networkRequest = switch sessionConfig {
      case .ephemeral:
        Dependency(\.ephemeralNetworkRequest).wrappedValue
      case .cached:
        Dependency(\.networkRequest).wrappedValue
      }
    } operation: {
      try await fetchDataClient.urlRequest(
        urlRequest: urlRequest,
        jsonDecoder: jsonDecoder
      )
    }
    
    // Got a successful response, clear any existing errors for this request
    if let requestId = requestId {
      await send(.delegate(.clearError(sourceId: errorSourceId, errorId: requestId)))
    }
    
    await send(.delegate(.response(response)))
  }
  
  func runRetries(
    send: Send<Action>,
    error: Error,
    requestId: UUID?,
    retry: Int,
    urlString: String,
    cachePolicy: NSURLRequest.CachePolicy,
    jsonDecoder: JSONDecoder
  ) async {
    let requestId = requestId ?? uuid()
    
    // Begin doing exponential backoff
    if retry < maxRetries {
      await send(
        .delegate(.error(
          error.toEquatableError(),
          sourceId: self.errorSourceId,
          errorId: requestId
        ))
      )
      do {
        try await clock.sleep(for: .milliseconds(Self.backoffDuration(retry: retry)))
        await send(
          .fetch(
            url: urlString,
            cachePolicy: cachePolicy,
            retry: retry + 1,
            requestId: requestId,
            decoder: jsonDecoder
          )
        )
      } catch {
        // This is only expected to throw on cancelation which is an error we don't
        // have to deal with
        //              await send(.delegate(.clearError(sourceId: self.errorSourceId, errorId: requestId)))
        
        return
      }
    } else {
      await send(.delegate(.error(
        RequestError.maxRetries.toEquatableError(),
        sourceId: self.errorSourceId,
        errorId: requestId
      )))
    }
  }
  
  func runRetries(
    send: Send<Action>,
    error: Error,
    requestId: UUID?,
    retry: Int,
    urlRequest: URLRequest,
    jsonDecoder: JSONDecoder
  ) async {
    let requestId = requestId ?? uuid()
    
    // Begin doing exponential backoff
    if retry < maxRetries {
      await send(
        .delegate(.error(
          error.toEquatableError(),
          sourceId: self.errorSourceId,
          errorId: requestId
        ))
      )
      do {
        try await clock.sleep(for: .milliseconds(Self.backoffDuration(retry: retry)))
        await send(
          .request(
            urlRequest: urlRequest,
            retry: retry + 1,
            requestId: requestId,
            decoder: jsonDecoder
          )
        )
      } catch {
        // This is only expected to throw on cancelation which is an error we don't
        // have to deal with
        //              await send(.delegate(.clearError(sourceId: self.errorSourceId, errorId: requestId)))
        
        return
      }
    } else {
      await send(.delegate(.error(
        RequestError.maxRetries.toEquatableError(),
        sourceId: self.errorSourceId,
        errorId: requestId
      )))
    }
  }
  
  static func backoffDuration(retry: Int) -> Int {
    let exponent = NSDecimalNumber(value: pow(2, Double(retry))).intValue
    let waitMilliseconds: Int = 100 + exponent
    return waitMilliseconds
  }
}

struct DataRequestClient<ResponseType: Codable & Equatable>: Sendable {
  var request: @Sendable (
    _ urlString: String,
    _ cachePolicy: NSURLRequest.CachePolicy,
    _ jsonDecoder: JSONDecoder
  ) async throws -> ResponseType
  
  var urlRequest: @Sendable (
    _ urlRequest: URLRequest,
    _ jsonDecoder: JSONDecoder
  ) async throws -> ResponseType
  
  init(
    request: @escaping @Sendable (_: String, _: NSURLRequest.CachePolicy, _: JSONDecoder) async throws -> ResponseType = unimplemented(),
    urlRequest: @escaping @Sendable (_: URLRequest, _: JSONDecoder) async throws -> ResponseType = unimplemented()
  ) {
    self.request = request
    self.urlRequest = urlRequest
  }
  
  func urlRequest(
    urlRequest: URLRequest,
    jsonDecoder: JSONDecoder
  ) async throws -> ResponseType {
    try await self.urlRequest(urlRequest, jsonDecoder)
  }
  
  func request(
    urlString: String,
    cachePolicy: NSURLRequest.CachePolicy,
    jsonDecoder: JSONDecoder
  ) async throws -> ResponseType {
    try await self.request(urlString, cachePolicy, jsonDecoder)
  }
}

// General networking client
extension DataRequestClient: DependencyKey {
  static var liveValue: DataRequestClient<ResponseType> {
    DataRequestClient { urlString, cachePolicy, jsonDecoder in
      @Dependency(\.loggingClient) var loggingClient
      guard let url = URL(string: urlString) else {
        let error = NetworkRequestError.malformedURLError(urlString: urlString)
        loggingClient.log(level: .error(error), category: "Networking")
        throw error
      }
      
      @Dependency(Repository<ResponseType>.self) var repository
      var urlRequest = URLRequest(url: url)
      urlRequest.cachePolicy = cachePolicy
      
      return try await repository(urlRequest, jsonDecoder)
    } urlRequest: { urlRequest, jsonDecoder in
      @Dependency(Repository<ResponseType>.self) var repository
      
      return try await repository(urlRequest, jsonDecoder)
    }
  }
  
  static var testValue: DataRequestClient<ResponseType> {
    // All properties unimplemented. Will autofail if used in tests.
    DataRequestClient()
  }
}

extension JSONDecoder: @retroactive Equatable {
  public static func == (lhs: JSONDecoder, rhs: JSONDecoder) -> Bool {
    return true
  }
}
