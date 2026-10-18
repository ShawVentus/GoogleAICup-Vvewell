import Foundation

// Mock 数据工厂
enum GlobalCareMock {

    // MARK: - AI 评估结果
    static func assessmentResult() -> AIAssessmentResult {
        return AIAssessmentResult(
            riskLevel: "Medium",
            recommendedDept: "Oncology / Cardiology",
            matchedHospitals: 23
        )
    }

    // MARK: - 服务套餐
    static func packages() -> [GlobalCarePackage] {
        return [
            GlobalCarePackage(
                id: "basic",
                tier: .basic,
                priceUSD: 2800,
                features: [
                    "AI assessment report",
                    "Medical record translation",
                    "Hospital appointment",
                    "Basic travel support"
                ]
            ),
            GlobalCarePackage(
                id: "standard",
                tier: .standard,
                priceUSD: 5800,
                features: [
                    "All Basic features",
                    "Visa application support",
                    "Airport pickup & drop",
                    "Multilingual companion",
                    "Accommodation coordination"
                ]
            ),
            GlobalCarePackage(
                id: "premium",
                tier: .premium,
                priceUSD: 12800,
                features: [
                    "All Standard features",
                    "24/7 dedicated case manager",
                    "Emergency medical escort",
                    "Multi-hospital consultation",
                    "Post-treatment follow-up 6mo"
                ]
            ),
        ]
    }

    // MARK: - 订单追踪节点
    static func trackingNodes() -> [TrackingNode] {
        return [
            // 诊前
            TrackingNode(titleKey: .node_submitted,        subtitle: "Application received",          timestamp: "Mar 28, 09:12", status: .completed,  phase: .pre),
            TrackingNode(titleKey: .node_ai_assessed,      subtitle: "Risk: Medium | Oncology",        timestamp: "Mar 28, 09:15", status: .completed,  phase: .pre),
            TrackingNode(titleKey: .node_record_organized, subtitle: "3 documents processed",          timestamp: "Mar 28, 14:30", status: .inProgress, phase: .pre),
            TrackingNode(titleKey: .node_hospital_booking, subtitle: "Tokyo Medical Center",           timestamp: "",              status: .pending,    phase: .pre),
            TrackingNode(titleKey: .node_visa_support,     subtitle: "Medical visa documents",         timestamp: "",              status: .pending,    phase: .pre),
            TrackingNode(titleKey: .node_transport,        subtitle: "Flight & ground transport",      timestamp: "",              status: .pending,    phase: .pre),
            // 诊中
            TrackingNode(titleKey: .node_pickup,           subtitle: "Airport arrival assistance",    timestamp: "",              status: .pending,    phase: .during),
            TrackingNode(titleKey: .node_treatment,        subtitle: "Oncology dept.",                 timestamp: "",              status: .pending,    phase: .during),
            TrackingNode(titleKey: .node_checkup,          subtitle: "PET-CT & MRI arranged",         timestamp: "",              status: .pending,    phase: .during),
            // 诊后
            TrackingNode(titleKey: .node_recovery,         subtitle: "Personalized rehab plan",       timestamp: "",              status: .pending,    phase: .post),
            TrackingNode(titleKey: .node_followup,         subtitle: "30-day check-in scheduled",     timestamp: "",              status: .pending,    phase: .post),
            TrackingNode(titleKey: .node_archive,          subtitle: "Synced to health profile",      timestamp: "",              status: .pending,    phase: .post),
        ]
    }

    // MARK: - 完整订单
    static func sampleOrder(context: GlobalCareFlowContext) -> GlobalCareOrder {
        let pkg = context.selectedPackage ?? packages()[1]
        return GlobalCareOrder(
            orderNo: "KC-2026-038291",
            draft: context.draft,
            package: pkg,
            nodes: trackingNodes(),
            submittedAt: Date()
        )
    }
}
