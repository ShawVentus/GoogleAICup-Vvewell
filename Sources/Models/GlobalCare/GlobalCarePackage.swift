import Foundation

// 服务套餐数据模型
struct GlobalCarePackage {
    let id: String
    let tier: Tier
    let priceUSD: Int
    let features: [String]
    var isSelected: Bool = false

    enum Tier {
        case basic, standard, premium

        func name(language: AppLanguage) -> String {
            switch self {
            case .basic:    return L10n.string(for: .packageBasic, language: language)
            case .standard: return L10n.string(for: .packageStandard, language: language)
            case .premium:  return L10n.string(for: .packagePremium, language: language)
            }
        }

        var accentColorHex: String {
            switch self {
            case .basic:    return "#4CAF82"
            case .standard: return "#2E9485"
            case .premium:  return "#1A6E63"
            }
        }
    }
}
