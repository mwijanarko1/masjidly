import ConvexMobile
import Foundation

final class ConvexService: @unchecked Sendable {
    let client: ConvexClient

    init(deploymentURL: String = ConvexConfiguration.deploymentURL) {
        client = ConvexClient(deploymentUrl: deploymentURL)
    }
}
