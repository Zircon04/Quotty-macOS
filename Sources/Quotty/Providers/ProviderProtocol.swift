import Foundation

public protocol QuotaProvider: AnyObject, Sendable {
    var family: Family { get }
    func fetch() async throws -> Snapshot
}
