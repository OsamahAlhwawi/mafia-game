import Foundation

enum ConnectionStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
}

enum ServiceEvent: Sendable {
    case status(ConnectionStatus)
    case message(ServerMessage)
}

/// The network boundary. The UI never talks to a socket directly, so the
/// store and view models can be tested against `MockGameService`.
@MainActor
protocol GameService: AnyObject {
    /// Single consumer: `GameStore`.
    var events: AsyncStream<ServiceEvent> { get }
    func connect(profile: Profile, token: String?)
    /// The latest identity to present when the connection drops and comes back.
    func updateIdentity(profile: Profile, token: String?)
    func disconnect()
    func send(_ message: ClientMessage)
}
