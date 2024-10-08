import Dependencies
import ComposableArchitecture
//import Sentry
import os
import Foundation

public enum LogLevel: Equatable {
    case info(message: String)
    case warning(message: String)
    case error(error: EquatableError)
    
    static func error(_ error: Error) -> Self {
        return LogLevel.error(error: error.toEquatableError())
    }
}

@DependencyClient
public struct LoggingClient: Sendable {
    public var setup: @Sendable () -> Void
    public var log: @Sendable (_ level: LogLevel, _ category: String) -> Void
}

extension LoggingClient: DependencyKey {
    public static let liveValue = LoggingClient {
//        @Dependency(\.remoteLoggingClient) var remoteLoggingClient
//        remoteLoggingClient.setup()
    } log: { level, category in
        let subsystem = Bundle.main.bundleIdentifier!
        let logger = Logger(subsystem: subsystem, category: category)
//        @Dependency(\.remoteLoggingClient) var remoteLoggingClient
        
        switch level {
        case let .info(message):
            logger.info("\(message)")
        case let .warning(message):
            logger.warning("\(message)")
        case let .error(error):
            logger.error("\(error.localizedDescription)")
        }
        
//        remoteLoggingClient.log(level: level, category: category)
    }
    
    // We want to turn off logging during tests most of the time
    public static let testValue = LoggingClient(setup: { }, log: { _, _ in })
}

extension DependencyValues {
    public var loggingClient: LoggingClient {
        get { self[LoggingClient.self] }
        set { self[LoggingClient.self] = newValue }
    }
}

//@DependencyClient
//struct RemoteLoggingClient: Sendable {
//    var setup: @Sendable () -> Void
//    var log: @Sendable (_ level: LogLevel, _ category: String) -> Void
//}
//
//extension RemoteLoggingClient: DependencyKey {
//    static let liveValue = RemoteLoggingClient {
//        SentrySDK.start { options in
//            options.dsn
//            = "https://262de3d8952cf58221fe4c6618834b64@o4506965171896320.ingest.us.sentry.io/4506965173207040"
//            options.enableTracing = true
//            //      options.debug = true
//        }
//    } log: { level, category in
//        switch level {
//        case let .error(error):
//            SentrySDK.capture(error: error.base)
//        case let .info(message):
//            SentrySDK.addBreadcrumb(Breadcrumb(level: .info, category: category))
//        case let .warning(message):
//            SentrySDK.addBreadcrumb(Breadcrumb(level: .warning, category: category))
//        }
//    }
//    
//    // We want to turn off logging during tests most of the time
//    static let testValue = RemoteLoggingClient(setup: { }, log: { _, _ in })
//}
//
//extension DependencyValues {
//    var remoteLoggingClient: RemoteLoggingClient {
//        get { self[RemoteLoggingClient.self] }
//        set { self[RemoteLoggingClient.self] = newValue }
//    }
//}

/// Area of interest for logging purposes
public protocol LoggingContext {
    /// A tag to be used by logs created by this type
    var loggingCategory: String { get }
}

public extension LoggingContext {
    /// Logs at the provided level using the category defined by the protocol conformance
    func log(_ level: LogLevel) {
        @Dependency(\.loggingClient) var loggingClient
        loggingClient.log(level: level, category: loggingCategory)
    }
    
    /// Logs any errors throwin in the closure returning results and rethrowing errors
    func logErrors<RetType>(_ closure: () async throws -> RetType) async throws -> RetType {
        do {
            return try await closure()
        } catch {
            log(.error(error))
            throw error
        }
    }
    
    /// Logs any errors throwin in the closure returning results and rethrowing errors
    func logErrors<RetType>(_ closure: () throws -> RetType) throws -> RetType {
        do {
            return try closure()
        } catch {
            log(.error(error))
            throw error
        }
    }
}

/// Area of interest for logging purposes
protocol StaticLoggingContext {
    /// A tag to be used by logs created by this type
    static var loggingCategory: String { get }
}

extension StaticLoggingContext {
    /// Logs at the provided level using the category defined by the protocol conformance
    static func log(_ level: LogLevel) {
        @Dependency(\.loggingClient) var loggingClient
        loggingClient.log(level: level, category: loggingCategory)
    }
    
    /// Logs any errors throwin in the closure returning results and rethrowing errors
    static func logErrors<RetType>(_ closure: () async throws -> RetType) async throws -> RetType {
        do {
            return try await closure()
        } catch {
            log(.error(error))
            throw error
        }
    }
    
    /// Logs any errors throwin in the closure returning results and rethrowing errors
    static func logErrors<RetType>(_ closure: () throws -> RetType) throws -> RetType {
        do {
            return try closure()
        } catch {
            log(.error(error))
            throw error
        }
    }
}

extension String: @retroactive Error { }
