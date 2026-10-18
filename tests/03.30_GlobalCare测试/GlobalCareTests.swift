import XCTest
@testable import vvewell_app_ios

// MARK: - 测试参数前置

/// LocaleManager 测试参数
private let kTestLanguageEN: AppLanguage = .en
private let kTestLanguageZH: AppLanguage = .zh
private let kTestLanguageAR: AppLanguage = .ar

/// L10n 测试参数：选取代表性 key
private let kSampleKeys: [L10nKey] = [
    .gcTitle,
    .gcSubtitle,
    .gcStart,
    .assessTitle,
    .packageTitle,
    .confirmTitle,
    .trackingTitle,
]

/// Mock 数据期望值
private let kExpectedPackageCount  = 3
private let kExpectedTrackingCount = 12

// MARK: - LocaleManager 测试

/// 测试 LocaleManager 语言切换、RTL 标志与通知广播
class LocaleManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // 每个用例前重置为英文，避免状态污染
        LocaleManager.shared.setLanguage(.en)
    }

    /// 验证切换语言后 current 属性正确更新
    func testSetLanguageUpdatesCurrent() {
        LocaleManager.shared.setLanguage(kTestLanguageZH)
        XCTAssertEqual(LocaleManager.shared.current, kTestLanguageZH,
                       "切换为中文后 current 应为 .zh")

        LocaleManager.shared.setLanguage(kTestLanguageAR)
        XCTAssertEqual(LocaleManager.shared.current, kTestLanguageAR,
                       "切换为阿拉伯语后 current 应为 .ar")
    }

    /// 验证阿拉伯语时 isRTL 为 true，其余为 false
    func testIsRTLFlag() {
        LocaleManager.shared.setLanguage(kTestLanguageAR)
        XCTAssertTrue(LocaleManager.shared.isRTL, "阿拉伯语应为 RTL")

        LocaleManager.shared.setLanguage(kTestLanguageEN)
        XCTAssertFalse(LocaleManager.shared.isRTL, "英语不应为 RTL")

        LocaleManager.shared.setLanguage(kTestLanguageZH)
        XCTAssertFalse(LocaleManager.shared.isRTL, "中文不应为 RTL")
    }

    /// 验证 setLanguage 后发出 appLanguageDidChange 通知
    func testLanguageChangeNotificationPosted() {
        let expectation = self.expectation(description: "收到语言变更通知")
        let observer = NotificationCenter.default.addObserver(
            forName: .appLanguageDidChange,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        LocaleManager.shared.setLanguage(kTestLanguageZH)
        waitForExpectations(timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}

// MARK: - L10n 三语种完整性测试

/// 测试所有采样 key 在三种语言下均有非空翻译
class L10nTests: XCTestCase {

    /// 验证英文翻译非空
    func testEnglishTranslationsNotEmpty() {
        for key in kSampleKeys {
            let value = L10n.string(for: key, language: .en)
            XCTAssertFalse(value.isEmpty, "英文 key \(key) 翻译不应为空")
        }
    }

    /// 验证中文翻译非空
    func testChineseTranslationsNotEmpty() {
        for key in kSampleKeys {
            let value = L10n.string(for: key, language: .zh)
            XCTAssertFalse(value.isEmpty, "中文 key \(key) 翻译不应为空")
        }
    }

    /// 验证阿拉伯语翻译非空
    func testArabicTranslationsNotEmpty() {
        for key in kSampleKeys {
            let value = L10n.string(for: key, language: .ar)
            XCTAssertFalse(value.isEmpty, "阿拉伯语 key \(key) 翻译不应为空")
        }
    }

    /// 验证三种语言翻译结果互不相同（防止漏填导致回退到同一默认值）
    func testTranslationsDifferAcrossLanguages() {
        for key in kSampleKeys {
            let en = L10n.string(for: key, language: .en)
            let zh = L10n.string(for: key, language: .zh)
            let ar = L10n.string(for: key, language: .ar)
            XCTAssertNotEqual(en, zh, "key \(key) 英文与中文翻译不应相同")
            XCTAssertNotEqual(en, ar, "key \(key) 英文与阿拉伯语翻译不应相同")
        }
    }
}

// MARK: - GlobalCareMock 测试

/// 测试 Mock 工厂返回正确数量与结构的数据
class GlobalCareMockTests: XCTestCase {

    /// 验证 packages() 返回 3 个套餐
    func testPackagesCount() {
        let pkgs = GlobalCareMock.packages()
        XCTAssertEqual(pkgs.count, kExpectedPackageCount,
                       "packages() 应返回 \(kExpectedPackageCount) 个套餐")
    }

    /// 验证每个套餐的 priceUSD 为正数
    func testPackagesPricePositive() {
        for pkg in GlobalCareMock.packages() {
            XCTAssertGreaterThan(pkg.priceUSD, 0,
                                 "套餐 \(pkg.tier) 价格应大于 0")
        }
    }

    /// 验证每个套餐 features 数组非空
    func testPackagesFeaturesNotEmpty() {
        for pkg in GlobalCareMock.packages() {
            XCTAssertFalse(pkg.features.isEmpty,
                           "套餐 \(pkg.tier) features 不应为空")
        }
    }

    /// 验证 trackingNodes() 返回 12 个节点
    func testTrackingNodesCount() {
        let nodes = GlobalCareMock.trackingNodes()
        XCTAssertEqual(nodes.count, kExpectedTrackingCount,
                       "trackingNodes() 应返回 \(kExpectedTrackingCount) 个节点")
    }

    /// 验证追踪节点三个阶段都有覆盖
    func testTrackingNodesCoversAllPhases() {
        let nodes = GlobalCareMock.trackingNodes()
        let phases = Set(nodes.map { $0.phase })
        XCTAssertTrue(phases.contains(.pre),    "应包含 pre 阶段节点")
        XCTAssertTrue(phases.contains(.during), "应包含 during 阶段节点")
        XCTAssertTrue(phases.contains(.post),   "应包含 post 阶段节点")
    }

    /// 验证 sampleOrder() 正确组装订单
    func testSampleOrderAssembly() {
        let ctx = GlobalCareFlowContext()
        let order = GlobalCareMock.sampleOrder(context: ctx)
        XCTAssertFalse(order.orderNo.isEmpty, "订单号不应为空")
        XCTAssertEqual(order.nodes.count, kExpectedTrackingCount,
                       "订单应包含 \(kExpectedTrackingCount) 个追踪节点")
    }
}

// MARK: - GlobalCareFlowContext 测试

/// 测试流程上下文默认值与字段赋值
class GlobalCareFlowContextTests: XCTestCase {

    /// 验证初始状态：selectedPackage 与 aiAssessmentResult 均为 nil
    func testDefaultValuesAreNil() {
        let ctx = GlobalCareFlowContext()
        XCTAssertNil(ctx.selectedPackage,      "默认 selectedPackage 应为 nil")
        XCTAssertNil(ctx.aiAssessmentResult,   "默认 aiAssessmentResult 应为 nil")
    }

    /// 验证 draft 默认字段为空字符串
    func testDraftDefaultsEmpty() {
        let ctx = GlobalCareFlowContext()
        XCTAssertTrue(ctx.draft.applicantName.isEmpty,  "默认 applicantName 应为空")
        XCTAssertTrue(ctx.draft.targetCountry.isEmpty,  "默认 targetCountry 应为空")
        XCTAssertTrue(ctx.draft.chiefComplaint.isEmpty, "默认 chiefComplaint 应为空")
    }

    /// 验证可以正常赋值 selectedPackage
    func testCanAssignSelectedPackage() {
        var ctx = GlobalCareFlowContext()
        let pkg = GlobalCareMock.packages()[0]
        ctx.selectedPackage = pkg
        XCTAssertNotNil(ctx.selectedPackage, "赋值后 selectedPackage 不应为 nil")
        XCTAssertEqual(ctx.selectedPackage?.tier, pkg.tier, "套餐等级应一致")
    }

    /// 验证可以正常赋值 aiAssessmentResult
    func testCanAssignAIAssessmentResult() {
        var ctx = GlobalCareFlowContext()
        let result = GlobalCareMock.assessmentResult()
        ctx.aiAssessmentResult = result
        XCTAssertNotNil(ctx.aiAssessmentResult, "赋值后 aiAssessmentResult 不应为 nil")
    }
}

// MARK: - AIAssessmentResult 结构测试

/// 测试 AI 评估结果数据结构完整性
class AIAssessmentResultTests: XCTestCase {

    /// 验证 Mock 结果的关键字段非空
    func testMockResultFieldsNotEmpty() {
        let result = GlobalCareMock.assessmentResult()
        XCTAssertFalse(result.riskLevel.isEmpty,        "riskLevel 不应为空")
        XCTAssertFalse(result.recommendedDept.isEmpty,  "recommendedDept 不应为空")
    }

    /// 验证匹配医院数量为正整数
    func testMockResultHospitalCountPositive() {
        let result = GlobalCareMock.assessmentResult()
        XCTAssertGreaterThan(result.matchedHospitals, 0, "matchedHospitals 应大于 0")
    }
}
