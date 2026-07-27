import Foundation
import Pulse

/// The connection selected when a host turns Pulse's pin affordance into an
/// app-specific action, such as temporarily pausing network access.
public struct ConsoleConnectionPinAction: Sendable {
    public let id: String
    public let domain: String
    public let destination: String
    public let displayName: String

    init(_ task: NetworkTaskEntity) {
        id = task.originalRequest?.headers["Connection-ID"] ?? task.objectID.uriRepresentation().absoluteString
        domain = task.connectionDomain ?? ""
        destination = task.connectionDestination ?? ""
        displayName = task.taskDescription ?? task.url ?? destination
    }
}
