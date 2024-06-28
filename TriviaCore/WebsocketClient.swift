import ComposableArchitecture
import Foundation

@Reducer
struct WebsocketClient: LoggingContext {
    struct State: Codable, Equatable {
        let endpoint: URL
        var socket: WebsocketClientActor?
        
        enum CodingKeys: CodingKey {
            case endpoint
        }
        
        static func == (lhs: WebsocketClient.State, rhs: WebsocketClient.State) -> Bool {
            lhs.endpoint == rhs.endpoint
        }
    }
    
    enum Action: Equatable {
        case task
        case messageReceived(URLSessionWebSocketTask.Message)
        case sendMessage(URLSessionWebSocketTask.Message)
    }
    
    enum Errors: Error {
        case messageSendFailed(EquatableError)
    }
    
    @Dependency(\.websocket) var websocket
    @Dependency(\.continuousClock) var clock
    
    let loggingCategory: String
    
    init(errorSourceId: String) {
        self.loggingCategory = errorSourceId
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                // Creates a new socket connection and starts listening for messages
                let socket = websocket()
                state.socket = socket
                return .run { [socket, endpoint = state.endpoint] send in
                    await socket.createWebsocketTask(url: endpoint)
                    let stream = await socket.stream()
                    
                    for await message in stream {
                        await send(.messageReceived(message))
                    }
                    
                    print("websocket closed")
                    
                    guard !Task.isCancelled else {
                        return
                    }
                    
                    // Wait for a second and then attempt to reopen the connection
                    try await clock.sleep(for: .seconds(1))
                    if !Task.isCancelled {
                        await send(.task)
                    }
                }
                
            case let .sendMessage(message):
                guard let socket = state.socket else {
                    log(.error("socket not set up before message send"))
                    return .none
                }
                
                return .run { [socket] send in
                    // TODO: On failure, add attempted message to a buffer and send those
                    // messages out on next successful connection. Give up after n attempts
                    try await socket.sendMessage(message)
                } catch: { error, send in
                    log(.error(Errors.messageSendFailed(error.toEquatableError())))
                }
            
            case .messageReceived:
                return .none
            }
        }
    }
}

actor WebsocketClientActor: StaticLoggingContext {
    static var loggingCategory = "LiveWebsocketClient"
    var websocketTask: URLSessionWebSocketTask? = nil
    
    var delegate: WebsocketDelegate?
    
    enum Errors: Error {
        case authFailed
    }
    @Dependency(\.fetchAuthToken) var fetchAuthToken
    
    @available(iOS, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
    var createWebsocketTask: (URL, WebsocketClientActor) async -> Void
    @available(iOS, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
    var sendMessage: (URLSessionWebSocketTask.Message, WebsocketClientActor) async throws -> Void
    @available(iOS, deprecated: 9999, message: "This property has a method equivalent that is preferred for autocomplete via this deprecation. It is perfectly fine to use for overriding and accessing via '@Dependency'.")
    var _stream: (WebsocketClientActor) -> AsyncStream<URLSessionWebSocketTask.Message>
    
    init(
        createWebsocketTask: @escaping (URL, WebsocketClientActor) async -> Void = unimplemented("Websocket.createWebsocketTask"),
        sendMessage: @escaping (URLSessionWebSocketTask.Message, WebsocketClientActor) async throws -> Void = unimplemented("Websocket.sendMessage"),
        stream: @escaping (WebsocketClientActor) -> AsyncStream<URLSessionWebSocketTask.Message> = unimplemented("Websocket.stream")
    ) {
        self.createWebsocketTask = createWebsocketTask
        self.sendMessage = sendMessage
        self._stream = stream
    }
    
    func createWebsocketTask(url: URL) async {
        await self.createWebsocketTask(url, self)
    }
    
    func sendMessage(_ message: URLSessionWebSocketTask.Message) async throws {
        try await self.sendMessage(message, self)
    }
    
    func stream() -> AsyncStream<URLSessionWebSocketTask.Message> {
        self._stream(self)
    }
    
    func setupWebsocket(url: URL) {
        let session = URLSession(configuration: .default)
        guard let authToken = fetchAuthToken() else {
            // TODO: Surface errors to users
            @Dependency(\.loggingClient) var loggingClient
            loggingClient.log(
                level: .error(Errors.authFailed),
                category: Self.loggingCategory
            )
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(authToken)", forHTTPHeaderField: HTTPHeaderField.authorization.rawValue)
        
        self.delegate = WebsocketDelegate(onClose: { [weak self] closureReason in
            guard let self else { return }
            
            print(closureReason.rawValue)
        })
        
        websocketTask = session.webSocketTask(with: request)
        websocketTask?.delegate = self.delegate
        websocketTask?.resume()
    }
}

class WebsocketDelegate: NSObject, URLSessionWebSocketDelegate {
    let onClose: (_ closure: (URLSessionWebSocketTask.CloseCode)) -> Void
    
    init(onClose: @escaping (_ closure: (URLSessionWebSocketTask.CloseCode)) -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onClose(closeCode)
    }
}

extension WebsocketClientActor: DependencyKey {
    static var liveValue: () -> WebsocketClientActor = {
        WebsocketClientActor(
            createWebsocketTask: { url, this in
                this.setupWebsocket(url: url)
            },
            sendMessage: { message, this in
                try await this.websocketTask?.send(message)
            },
            stream: { this in
                AsyncStream<URLSessionWebSocketTask.Message> {
                    guard let websocketTask = this.websocketTask, websocketTask.state == .running else {
                        return nil
                    }
                    
                    do {
                        return try await logErrors {
                            let message = try await websocketTask.receive()
                            return message
                        }
                    } catch {
                        print(error)
                        return nil
                    }
                }
            }
        )
    }
    
    static var testValue: () -> WebsocketClientActor = {
        .init()
    }
}

extension DependencyValues {
    var websocket: () -> WebsocketClientActor {
        get { self[WebsocketClientActor.self] }
        set { self[WebsocketClientActor.self] = newValue }
    }
}

extension URLSessionWebSocketTask.Message: @retroactive Equatable {
    public static func == (lhs: URLSessionWebSocketTask.Message, rhs: URLSessionWebSocketTask.Message) -> Bool {
        switch (lhs, rhs) {
        case (.data(let lhsData), .data(let rhsData)):
            return lhsData == rhsData
        case (.string(let lhsString), .string(let rhsString)):
            return lhsString == rhsString
        default:
            return false
        }
    }
}
