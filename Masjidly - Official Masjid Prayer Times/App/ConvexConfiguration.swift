import Foundation

enum ConvexConfiguration {
    static var deploymentURL: String {
        #if DEBUG
        "https://upbeat-goat-583.eu-west-1.convex.cloud"
        #else
        "https://zany-mockingbird-207.eu-west-1.convex.cloud"
        #endif
    }
}
