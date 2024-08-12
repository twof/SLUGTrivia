import ComposableArchitecture
import Foundation
import URL

public struct RegistrationResponse: Codable, Equatable {}

@Reducer
public struct Registration: LoggingContext {
  public typealias HTTPDataSource = HTTPDataSourceReducer<RegistrationResponse>
  
  public struct State {
    public var teamName: String
    
    // Scoped
    public var dataSource: HTTPDataSource.State
  }
  
  public enum Action {
    public enum Delegate {
      case registration(wasSuccessful: Bool)
    }
    
    case submit
    case updateTeamName(String)
    case delegate(Delegate)
    
    // Scoped
    case dataSource(HTTPDataSource.Action)
  }
  
  public let loggingCategory = "Registration"
  
  public init() {}
  
  public var body: some ReducerOf<Self> {
    Scope(state: \.dataSource, action: \.dataSource) {
      HTTPDataSource(errorSourceId: loggingCategory)
    }
    
    Reduce { state, action in
      switch action {
      case .submit:
        var urlRequest = URLRequest(url: urlFor(teamName: state.teamName))
        urlRequest.httpMethod = "POST"
        return .send(.dataSource(.request(urlRequest: urlRequest)))
        
      case let .updateTeamName(teamName):
        state.teamName = teamName
        
        return .none
        
      case let .dataSource(.delegate(.response(response))):
        return .send(.delegate(.registration(wasSuccessful: true)))
        
      case .dataSource, .delegate:
        return .none
      }
    }
  }
  
  func urlFor(teamName: String) -> URL {
    URL(string: "http://localhost:8080/register/\(teamName)")!
  }
}
