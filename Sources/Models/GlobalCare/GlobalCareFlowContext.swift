import Foundation

// 流程共享状态，在各 VC 间传递
struct GlobalCareFlowContext {
    var draft: GlobalCareDraft = GlobalCareDraft()
    var selectedPackage: GlobalCarePackage? = nil
    var aiAssessmentResult: AIAssessmentResult? = nil
}

// AI 预评估结果（Mock）
struct AIAssessmentResult {
    let riskLevel: String
    let recommendedDept: String
    let matchedHospitals: Int
}
