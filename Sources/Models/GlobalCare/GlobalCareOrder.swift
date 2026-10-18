import Foundation

// 时间线节点状态
enum TrackingNodeStatus {
    case completed
    case inProgress
    case pending
}

// 时间线节点
struct TrackingNode {
    let titleKey: L10nKey
    let subtitle: String
    let timestamp: String
    let status: TrackingNodeStatus
    let phase: TrackingPhase
}

enum TrackingPhase {
    case pre, during, post
}

// 订单模型
struct GlobalCareOrder {
    let orderNo: String
    let draft: GlobalCareDraft
    let package: GlobalCarePackage
    let nodes: [TrackingNode]
    let submittedAt: Date
}
