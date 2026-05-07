import Combine
import ConvexMobile
import Foundation

enum ConvexQueryError: Error {
    case emptyStream
}

extension ConvexClient {
    /// First value from a live subscription (one-shot read).
    func subscribeFirstValue<T: Decodable>(
        to name: String,
        with args: [String: ConvexEncodable?]? = nil,
        as _: T.Type
    ) async throws -> T {
        let stream = subscribe(to: name, with: args, yielding: T.self).values
        var iterator = stream.makeAsyncIterator()
        guard let value = try await iterator.next() else {
            throw ConvexQueryError.emptyStream
        }
        return value
    }
}
