import Foundation

/// In-memory stand-in for the server, used by tests and SwiftUI previews.
@MainActor
final class MockGameService: GameService {
    let events: AsyncStream<ServiceEvent>
    private let continuation: AsyncStream<ServiceEvent>.Continuation
    private(set) var sent: [ClientMessage] = []
    private(set) var connectedAs: (profile: Profile, token: String?)?

    init() {
        (events, continuation) = AsyncStream.makeStream()
    }

    func connect(profile: Profile, token: String?) {
        connectedAs = (profile, token)
        sent.append(.hello(token: token, profile: profile))
        continuation.yield(.status(.connected))
    }

    func updateIdentity(profile: Profile, token: String?) {
        connectedAs = (profile, token)
    }

    func disconnect() {
        continuation.yield(.status(.disconnected))
    }

    func send(_ message: ClientMessage) {
        sent.append(message)
    }

    /// Pretends the server sent this.
    func emit(_ message: ServerMessage) {
        continuation.yield(.message(message))
    }

    func emitStatus(_ status: ConnectionStatus) {
        continuation.yield(.status(status))
    }
}
