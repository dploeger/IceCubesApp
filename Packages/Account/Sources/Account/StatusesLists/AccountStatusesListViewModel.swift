import SwiftUI
import Models
import Status
import Network
import Env

@MainActor
@Observable
public class AccountStatusesListViewModel: StatusesFetcher {
  public enum Mode  {
    case bookmarks, favorites
    
    var title: LocalizedStringKey {
      switch self {
      case .bookmarks:
        "accessibility.tabs.profile.picker.bookmarks"
      case .favorites:
        "accessibility.tabs.profile.picker.favorites"
      }
    }
    
    func endpoint(sinceId: String?) -> Endpoint {
      switch self {
      case .bookmarks:
        Accounts.bookmarks(sinceId: sinceId)
      case .favorites:
        Accounts.favorites(sinceId: sinceId)
      }
    }
  }
  
  let mode: Mode
  public var statusesState: StatusesState = .loading
  var statuses: [Status] = []
  var nextPage: LinkHandler?
  
  var client: Client?
  
  init(mode: Mode) {
    self.mode = mode
  }
  
  public func fetchNewestStatuses(pullToRefresh: Bool) async {
    guard let client else { return }
    statusesState = .loading
    do {
      (statuses, nextPage) = try await client.getWithLink(endpoint: mode.endpoint(sinceId: nil))
      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)
      statusesState = .display(statuses: statuses,
                               nextPageState: nextPage?.maxId != nil ? .hasNextPage : .none)
    } catch {
      statusesState = .error(error: error)
    }
  }
  
  public func fetchNextPage() async {
    guard let client, let nextId = nextPage?.maxId else { return }
    statusesState = .display(statuses: statuses,
                             nextPageState: .loadingNextPage)
    do {
      var newStatuses: [Status] = []
      (newStatuses, nextPage) = try await client.getWithLink(endpoint: mode.endpoint(sinceId: nextId))
      statuses.append(contentsOf: newStatuses)
      StatusDataControllerProvider.shared.updateDataControllers(for: statuses, client: client)
      statusesState = .display(statuses: statuses,
                               nextPageState: nextPage?.maxId != nil ? .hasNextPage : .none)
    } catch { }
  }
  
  public func statusDidAppear(status: Status) {
    
  }
  
  public func statusDidDisappear(status: Status) {
    
  }
}
