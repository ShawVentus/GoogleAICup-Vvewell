import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppLanguageController extends GetxController {
  final Rx<Locale> currentLocale = const Locale('zh', 'CN').obs;

  bool get isEnglish => currentLocale.value.languageCode == 'en';

  void toggle() => setEnglish(!isEnglish);

  void setEnglish(bool enabled) {
    final locale = enabled
        ? const Locale('en', 'US')
        : const Locale('zh', 'CN');
    Get.locale = locale;
    currentLocale.value = locale;
  }
}

class VvewellTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en_US': {
      '准时睡': 'Sleep on time',
      '轻松走': 'Take a walk',
      '放松': 'Relax',
      '未完成': 'Not completed',
      '点击行动星球，向今日健康分注入能量':
          'Choose an action to contribute to today’s health score',
      '已完成 @count 项行动 · 今日贡献 +@score':
          '@count actions completed · Today’s contribution +@score',
      '王国良': 'Guoliang Wang',
      '当前健康档案 @name，点击切换家庭成员':
          'Current health record: @name. Switch family member.',
      '红外摄像头': 'Thermal camera',
      '首页': 'Home',
      '健康': 'Health',
      '对话': 'Chat',
      '医疗': 'Care',
      '我的': 'Profile',
      '我自己': 'Me',
      '本人': 'Self',
      '男': 'Male',
      '女': 'Female',
      '晚上好': 'Good evening',
      '欢迎回到 vvewell': 'Welcome back to vvewell',
      '快捷入口': 'Quick access',
      '健康档案': 'Health records',
      '设备': 'Devices',
      '手机测量': 'Phone check',
      '营养': 'Nutrition',
      '连接你的健康设备': 'Connect a health device',
      '推荐阅读': 'Recommended reading',
      '系统状态': 'System status',
      '基本健康状况': 'Health overview',
      '生理总览': 'Vitals',
      '睡眠': 'Sleep',
      '运动': 'Activity',
      '女性健康': "Women's health",
      '心血管': 'Cardio',
      '呼吸': 'Breathing',
      '设备中心': 'Device center',
      '统一管理硬件、数据来源与同步状态。': 'Manage hardware, data sources, and sync status.',
      '我的设备': 'My devices',
      '硬件购买': 'Hardware shop',
      '已连接': 'Connected',
      '一键检测': 'One-tap check',
      '开始扫描与连接': 'Scan and connect',
      '已连接设备': 'Connected devices',
      '连接其他设备': 'Connect another device',
      '扫描并添加设备': 'Scan and add device',
      '支持的设备': 'Supported devices',
      '扫描已支持的设备': 'Scan supported devices',
      '健康小助手': 'Health Assistant',
      '立即购买': 'Buy now',
      '家庭与健康': 'Family & health',
      '家庭成员管理': 'Family members',
      '设备管理': 'Device management',
      '订单与权益': 'Orders & benefits',
      '我的订单': 'My orders',
      '我的权益': 'My benefits',
      '设置': 'Settings',
      '通知设置': 'Notification settings',
      '语言': 'Language',
      '隐私与安全': 'Privacy & security',
      '帮助与反馈': 'Help & feedback',
      '关于我们': 'About',
      '退出登录': 'Sign out',
      '隐私与安全入口已准备就绪': 'Privacy and security is ready',
      '帮助与反馈入口已准备就绪': 'Help and feedback is ready',
      '关于我们入口已准备就绪': 'About is ready',
      '退出登录入口已准备就绪': 'Sign out is ready',
      '紧急救援服务入口已准备就绪': 'Emergency assistance is ready',
      '在线客服服务入口已准备就绪': 'Online support is ready',
      'Vvewell 家庭健康管家': 'Vvewell family health companion',
      '版本 1.0.0': 'Version 1.0.0',
      '本人档案': 'My profile',
      '家庭健康成员': 'Family health member',
      '家庭成员': 'Family members',
      '切换健康档案': 'Switch health record',
      '送诊、保险与健康建议将使用所选成员的独立档案。':
          'Care, insurance, and health guidance will use the selected member\'s separate record.',
      '管理家庭成员': 'Manage family members',
      '已添加 @name，并切换至该健康档案': 'Added @name and switched to that health record',
      '全部成员': 'All members',
      '@count 人': '@count people',
      '添加成员': 'Add member',
      '当前查看': 'Viewing now',
      '当前': 'Current',
      '查看健康档案': 'View health record',
      '切换': 'Switch',
      '权限说明': 'Permissions',
      '每位成员拥有独立的健康、送诊、保险和社区档案。成年成员的数据仅在其明确授权范围内共享，授权可随时撤回。':
          'Each member has separate health, care, insurance, and community records. Adult data is shared only within explicit authorization, which can be withdrawn at any time.',
      '添加家庭成员': 'Add family member',
      '成员姓名 *': 'Member name *',
      '请输入成员姓名': 'Enter the member\'s name',
      '与我的关系 *': 'Relationship to me *',
      '配偶': 'Spouse',
      '子女': 'Child',
      '父母': 'Parent',
      '其他被扶养人': 'Other dependent',
      '性别 *': 'Gender *',
      '其他/不便说明': 'Other / prefer not to say',
      '出生年份 *': 'Birth year *',
      '用于年龄相关的服务适配，不会自动用于保险定价。':
          'Used for age-related service matching and never automatically for insurance pricing.',
      '请输入有效的出生年份': 'Enter a valid birth year',
      '我已获得该成员授权，或拥有合法代理权限':
          'I have this member\'s authorization or legal authority to act for them',
      '添加前需要确认授权': 'Confirm authorization before adding',
      '保存并切换': 'Save and switch',
      '@relationship · @gender · @year 年':
          '@relationship · @gender · born @year',
      '健康评分': 'Health score',
      '动态健康标签': 'Dynamic health tags',
      '事实、预测与推断分开显示。预测结果不是诊断。':
          'Facts, predictions, and inferences are shown separately. Predictions are not diagnoses.',
      "家庭保障规划": "Family coverage plan",
      "当前保障 (CNY)": "Current coverage (CNY)",
      "目标 (CNY)": "Target (CNY)",
      "@provider · @price · 保额 @coverage":
          "@provider · @price · coverage @coverage",
      "条款版本 2026.07 · 网络更新于 2026-08-01":
          "Policy wording version 2026.07 · Network updated Aug 1, 2026",
      "@provider · 条款版本 2026.07 · 网络更新于 2026-08-01":
          "@provider · policy wording version 2026.07 · network updated Aug 1, 2026",
      "住院医疗缺口覆盖较高，常用医院网络匹配":
          "Strong coverage for inpatient gaps and a good match for commonly used hospitals",
      "既往症和等待期以正式条款与核保结果为准":
          "Pre-existing conditions and waiting periods are subject to the official policy and underwriting decision",
      "门诊与意外保障均衡，年度预算压力较低":
          "Balanced outpatient and accident coverage with a lower annual budget",
      "部分专科医院为网络外，预计自付区间更宽":
          "Some specialist hospitals are out of network, so estimated out-of-pocket costs may vary more",
      "补充重大疾病一次性给付，降低家庭收入责任缺口":
          "Adds a lump-sum critical illness benefit to help cover family income needs",
      "不替代医疗险；健康告知需由持牌机构正式审核":
          "Does not replace medical insurance. A licensed organization must review health disclosures",
      "¥4,200 / 年": "CNY ¥4,200 / year",
      "¥2,800 / 年": "CNY ¥2,800 / year",
      "¥1,800 / 年": "CNY ¥1,800 / year",
      "¥1,000,000": "CNY ¥1,000,000",
      "¥500,000": "CNY ¥500,000",
      "¥300,000": "CNY ¥300,000",
      "¥100,000": "CNY ¥100,000",
      "¥50,000": "CNY ¥50,000",
      "¥400,000": "CNY ¥400,000",
      "¥200,000": "CNY ¥200,000",
      "¥150,000": "CNY ¥150,000",
      "¥10,000": "CNY ¥10,000",
      "¥5,000": "CNY ¥5,000",
      "¥3,500": "CNY ¥3,500",
      "¥4,800": "CNY ¥4,800",
      "¥12,000": "CNY ¥12,000",
      "¥18,000": "CNY ¥18,000",
      "¥3,200": "CNY ¥3,200",
      "¥8,000": "CNY ¥8,000",
      "¥14,000": "CNY ¥14,000",
      "¥1,800": "CNY ¥1,800",
      "¥0": "CNY ¥0",
      "@count 成员": "@count members",
      "@count 帖子": "@count posts",
      "复核方案：@product": "Plan for review: @product",
      "关闭": "Close",
      '待完善': 'Incomplete',
      '已确认事实': 'Confirmed facts',
      '@count 项': '@count items',
      '风险预测': 'Risk predictions',
      '已确认': 'Confirmed',
      '系统推断': 'System inference',
      '待补充': 'More information needed',
      '来源：@source\n用途：@purpose': 'Source: @source\nUse: @purpose',
      '来源：@source\n用途：@purpose\n置信度：@confidence%':
          'Source: @source\nUse: @purpose\nConfidence: @confidence%',
      '确认信息': 'Confirm information',
      '恢复个性化使用': 'Resume personalization',
      '停止个性化使用': 'Stop personalization',
      '档案尚未完善': 'Record not yet complete',
      '完成基础资料与授权后，健康事实和服务建议会显示在这里。':
          'Health facts and service guidance will appear here after profile details and authorization are complete.',
      '完善基础资料': 'Complete profile',
      '已确认健康事实': 'Confirmed health fact',
      '近 7 天稳定': 'Stable over the past 7 days',
      '智能设备与本人确认': 'Smart device and self-confirmation',
      '健康管理、送诊服务': 'Health management and care services',
      '预测风险': 'Predicted risk',
      '中等风险': 'Moderate risk',
      '多夜睡眠趋势模型 v1.2': 'Multi-night sleep trend model v1.2',
      '健康提醒，不用于诊断或保险定价':
          'Health reminders; not for diagnosis or insurance pricing',
      '照护与送诊': 'Care and referral',
      '建议 30 天内完成': 'Recommended within 30 days',
      '健康档案规则集 2026.07': 'Health-record ruleset 2026.07',
      '送诊与复诊提醒': 'Care and follow-up reminders',
      '保障需求': 'Coverage need',
      '存在 ¥150,000 缺口': '¥150,000 shortfall',
      '保单导入与家庭预算问卷': 'Policy import and household budget questionnaire',
      '保险适当性与保障规划': 'Insurance suitability and coverage planning',
      '身份与人口学': 'Identity and demographics',
      '基础档案': 'Basic profile',
      '家庭管理员录入': 'Entered by family administrator',
      '家庭健康服务适配': 'Family health service matching',
      '今日健康参考分': 'Today\'s wellness score',
      '今日行动改变参考分，持续趋势形成 Aging 方向':
          'Today\'s actions affect the score; long-term trends shape aging pace.',
      '实际年龄': 'Actual age',
      '生理年龄': 'Biological age',
      '衰老速度': 'Aging pace',
      '岁': 'yrs',
      '通知总开关': 'All notifications',
      '健康提醒': 'Health alerts',
      '设备与测量': 'Device & measurement',
      '家庭成员动态': 'Family updates',
      '订单与服务': 'Orders & services',
      '社区互动': 'Community activity',
      '免打扰时段': 'Quiet hours',
      '简体中文': 'Simplified Chinese',
      'English': 'English',
      '应用语言': 'App language',
      '切换到英文': 'Switch to English',
      '切换到中文': 'Switch to Chinese',
      '全部': 'All',
      '待付款': 'To pay',
      '进行中': 'In progress',
      '已完成': 'Completed',
      '会员积分': 'Member points',
      '每日任务': 'Daily tasks',
      '积分记录': 'Points history',
      '通知类型': 'Notification types',
      '控制所有推送、提醒与服务进度通知': 'Control all push, reminder, and service updates',
      '异常趋势、用药和复查提醒': 'Abnormal trends, medication, and follow-up reminders',
      '电量、佩戴、同步和检测结果': 'Battery, wear, sync, and measurement results',
      '共享成员的授权健康动态': 'Authorized health updates from shared members',
      '物流、预约与保险服务进度': 'Delivery, appointments, and insurance updates',
      '回复、关注和社区活动': 'Replies, follows, and community activity',
      '免打扰': 'Do not disturb',
      '22:30 - 07:30 · 紧急健康提醒仍可送达':
          '22:30 - 07:30 · Urgent health alerts remain enabled',
      '设置时间': 'Set schedule',
      '免打扰时间已保存': 'Quiet hours saved',
      'Alloop Ring 健康套装': 'Alloop Ring Health Kit',
      '月光银 · 尺寸 9': 'Moonlight Silver · Size 9',
      '跨境医疗专家会诊': 'International specialist consultation',
      '心血管内科 · 资料复核中': 'Cardiology · Records under review',
      '家庭营养深度评估': 'In-depth family nutrition assessment',
      'Athena 沐瑶 · 已生成报告': 'Athena Muyao · Report generated',
      '红外健康检测仪': 'Infrared Health Sensor',
      'Alloop 智能戒指': 'Alloop Smart Ring',
      '@count 台在线': '@count online',
      'SDK 数据服务已就绪 · 点击查看完整设备页':
          'SDK data service ready · Tap for full device details',
      '将自动检测血氧与心率，采集 PPG/运动波形，并同步戒指历史体温。':
          'Automatically checks blood oxygen and heart rate, captures PPG and motion waveforms, and syncs historical ring temperature.',
      '当前设备保持连接，可继续添加戒指、健康小助手或毫米波雷达。':
          'Keep the current device connected while adding another ring, Health Assistant, or mmWave radar.',
      '一次扫描即可发现 Alloop、AIZORING、健康小助手和 JDY-23。':
          'One scan discovers Alloop, AIZORING, Health Assistant, and JDY-23 devices.',
      '蓝牙扫描已就绪': 'Bluetooth scan ready',
      '血氧验证与历史数据同步': 'Blood-oxygen verification and history sync',
      '心率、血氧、体温、压力与睡眠':
          'Heart rate, blood oxygen, temperature, stress, and sleep',
      '设备控制、Wi-Fi 配网与 MCP 工具': 'Device controls, Wi-Fi setup, and MCP tools',
      'JDY-23 毫米波雷达': 'JDY-23 mmWave radar',
      '点云与生命体征工程数据': 'Point-cloud and engineering vital-sign data',
      '血氧、心率与体温趋势': 'Blood oxygen, heart rate, and temperature trends',
      '语音交互与家庭健康提醒': 'Voice interaction and family health reminders',
      '智能家居': 'Smart home',
      '非接触体温与环境温度检测': 'Contactless body and ambient temperature checks',
      '新品': 'New',
      '毫米波雷达': 'mmWave radar',
      '睡眠、呼吸与离床感知': 'Sleep, breathing, and bed-exit sensing',
      '免佩戴': 'Contactless',
      '购物车': 'Cart',
      '购物车内有 @count 件商品': '@count items in cart',
      '@item 已进入结算流程': '@item is ready for checkout',
      '标准版 · 已签收': 'Standard · Delivered',
      '订单详情已加载': 'Order details loaded',
      '查看详情': 'View details',
      '支付流程已打开': 'Payment opened',
      '服务进度已更新': 'Service status updated',
      '去付款': 'Pay now',
      '查看进度': 'View status',
      '高级会员': 'Premium member',
      '距离下一等级': 'Until next level',
      '620 积分': '620 points',
      '已连续签到 7 天': '7-day check-in streak',
      'AI 健康咨询': 'AI health consultation',
      '24 小时 AI 健康顾问': '24/7 AI health advisor',
      '营养顾问': 'Nutrition advisor',
      '个性化营养建议': 'Personalized nutrition advice',
      '深度报告': 'In-depth reports',
      '每月健康深度分析': 'Monthly in-depth health analysis',
      '优先预约': 'Priority booking',
      '专家问诊优先通道': 'Priority specialist access',
      '生日礼遇': 'Birthday rewards',
      '专属生日福利': 'Exclusive birthday benefit',
      '家庭共享+': 'Family sharing+',
      '升级后支持家人共享': 'Upgrade to share with family',
      '5 / 6 已解锁': '5 / 6 unlocked',
      '每日签到': 'Daily check-in',
      '佩戴戒指': 'Wear your ring',
      '完成健康评估': 'Complete health assessment',
      '查看全部': 'View all',
      '营养评估': 'Nutrition assessment',
      '兑换礼品': 'Redeem gift',
      '评估': 'Assessment',
      'AI 问诊': 'AI consult',
      '追踪': 'Tracking',
      '商城': 'Shop',
      '营养中心': 'Nutrition center',
      '@member · 个性化营养评估与补剂追踪':
          '@member · Personalized nutrition assessment and supplement tracking',
      '购物车，共 @count 件': 'Cart, @count items',
      '购物车暂无商品': 'Your cart is empty',
      '购物车已有 @count 件候选补剂': 'Your cart contains @count candidate supplements',
      '结合当前饮食记录与睡眠风险标签，建议先确认最近 3 天饮食、用药和过敏信息，再判断是否需要补剂。优先通过食物补充；涉及药物相互作用时请让医生或药师复核。':
          'Based on the current food log and sleep-risk tag, first confirm the past three days of diet, medications, and allergies before deciding whether supplements are needed. Prefer food sources, and ask a clinician or pharmacist to review possible medication interactions.',
      '已将@meal记录到饮食摄入：@summary': 'Added @meal to food intake: @summary',
      '今天还有 @count 种补剂未打卡': '@count supplements remain unchecked today',
      '按个人方案记录，不要因漏服自行加倍剂量':
          'Follow your personal plan; never double a dose after missing one',
      '去打卡': 'Check in',
      '营养完成度': 'Nutrition progress',
      '@member 的今日营养概况': '@member\'s nutrition today',
      '尚未记录餐食，完成一次图片识别后可获得更贴合的建议。':
          'No meals recorded yet. Scan one meal image for more relevant guidance.',
      '已记录 @count 餐，共 @calories kcal。':
          '@count meals recorded, @calories kcal total.',
      '记录一餐': 'Record a meal',
      '针对睡眠风险的补剂候选': 'Supplement candidates for sleep risk',
      '根据“睡眠呼吸风险：中等”和近期睡眠不足生成，须结合用药及禁忌复核。':
          'Based on moderate sleep-breathing risk and recent insufficient sleep. Review medications and contraindications first.',
      '结合我最近的睡眠状况，补剂应该怎么排时间？':
          'How should I schedule supplements based on my recent sleep?',
      '我今天的蛋白质和膳食纤维够吗？': 'Did I get enough protein and fiber today?',
      '鱼油和正在使用的药物会冲突吗？': 'Could fish oil interact with my current medications?',
      '如何优先通过食物改善营养，而不是直接买补剂？':
          'How can I improve nutrition through food before buying supplements?',
      '已读取 @member 的基础信息': 'Loaded @member\'s basic profile',
      '睡眠：昨晚 6 小时 30 分钟，睡眠呼吸风险为中等':
          'Sleep: 6 h 30 min last night; moderate sleep-breathing risk',
      '心血管：血压近 7 天稳定，建议 30 天内完成年度复查':
          'Cardiovascular: blood pressure stable for 7 days; annual review recommended within 30 days',
      '饮食：以今天已确认的餐食记录为准，不推断未记录内容':
          'Diet: uses only today\'s confirmed meal records and does not infer missing entries',
      'AI 营养顾问': 'AI nutrition advisor',
      '可先从一个具体问题开始；回答会标明假设和需要人工复核的部分。':
          'Start with one specific question. Answers identify assumptions and items requiring human review.',
      '输入营养或补剂问题': 'Ask about nutrition or supplements',
      '发送问题': 'Send question',
      '今日补剂概览': 'Today\'s supplements',
      '睡眠支持': 'Sleep support',
      '改善睡眠规律，记录入睡与晨起感受':
          'Improve sleep consistency and record bedtime and morning feelings',
      '免疫力支持': 'Immune support',
      '2 / 4 已完成': '2 / 4 completed',
      '疲劳管理': 'Fatigue management',
      '1 / 4 已完成': '1 / 4 completed',
      '全部补剂清单': 'All supplements',
      '仅显示个人已购方案，可逐项记录。':
          'Shows only purchased items in your plan for individual tracking.',
      '今天的已购补剂已全部打卡': 'All purchased supplements checked in today',
      '全部打卡': 'Check all',
      '还没有餐食记录': 'No meal records yet',
      '共 @count 餐 · @calories kcal': '@count meals · @calories kcal',
      '已记录@meal：@summary': 'Recorded @meal: @summary',
      '上传第一餐': 'Upload first meal',
      '继续记录餐食': 'Record another meal',
      '补剂商城': 'Supplement shop',
      '候选商品不等于医疗建议；购买前核对成分、剂量、用药和禁忌。':
          'Candidate products are not medical advice. Check ingredients, dosage, medications, and contraindications before purchase.',
      '维生素': 'Vitamins',
      '镁': 'Magnesium',
      '抗氧化': 'Antioxidants',
      '展示批次、成分与第三方检测信息 · Mock 商品不产生真实订单':
          'Batch, ingredient, and third-party testing details shown · Mock products do not create real orders',
      '@item 已加入候选购物车': '@item added to the candidate cart',
      '加入购物车': 'Add to cart',
      '补剂推荐是健康管理候选，不用于诊断或治疗。孕期、慢病、肝肾功能异常、手术前或正在用药时，应先由医生或药师复核。':
          'Supplement recommendations are health-management candidates, not diagnosis or treatment. During pregnancy, chronic illness, liver or kidney impairment, before surgery, or while taking medication, seek clinician or pharmacist review first.',
      '@calories kcal · 蛋白 @protein g': '@calories kcal · Protein @protein g',
      '记录今天的餐食': 'Record today\'s meal',
      '选择餐次并上传照片。营养识别为可编辑的 Mock 数据，确认后写入饮食摄入。':
          'Choose a meal and upload a photo. Nutrition recognition uses editable Mock data saved to food intake after confirmation.',
      '早餐': 'Breakfast',
      '午餐': 'Lunch',
      '晚餐': 'Dinner',
      '加餐': 'Snack',
      '图片保存失败：@error': 'Could not save image: @error',
      '拍照': 'Take photo',
      '从相册选择': 'Choose from gallery',
      '重新选择': 'Choose again',
      'Mock 营养识别': 'Mock nutrition recognition',
      '可修改识别出的份量，营养合计会同步更新。':
          'Edit recognized portions and nutrient totals will update automatically.',
      '热量': 'Calories',
      '蛋白质': 'Protein',
      '碳水': 'Carbohydrates',
      '脂肪': 'Fat',
      '膳食纤维': 'Dietary fiber',
      '保存中…': 'Saving…',
      '确认并记录到饮食摄入': 'Confirm and add to food intake',
      '本餐蛋白质相对较少，可结合全天摄入补充豆制品、蛋、奶、鱼或瘦肉。该结果仅用于饮食记录。':
          'This meal is relatively low in protein. Balance the day with beans, eggs, dairy, fish, or lean meat. This result is only for food tracking.',
      '蛋白质较充足，膳食纤维偏少，可增加蔬菜、全谷物或适量水果。该结果不是医疗或减重处方。':
          'Protein is adequate but fiber is low. Add vegetables, whole grains, or fruit. This is not a medical or weight-loss prescription.',
      '本餐包含主食、优质蛋白和蔬菜，结构较均衡；仍需结合全天饮食、多样性与个人禁忌综合判断。':
          'This meal includes staple food, quality protein, and vegetables. Consider the full day, variety, and personal restrictions.',
      '维生素 D3': 'Vitamin D3',
      'Omega-3 鱼油': 'Omega-3 fish oil',
      '镁（甘氨酸镁）': 'Magnesium glycinate',
      '维生素 K2': 'Vitamin K2',
      '褪黑素': 'Melatonin',
      '维生素 B6': 'Vitamin B6',
      'L-茶氨酸': 'L-theanine',
      '维生素 C': 'Vitamin C',
      '锌': 'Zinc',
      '辅酶 Q10': 'CoQ10',
      '早餐后': 'After breakfast',
      '午餐后': 'After lunch',
      '晚餐后': 'After dinner',
      '睡前 30 分钟': '30 minutes before bed',
      '睡前': 'Before bed',
      '在日照不足或检测提示不足时辅助维持骨骼与免疫健康':
          'Supports bone and immune health when sunlight or testing indicates deficiency',
      '补充 EPA/DHA；正在使用抗凝药时应先咨询医生':
          'Provides EPA/DHA; consult a doctor first when taking anticoagulants',
      '补充膳食镁；肾功能异常或正在用药时需先咨询医生':
          'Provides dietary magnesium; consult a doctor first for kidney impairment or medication use',
      '与维生素 D 搭配的候选；使用华法林等药物时不应自行补充':
          'A candidate to pair with vitamin D; do not self-supplement while using warfarin or similar medication',
      '短期睡眠节律支持候选，不用于替代睡眠呼吸风险评估':
          'A short-term sleep-rhythm candidate, not a substitute for sleep-breathing risk assessment',
      '参与能量代谢；不建议长期超量使用':
          'Supports energy metabolism; long-term excessive use is not recommended',
      '作为放松支持候选，效果存在个体差异':
          'A relaxation-support candidate with individual variation in effect',
      '饮食不足时的补充候选，不替代蔬果摄入':
          'A candidate when dietary intake is insufficient, not a substitute for fruit and vegetables',
      '明确膳食不足时短期补充，避免长期高剂量':
          'Short-term use for confirmed dietary insufficiency; avoid prolonged high doses',
      '心血管用药人群的候选补充需由医生复核':
          'A clinician should review this candidate for people taking cardiovascular medication',
      '氨基酸': 'Amino acids',
      '矿物质': 'Minerals',
      '热销': 'Popular',
      '助眠': 'Sleep support',
      '特惠': 'Special offer',
      '护心': 'Heart support',
      '未识别食物': 'Unrecognized food',
      '餐食': 'Meal',
      '燕麦粥': 'Oatmeal',
      '水煮蛋': 'Boiled egg',
      '蓝莓': 'Blueberries',
      '烤三文鱼': 'Grilled salmon',
      '红薯': 'Sweet potato',
      '菠菜': 'Spinach',
      '无糖酸奶': 'Unsweetened yogurt',
      '混合坚果': 'Mixed nuts',
      '糙米饭': 'Brown rice',
      '鸡胸肉': 'Chicken breast',
      '西兰花': 'Broccoli',
      '准备开始手机 rPPG 测量': 'Phone rPPG ready',
      '正在打开摄像头测量页': 'Opening camera measurement',
      '当前设备缺少前置摄像头或 rPPG 模型资源':
          'This device lacks a front camera or rPPG model resources',
      '测量失败': 'Measurement failed',
      '已请求取消测量': 'Cancellation requested',
      '测量完成，结果已保存': 'Measurement complete and result saved',
      '测量已取消': 'Measurement cancelled',
      '信号质量不足': 'Insufficient signal quality',
      '测量结束：@reason': 'Measurement ended: @reason',
      '手机 rPPG 测量': 'Phone rPPG measurement',
      '开始测量': 'Start measurement',
      '取消测量': 'Cancel measurement',
      '最终结果': 'Final result',
      '呼吸率': 'Respiratory rate',
      '次/分': 'breaths/min',
      '样本数：@count  来源：@source': 'Samples: @count  Source: @source',
      '报告识别失败': 'Report recognition failed',
      '上传医疗报告': 'Upload medical report',
      '报告将归入 @member 的独立健康档案。OCR 结果必须与原件核对。':
          'The report will be added to @member\'s health record. Verify all OCR results against the original.',
      '报告仅用于本次咨询，不会写入医疗档案。OCR 结果必须与原件核对。':
          'This report is used only for this consultation and will not be saved to medical records. Verify all OCR results against the original.',
      '报告类型': 'Report type',
      '体检报告': 'Physical examination report',
      '检验报告': 'Laboratory report',
      '影像报告': 'Imaging report',
      '出院小结': 'Discharge summary',
      '医疗机构': 'Medical institution',
      '请输入医疗机构': 'Enter a medical institution',
      '报告日期': 'Report date',
      '拍摄报告': 'Take report photo',
      '选择图片': 'Choose image',
      '已载入用于流程演示的脱敏体检报告':
          'A de-identified examination report is loaded for the demo',
      '使用脱敏演示报告': 'Use de-identified demo report',
      '确认报告归属与内容，并同意用于本人的健康档案分析':
          'Confirm the report owner and content, and allow health-record analysis',
      '确认报告内容，并同意用于本次报告咨询':
          'Confirm the report content and allow this consultation',
      '分析结果仅作信息整理，不替代医生诊断。':
          'The analysis organizes information and does not replace a medical diagnosis.',
      '请选择报告并确认授权后提交': 'Select a report and confirm consent before submitting',
      '正在识别报告...': 'Recognizing report...',
      '上传并生成 OCR 分析': 'Upload and generate OCR analysis',
      'Mock OCR：血常规主要指标处于参考范围，维生素 D 指标建议结合原报告复核。':
          'Mock OCR: Key blood-count values are within reference ranges. Verify the vitamin D value against the original report.',
      'Mock OCR：已提取检查部位、检查方法和影像结论，建议由专业医生结合原片解读。':
          'Mock OCR: The body site, method, and imaging conclusion were extracted. A clinician should interpret them with the original images.',
      'Mock OCR：已提取诊断、治疗经过、出院用药与复诊计划，请人工确认药名及剂量。':
          'Mock OCR: Diagnoses, treatment, discharge medications, and follow-up plans were extracted. Manually verify medication names and doses.',
      'Mock OCR：已提取体检项目与异常提示，发现内容需结合原报告和医生意见复核。':
          'Mock OCR: Examination items and abnormal findings were extracted. Verify them against the original report and a clinician\'s assessment.',
      '健康咨询': 'Health consultation',
      '先了解你的当前健康状况': 'Start with your current health',
      '我会区分已确认事实、设备趋势与预测风险，并在需要时建议线下就医。':
          'I will separate confirmed facts, device trends, and predicted risks, and recommend in-person care when needed.',
      '症状判断': 'Symptom check',
      '复查准备': 'Follow-up preparation',
      '血压最近稳定，但为什么仍建议做年度心血管复查？':
          'My blood pressure is stable. Why is an annual cardiovascular review still recommended?',
      '出现哪些胸闷或心悸信号时应该立即就医？':
          'Which chest tightness or palpitation symptoms require immediate care?',
      '帮我总结当前健康档案里最需要关注的三件事':
          'Summarize the three most important items in my health record.',
      '心血管复查前应该准备哪些报告和测量记录？':
          'Which reports and measurements should I prepare for my cardiovascular review?',
      '报告咨询': 'Report consultation',
      '上传报告后继续咨询': 'Upload a report to continue',
      '我会读取 OCR 结构化结果，整理异常指标、参考范围和复诊问题；所有数值仍须与原报告核对。':
          'I will organize abnormal values, reference ranges, and follow-up questions from structured OCR results. Verify every value against the original report.',
      '检验指标': 'Lab values',
      '复诊清单': 'Follow-up checklist',
      '隐私': 'Privacy',
      '体检报告里哪些异常项通常需要优先复核？':
          'Which abnormal findings in this report should usually be reviewed first?',
      '如何区分单次异常和需要持续观察的趋势？':
          'How can I distinguish a one-time abnormal result from a trend that needs monitoring?',
      '根据报告帮我整理一份向医生提问的清单':
          'Create a list of questions to ask my doctor based on this report.',
      '上传医疗报告时哪些个人信息可以先遮挡？':
          'Which personal details can I cover before uploading a medical report?',
      '结合今天的饮食与补剂记录': 'Use today\'s meals and supplement log',
      '优先改善全天饮食结构，再讨论是否需要补剂和人工复核。':
          'Improve the overall daily diet first, then assess supplements and professional review.',
      '饮食摄入': 'Food intake',
      '补剂安全': 'Supplement safety',
      '食物优先': 'Food first',
      '拍照识别': 'Photo recognition',
      '根据今天已记录的餐食，我还缺哪些营养？':
          'Based on today\'s meals, which nutrients am I still missing?',
      '鱼油、镁和维生素 D 应该怎样安排时间？':
          'When should I take fish oil, magnesium, and vitamin D?',
      '有哪些食物可以替代当前候选补剂？':
          'Which foods could replace the suggested supplements?',
      '我想上传午餐图片并估算营养成分': 'I want to upload lunch and estimate its nutrients.',
      '睡眠助手': 'Sleep assistant',
      '先看睡眠时长、趋势与风险标签': 'Start with sleep duration, trends, and risk labels',
      '当前结果只用于健康提醒，不用于诊断；中等睡眠呼吸风险建议专业评估。':
          'These results are health reminders, not a diagnosis. Moderate sleep-breathing risk warrants professional assessment.',
      '睡眠时长': 'Sleep duration',
      '呼吸风险': 'Breathing risk',
      '作息': 'Routine',
      '助眠补剂': 'Sleep supplements',
      '昨晚只睡了 6 小时 30 分钟，今晚怎么调整？':
          'I slept only 6 hours 30 minutes last night. What should I change tonight?',
      '睡眠呼吸风险为中等意味着什么，下一步做什么？':
          'What does moderate sleep-breathing risk mean, and what should I do next?',
      '帮我制定未来七天固定入睡和起床计划':
          'Create a consistent seven-day sleep and wake schedule.',
      '褪黑素和镁是否适合长期使用？':
          'Are melatonin and magnesium suitable for long-term use?',
      '@member 的个性化咨询场景': '@member\'s personalized consultation',
      '血压近 7 天稳定': 'Blood pressure stable for 7 days',
      '睡眠 6小时30分钟': 'Sleep: 6 h 30 min',
      '睡眠呼吸风险：中等': 'Sleep-breathing risk: Moderate',
      '心血管复查：30天内': 'Cardiovascular review: within 30 days',
      '上传报告开始咨询': 'Upload report to start',
      '更换咨询报告': 'Replace consultation report',
      '当前报告：@report': 'Current report: @report',
      '你可以从这些问题开始': 'Try one of these questions',
      '输入 @topic 问题': 'Ask a @topic question',
      '上传或选择医疗报告': 'Upload or choose a medical report',
      '拍摄或选择餐食照片': 'Take or choose a meal photo',
      '请先上传一张真实医疗报告。完成 OCR 后，我才能基于报告内容回答。':
          'Upload a real medical report first. After OCR finishes, I can answer from its contents.',
      '咨询失败': 'Consultation failed',
      '已载入脱敏演示报告。若要进行真实报告咨询，请上传实际报告图片。':
          'A de-identified demo report is loaded. Upload an actual report image for a real consultation.',
      '我会先提取报告类型、日期、医疗机构、异常指标和医生结论，并把无法确认的 OCR 内容标记出来。请不要仅依据识别结果自行停药或调整治疗。':
          'I will extract the report type, date, institution, abnormal values, and clinician conclusions, and mark uncertain OCR content. Do not stop medication or change treatment based only on OCR.',
      '我会结合已确认的餐食摄入、过敏与用药信息判断。当前建议先保证蛋白质、蔬菜和全谷物，再评估补剂；涉及鱼油、维生素 K 或助眠成分时需核对药物相互作用。':
          'I will use confirmed meals, allergies, and medications. Prioritize protein, vegetables, and whole grains before supplements, and check medication interactions for fish oil, vitamin K, or sleep aids.',
      '当前档案显示昨晚睡眠 6 小时 30 分钟，并有中等睡眠呼吸风险标签。建议先记录一周作息、打鼾和日间嗜睡情况；若有夜间憋醒或明显日间嗜睡，应进行专业睡眠评估。':
          'The profile shows 6 hours 30 minutes of sleep and moderate sleep-breathing risk. Track routine, snoring, and daytime sleepiness for a week. Seek a professional sleep assessment for nighttime choking or marked daytime sleepiness.',
      '当前已确认血压近 7 天稳定，同时存在 30 天内完成年度心血管复查的提醒。我会先区分紧急信号、既往事实和趋势数据，再给出下一步建议。':
          'Blood pressure has been stable for 7 days, with an annual cardiovascular review due within 30 days. I will separate urgent signs, established history, and trend data before suggesting next steps.',
      '风险提示': 'Risk alert',
      '健康指数': 'Health index',
      '身体活力': 'Physical vitality',
      '心理状态': 'Mental wellbeing',
      '需要专业关注': 'Professional attention needed',
      '体温信号与平时不同，必要时请人工测量或寻求专业帮助。':
          'The temperature signal differs from your usual pattern. Verify it manually or seek professional help if needed.',
      '人工复测': 'Manual recheck',
      '过一会': 'Later',
      '退下': 'Dismiss',
      '不足': 'Low',
      '平均': 'Average',
      '充足': 'Good',
      '过量': 'Excessive',
      '心率': 'Heart rate',
      '血氧': 'Blood oxygen',
      '压力': 'Stress',
      '精力': 'Energy',
      '中等': 'Moderate',
      '偏低': 'Low',
      '你看小熊猫好像睡眠有点不足，休息个二十分钟吧。':
          'It looks like you may be short on sleep. Consider taking a 20-minute break.',
      '任务已完成。稍后会加载 Mock 复测结果。':
          'Task completed. Mock recheck results will load shortly.',
      '任务完成': 'Task completed',
      '正在加载今日状态': 'Loading today\'s status',
      '暂时无法加载今日状态': 'Unable to load today\'s status',
      '今天还没有可展示的数据': 'No data to show today',
      '数据暂不完整，先展示普通状态':
          'Some data is unavailable; showing the standard status.',
      '状态提示': 'Status update',
      '轻量活动或补水': 'Light activity or hydration',
      '日常建议': 'Daily suggestion',
      '今天状态平稳，可以做一点轻量活动或补充水分。':
          'Your status is stable today. Try some light activity or drink some water.',
      '任务已完成。Mock 复测显示三个状态条有变化，请继续按自己的节奏。':
          'Task completed. The Mock recheck shows changes in three status bars. Continue at a comfortable pace.',
      '保持当前节奏': 'Keep your current pace',
      '状态良好': 'Looking good',
      '今天整体状态不错，保持现在舒适的节奏就好。':
          'Your overall status looks good today. Keep a comfortable pace.',
      '任务已完成。保持适合自己的节奏即可。':
          'Task completed. Continue at a pace that suits you.',
      '休息二十分钟': 'Rest for 20 minutes',
      '需要关注': 'Needs attention',
      '休息任务已完成。Mock 复测已返回，稍后也可以继续关注身体感受。':
          'Rest task completed. The Mock recheck is back; continue monitoring how you feel.',
      '呼吸放松三分钟': 'Three-minute breathing break',
      '现在可能有些紧绷，可以尝试三分钟呼吸放松。':
          'You may be tense. Try a three-minute breathing exercise.',
      '呼吸任务已完成。Mock 复测已返回，不代表生理指标已经改善。':
          'Breathing task completed. The Mock recheck does not prove that physiological values improved.',
      '拉伸活动五分钟': 'Stretch for five minutes',
      '需要活动': 'Time to move',
      '坐得有些久了，可以用五分钟做一组轻柔拉伸。':
          'You have been sitting for a while. Try five minutes of gentle stretching.',
      '拉伸任务已完成。Mock 复测已返回，可以留意接下来的身体感受。':
          'Stretch task completed. The Mock recheck is back; notice how you feel next.',
      '降低强度并休息': 'Reduce intensity and rest',
      '恢复优先': 'Prioritize recovery',
      '今天更适合降低活动强度，给身体留一点恢复时间。':
          'Today is better suited to lower-intensity activity and recovery time.',
      '恢复任务已完成。Mock 复测已返回，完成本身不代表生理状态已恢复。':
          'Recovery task completed. The Mock recheck does not prove physiological recovery.',
      '体温信号与平时不同，建议使用可靠设备进行人工测量。':
          'The temperature signal differs from usual. Verify it with a reliable device.',
      '已记录操作。风险提示会保留，直到 Mock 人工复测结果正常。':
          'Action recorded. The risk alert remains until the Mock manual recheck is normal.',
      '已完成任务': 'Completed task',
      '任务已完成。': 'Task completed.',
      'Mock 人工复测正常': 'Mock manual recheck normal',
      '今日状态暂不可用': 'Today\'s status is unavailable',
      'Alloop、AIZORING、健康小助手、JDY-23 雷达':
          'Alloop, AIZORING, Health Assistant, and JDY-23 radar',
      '昨晚时长': 'Last night',
      '06小时30分钟': '6 h 30 min',
      '今日运动': 'Today\'s activity',
      '步数': 'Steps',
      '千卡': 'kcal',
      '分钟': 'min',
      '生理数据': 'Vitals',
      '最近同步时间: 2026-06-27 16:18': 'Last synced: 2026-06-27 16:18',
      '当前心率': 'Current heart rate',
      '当前血氧饱和度': 'Current blood oxygen',
      '当前体温': 'Current temperature',
      '心率变异性': 'Heart-rate variability',
      '静息心率': 'Resting heart rate',
      '睡眠阶段趋势': 'Sleep-stage trend',
      '睡眠阶段时长': 'Sleep-stage duration',
      '总睡眠时长': 'Total sleep',
      '快速眼动睡眠': 'REM sleep',
      '核心睡眠': 'Core sleep',
      '深睡': 'Deep sleep',
      '6小时20分钟': '6 h 20 min',
      '4小时18分钟': '4 h 18 min',
      '1小时20分钟': '1 h 20 min',
      '47分钟': '47 min',
      '运动记录': 'Activity history',
      '户外步行': 'Outdoor walk',
      '20分钟': '20 min',
      '35分钟': '35 min',
      '45分钟': '45 min',
      '5.2公里': '5.2 km',
      '3.8公里': '3.8 km',
      '4.5公里': '4.5 km',
      '脱敏演示报告已加入本次档案': 'De-identified demo report added to this record',
      '报告识别完成，已加入本次演示档案': 'Report recognized and added to this demo record',
      '医疗报告与饮食摄入': 'Medical reports and food intake',
      '真实图片生成可复核的 OCR 结果，并加入当前家庭成员的本次演示档案。':
          'Generate reviewable OCR results from a real image and add them to the active family member\'s demo record.',
      '医疗报告上传': 'Medical report upload',
      '体检、检验、影像或出院资料': 'Examination, lab, imaging, or discharge records',
      '上传报告': 'Upload report',
      '今日餐食上传': 'Upload today\'s meal',
      '早餐、午餐、晚餐或加餐': 'Breakfast, lunch, dinner, or snack',
      '识别营养': 'Analyze nutrition',
      '暂无医疗报告，上传后会在这里显示识别摘要':
          'No medical reports yet. OCR summaries will appear here after upload.',
      '最近医疗报告': 'Recent medical reports',
      '今日暂无饮食摄入，上传餐食后自动汇总营养成分':
          'No food intake today. Upload a meal to summarize nutrients automatically.',
      '今日饮食摄入': 'Today\'s food intake',
      '健康建议': 'Health suggestions',
      '生活方式': 'Lifestyle',
      '改善睡眠作息': 'Improve sleep routine',
      '保持固定的入睡和起床时间': 'Keep consistent sleep and wake times',
      '增加维生素 D': 'Increase vitamin D',
      '可考虑每日补充 2000 IU': 'Consider 2,000 IU daily',
      '加入力量训练': 'Add strength training',
      '建议每周进行 2–3 次训练': 'Aim for 2–3 sessions per week',
      '当前服务档案': 'Current service profile',
      '查看档案': 'View profile',
      '送诊服务': 'Care referral',
      '保险服务': 'Insurance',
      '康友社区': 'Peer community',
      '紧急帮助': 'Emergency help',
      '在线客服': 'Support',
      '发起送诊': 'Start referral',
      '跨境医疗': 'International care',
      '推荐服务': 'Recommended services',
      '基于当前档案给出方向性建议，临床安全与资质硬门不会因价格或偏好放宽。':
          'Directional suggestions use the current profile. Clinical safety and credential requirements are never relaxed for price or preference.',
      '档案建议': 'Profile suggestion',
      '先完成计划性专科评估': 'Complete a planned specialist assessment first',
      '@member 的健康档案显示年度心血管复查即将到期。建议 30 天内评估；若出现胸痛、严重呼吸困难或意识改变，请立即升级处理。':
          '@member\'s annual cardiovascular review is due soon. Assessment is recommended within 30 days. Escalate immediately for chest pain, severe breathing difficulty, or altered consciousness.',
      'A3 计划就诊': 'A3 planned visit',
      '有效期 30 天': 'Valid for 30 days',
      '可人工复核': 'Human review available',
      '选择一个主服务': 'Choose one primary service',
      '每个服务单只能选择一个主服务。医院与第三方费用始终独立。':
          'Each request can have one primary service. Hospital and third-party charges always remain separate.',
      '专家问诊': 'Specialist consultation',
      '专科医师及全球医学专家意见，适用于复杂病症':
          'Specialist and international medical opinions for complex conditions',
      '全球专家匹配': 'International specialist matching',
      '视频问诊协调': 'Video consultation coordination',
      '多语言支持': 'Multilingual support',
      '第二诊疗意见整理': 'Second-opinion summary',
      '医生或医院另收的挂号诊金、检查费和药品费':
          'Clinician or hospital registration, consultation, test, and medication fees are separate',
      '当前选择': 'Selected service',
      '已选择': 'Selected',
      '选择服务': 'Select service',
      '开始评估': 'Start assessment',
      '专项检查': 'Specialized testing',
      '精密诊断检测与专科医学检查的预约协调':
          'Coordination for advanced diagnostics and specialist examinations',
      'MRI / CT 协调': 'MRI / CT coordination',
      '基因检测协调': 'Genetic testing coordination',
      '专科化验协调': 'Specialist lab coordination',
      '结果归档': 'Results archiving',
      '医院检查费、造影剂、麻醉、耗材和复诊诊金另付医院':
          'Hospital testing, contrast, anesthesia, supplies, and follow-up fees are paid separately',
      '全球转诊': 'International referral',
      '跨境医疗转诊全流程协调与支持':
          'End-to-end coordination and support for international medical referrals',
      '国际医院准入': 'International hospital access',
      '医疗签证材料': 'Medical visa documentation',
      '行程协调': 'Travel coordination',
      '专属个案经理': 'Dedicated case manager',
      '医院诊疗、签证规费、机票、酒店和交通不包含':
          'Hospital care, visa fees, flights, hotels, and transport are not included',
      '我的就诊进度': 'My care progress',
      '完成建档与初筛后，可在这里查看平台、医院直付和资料三类待办。':
          'After intake and initial screening, track platform, hospital payment, and document tasks here.',
      '候选医疗资源': 'Candidate care providers',
      '已根据健康标签预选地点与科室，可修改后重新排序。候选卡展示适配理由、时限、证据和未知项。':
          'Locations and departments are preselected from health tags and can be changed. Cards show fit, timing, evidence, and unknowns.',
      '已根据“血压趋势稳定”和“30 天内心血管复查”自动预选':
          'Preselected from stable blood-pressure trends and a cardiovascular review due within 30 days',
      '北京': 'Beijing',
      '上海': 'Shanghai',
      '新加坡': 'Singapore',
      '美国': 'United States',
      '地点': 'Location',
      '心内科': 'Cardiology',
      '呼吸与睡眠': 'Respiratory and sleep medicine',
      '内分泌科': 'Endocrinology',
      '肿瘤科': 'Oncology',
      '科室': 'Department',
      '最优推荐': 'Top recommendation',
      '标签匹配 @score%': 'Tag match @score%',
      '北京协和医院': 'Peking Union Medical College Hospital',
      '中国医学科学院阜外医院': 'Fuwai Hospital, CAMS',
      '上海交通大学医学院附属瑞金医院': 'Ruijin Hospital, Shanghai Jiao Tong University',
      '复旦大学附属中山医院': 'Zhongshan Hospital, Fudan University',
      '预计 4 天可约': 'Estimated availability: 4 days',
      '预计 6 天可约': 'Estimated availability: 6 days',
      '预计 5 天可约': 'Estimated availability: 5 days',
      '预计 8 天可约': 'Estimated availability: 8 days',
      '预计 9 天可约': 'Estimated availability: 9 days',
      '预计 7 天可约': 'Estimated availability: 7 days',
      '预计 12 天可约': 'Estimated availability: 12 days',
      '预计 15 天可约': 'Estimated availability: 15 days',
      '与年度心血管复查标签高度匹配；支持复杂心血管评估':
          'Strong match for the annual cardiovascular review tag; supports complex cardiovascular assessment',
      '心血管专科能力突出；可承接进一步分层检查与长期随访':
          'Strong cardiovascular specialty capability; supports further stratified testing and long-term follow-up',
      '睡眠呼吸亚专科匹配；可承接睡眠监测与多学科评估':
          'Sleep-breathing subspecialty match; supports sleep studies and multidisciplinary assessment',
      '呼吸睡眠联合门诊；便于从风险筛查进入专业诊断':
          'Combined respiratory-sleep clinic; supports progression from screening to diagnosis',
      '代谢与营养风险联合评估；可结合检验与连续监测':
          'Combined metabolic and nutritional risk assessment using labs and continuous monitoring',
      '糖脂代谢专科能力匹配；支持长期随访计划':
          'Metabolic specialty match with long-term follow-up support',
      '复杂病例多学科讨论；支持病理与影像复核':
          'Multidisciplinary review for complex cases, including pathology and imaging review',
      '诊疗连续性较高；支持第二诊疗意见整理':
          'Strong continuity of care with second-opinion summary support',
      '档案标签匹配 96% · 报告闭环率 94% · 网络状态待核验':
          'Profile tag match 96% · Report follow-through 94% · Network status pending verification',
      '档案标签匹配 88% · 号源更新于 15 分钟前 · 预计自付待评估':
          'Profile tag match 88% · Availability updated 15 minutes ago · Estimated out-of-pocket cost pending',
      '为什么适合：@reason': 'Why it fits: @reason',
      '安全提示：任何候选都不能替代紧急医疗判断。若症状加重或出现危险信号，请立即联系当地急救或前往适当急诊。':
          'Safety notice: No candidate replaces emergency medical judgment. If symptoms worsen or danger signs appear, contact local emergency services or go to an appropriate emergency department immediately.',
      "@member 现有保单、家庭责任及可持续预算概览，可生成保障缺口分析和三项候选方案。":
          "Review @member’s existing policies, family responsibilities, and sustainable budget to identify coverage gaps and three candidate plans.",
      "已按“@priority”更新需求，年度预算 ¥@budget。":
          "Needs updated for “@priority”. Annual budget: CNY ¥@budget.",
      "开始保障规划": "Start coverage planning",
      "调整预算与优先级": "Adjust budget and priorities",
      "保障缺口分析": "Coverage gap analysis",
      "目标、已有保障和缺口按责任类型分开显示，不以单一综合分替代。":
          "Targets, current coverage, and gaps are shown by coverage type instead of a single overall score.",
      "重大疾病": "Critical illness",
      "医疗险": "Medical insurance",
      "意外险": "Accident insurance",
      "高": "High",
      "中": "Medium",
      "低": "Low",
      "已有保障": "Current coverage",
      "目标": "Target",
      "缺口金额：@amount": "Coverage gap: @amount",
      "推荐保障方案": "Recommended coverage plans",
      "仅展示通过资格与适当性初筛的候选；匹配度不会替代具体理由。":
          "Only candidates that pass initial eligibility and suitability screening are shown. Match scores do not replace the reasons for each recommendation.",
      "平安健康险": "Ping An Health Insurance",
      "太平洋健康险": "CPIC Health Insurance",
      "中国人寿": "China Life Insurance",
      "保额": "Coverage",
      "优选": "Recommended",
      "适配：@fit": "Why it fits: @fit",
      "限制：@limit": "Limitations: @limit",
      "查看条款与成本": "View terms and costs",
      "持牌顾问复核": "Licensed advisor review",
      "保单与理赔服务": "Policies and claims",
      "合同事实、材料、预授权、进度与申诉入口集中管理。":
          "Manage policy details, documents, pre-authorization, claim status, and appeals in one place.",
      "医疗险 · 保单有效": "Medical insurance · Policy active",
      "免赔进度 ¥3,500 / ¥10,000 · 等待期已结束":
          "Deductible progress: CNY ¥3,500 / ¥10,000 · Waiting period complete",
      "有效": "Active",
      "暂无理赔草稿": "No claim draft yet",
      "上传材料后可查看完整度、责任人、SLA 和下一步":
          "Upload documents to review completeness, owner, SLA, and next steps",
      "申请金额 ¥@amount · 草稿待核对字段":
          "Claim amount: CNY ¥@amount · Draft fields need review",
      "待创建": "Not started",
      "草稿": "Draft",
      "预授权": "Pre-authorization",
      "新建理赔": "Start a claim",
      "平台结果为需求、条款和成本情景辅助，不是正式报价、承保或赔付承诺。正式费率、除外、反要约和理赔决定以持牌保险机构结果为准，并提供人工复核与申诉。":
          "Platform results support needs assessment and comparison of terms and cost scenarios. They are not quotes, underwriting, or payment promises. Final rates, exclusions, counteroffers, and claim decisions come from licensed insurers, with human review and appeal available.",
      "保障缺口评估适用于": "Coverage gap assessment for",
      "平台提供适当性辅助，正式报价和核保由持牌机构完成。":
          "The platform supports suitability assessment; licensed insurers provide official quotes and underwriting.",
      "优先保障目标": "Coverage priorities",
      "住院与门诊医疗": "Inpatient and outpatient care",
      "家庭收入责任": "Family income protection",
      "全球医疗": "International medical care",
      "年度可持续预算（人民币）*": "Sustainable annual budget (CNY) *",
      "预算用于适当性与支付可持续评估，不等同正式保费。":
          "This budget supports suitability and affordability reviews; it is not a premium quote.",
      "请输入 1,000 至 1,000,000 之间的年度预算":
          "Enter an annual budget from CNY 1,000 to CNY 1,000,000",
      "已有医疗或健康保险": "I already have medical or health insurance",
      "下一步可上传电子保单，逐项确认责任、等待期、除外和网络。":
          "You can upload a digital policy next to review benefits, waiting periods, exclusions, and provider networks.",
      "我确认预算与家庭责任信息真实，并理解可随时修改":
          "I confirm that my budget and family responsibility information is accurate and understand that I can change it at any time.",
      "同意在我确认后，将必要信息交给具名持牌顾问复核":
          "I agree to share the necessary information with a named, licensed advisor after I confirm.",
      "交接前可撤回；社区行为与设备风险预测不会自动进入核保。":
          "You can withdraw consent before handoff. Community activity and device risk predictions are never added to underwriting automatically.",
      "提交前需确认资料和持牌交接授权":
          "Confirm the information and licensed advisor handoff before submitting",
      "生成保障缺口与候选方案": "Analyze coverage gaps and candidate plans",
      "为 @member 评估保障缺口。平台提供适当性辅助，正式报价和核保由持牌机构完成。":
          "Review coverage gaps for @member. The platform supports suitability assessment; licensed insurers provide official quotes and underwriting.",
      "新建理赔草稿": "Create a claim draft",
      "为 @member 整理材料。系统只做预填、完整度检查和状态跟踪，不会自动拒赔。":
          "Prepare documents for @member. The system only pre-fills information, checks completeness, and tracks status; it never automatically denies a claim.",
      "理赔类型 *": "Claim type *",
      "医疗费用理赔": "Medical expense claim",
      "重大疾病理赔": "Critical illness claim",
      "意外医疗理赔": "Accident medical claim",
      "预授权申请": "Pre-authorization request",
      "申请金额 *": "Claim amount *",
      "请输入有效金额": "Enter a valid amount",
      "材料清单": "Document checklist",
      "医疗发票与费用清单": "Medical invoices and itemized charges",
      "上传后保留原图、页码、字段置信度和证据位置。":
          "Uploaded originals, page numbers, field confidence, and evidence locations are retained.",
      "病历、诊断证明或出院小结": "Medical records, diagnosis, or discharge summary",
      "材料完整度预估 86%。提交后仍以保险机构正式要求为准。":
          "Estimated document completeness: 86%. The insurer’s formal requirements still apply after submission.",
      "当前材料不完整。系统会一次性生成最小补件清单，不会重复索取已上传材料。":
          "Documents are incomplete. The system will create one concise list of missing items and will not request files you already uploaded.",
      "我确认资料真实，并同意提交前再次核对抽取字段":
          "I confirm that the information is accurate and agree to review extracted fields before submission.",
      "保存理赔草稿": "Save claim draft",
      "具体适配": "Why this plan fits",
      "90 天": "90 days",
      "30 天": "30 days",
      "年保费 / 保额": "Annual premium / coverage",
      "总成本情景": "Total cost scenarios",
      "免赔与等待期": "Deductible and waiting period",
      "重要限制": "Important limitations",
      "网络与预授权": "Provider network and pre-authorization",
      "常用医院需逐项核验；部分治疗需要事前授权":
          "Check each preferred hospital. Some treatments require pre-authorization.",
      "利益关系": "Conflicts of interest",
      "平台可能与合作机构开展服务合作，不以佣金提升不适当产品":
          "The platform may work with partner organizations. Commissions do not increase the ranking of unsuitable products.",
      "申请具名持牌顾问复核": "Request a review by a named, licensed advisor",
      "预约具名持牌顾问复核": "Schedule a review with a named, licensed advisor",
      "留下联系信息后，平台仅提交回访申请。正式报价、核保结论与销售建议由具名持牌人员提供。":
          "After you provide contact details, the platform only submits a callback request. A named, licensed advisor provides official quotes, underwriting decisions, and sales advice.",
      "联系人姓名*": "Contact name *",
      "请输入联系人姓名": "Enter a contact name",
      "联系电话*": "Phone number *",
      "手机号或可接听的国际号码": "Mobile or reachable international number",
      "请输入 6 至 15 位有效联系电话": "Enter a valid phone number with 6–15 digits",
      "希望如何联系": "Preferred contact method",
      "电话": "Phone",
      "短信": "Text message",
      "微信确认后通话": "Call after WeChat confirmation",
      "方便联系的时间": "Preferred contact time",
      "工作日 09:00-12:00": "Weekdays, 9:00 AM–12:00 PM",
      "工作日 14:00-18:00": "Weekdays, 2:00–6:00 PM",
      "工作日 18:00-20:00": "Weekdays, 6:00–8:00 PM",
      "周末 10:00-18:00": "Weekends, 10:00 AM–6:00 PM",
      "同意将联系信息与本次候选方案交给具名持牌顾问":
          "I agree to share my contact information and this candidate plan with a named, licensed advisor.",
      "不会自动共享社区行为、预测标签或未确认的医疗信息。":
          "Community activity, predicted tags, and unconfirmed medical information are never shared automatically.",
      "提交前需确认最小必要信息授权":
          "Confirm consent to share the minimum necessary information before submitting",
      "提交回访申请": "Submit callback request",
      "安全、私密的经验交流空间。社区不是诊疗场所，不提供个体诊断或处方。":
          "A safe, private space to share experiences. This community does not provide diagnosis or prescriptions.",
      "搜索社区、病种或主题": "Search communities, conditions, or topics",
      "推荐": "Recommended",
      "最新": "Latest",
      "治疗经验": "Treatment experiences",
      "康复随访": "Recovery and follow-up",
      "用药副作用": "Medication side effects",
      "心理生活": "Mental well-being",
      "问答": "Q&A",
      "活动": "Events",
      "社区动态": "Community posts",
      "优先有帮助的回应、内容质量与成员安全。":
          "Prioritizing helpful replies, content quality, and member safety.",
      "发布内容": "Create a post",
      "乳腺癌康友社区": "Breast Cancer Peer Support",
      "围绕治疗经验、康复随访、用药副作用和心理支持的私密交流空间":
          "A private space to discuss treatment experiences, recovery, medication side effects, and emotional support",
      "肿瘤康复": "Cancer recovery",
      "糖尿病管理": "Diabetes Management",
      "分享饮食、运动、用药依从和日常管理经验":
          "Share experiences with nutrition, exercise, medication adherence, and daily care",
      "慢病管理": "Chronic condition management",
      "心脏健康": "Heart Health",
      "心血管疾病预防、复诊和康复支持":
          "Support for cardiovascular prevention, follow-up visits, and recovery",
      "心理与生活": "Mental Well-being",
      "情绪支持、家庭沟通、工作与生活适应":
          "Emotional support, family communication, and adapting to work and daily life",
      "心理支持": "Emotional support",
      "罕见病互助网络": "Rare Disease Peer Network",
      "与相似经历的人交流就医信息、资源和照护经验":
          "Connect with people who have similar experiences to share care information, resources, and caregiving tips",
      "罕见病": "Rare diseases",
      "@count members": "@count members",
      "@count posts": "@count posts",
      "已加入": "Joined",
      "加入": "Join",
      "康复与随访": "Recovery and follow-up",
      "小满 · 认证康友": "Xiaoman · Verified peer",
      "晨光 27": "Morning Light 27",
      "治疗结束后的第一次复查，我把医生要求的资料、检查顺序和当天的准备事项整理成了清单，希望能帮到正在准备的朋友。":
          "For my first follow-up after treatment, I made a checklist of the documents my doctor requested, the order of tests, and what to prepare that day. I hope it helps others getting ready.",
      "更多操作": "More actions",
      "举报内容": "Report post",
      "减少此类内容": "Show fewer posts like this",
      "个人经历，不构成医疗建议": "Personal experience, not medical advice",
      "回复": "Reply",
      "已收藏": "Saved",
      "收藏": "Save",
      "分享站内链接": "Share private link",
      "线上活动 · 复查前的准备与沟通": "Online event · Preparing for a follow-up visit",
      "认证医护": "Verified healthcare professional",
      "8 月 10 日 19:30 · 普通话 · 提供字幕与审核后回放":
          "Aug 10, 7:30 PM · Mandarin · Captions and reviewed replay available",
      "剩余 18 席 · 问题将提前预审 · 报名身份在前台使用别名":
          "18 seats left · Questions reviewed in advance · Alias shown to other attendees",
      "已报名 · 取消报名": "Registered · Cancel registration",
      "报名活动": "Register",
      "成年成员的加入、浏览、发帖和活动记录默认不向家庭管理员展示，也不会进入保险销售、精算、核保、拒保或拒赔。对外分享使用不暴露病种的中性链接。":
          "For adult members, joining, browsing, posting, and event activity are hidden from family administrators by default and are never used for insurance sales, actuarial analysis, underwriting, denials, or claims decisions. Shared links do not reveal a condition.",
      "没有匹配的社区": "No matching communities",
      "试试搜索更宽泛的病种、康复阶段或支持主题。预测风险不会自动把你加入确诊社区。":
          "Try a broader condition, recovery stage, or support topic. Predicted risk will never automatically enroll you in a diagnosis community.",
      "查看全部社区": "View all communities",
      "加入@community": "Join @community",
      "加入后将默认使用匿名别名。成年成员的社区活动不会向家庭管理员展示，也不会用于保险销售、精算、核保或理赔。":
          "After joining, you will use an alias by default. Adult members’ community activity is hidden from family administrators and never used for insurance sales, actuarial analysis, underwriting, or claims decisions.",
      "我已阅读社区规则和隐私说明，并同意加入":
          "I have read the community rules and privacy notice and agree to join",
      "取消": "Cancel",
      "使用匿名别名加入": "Join with an alias",
      "回复帖子": "Reply to post",
      "将使用匿名别名“晨光 27”，回复同样经过隐私与医疗安全检查。":
          "Your reply will use the alias “Morning Light 27” and undergo privacy and medical safety checks.",
      "回复内容": "Reply",
      "请填写回复内容": "Enter a reply",
      "发布回复": "Post reply",
      "举报原因": "Reason for report",
      "医疗错误信息": "Medical misinformation",
      "隐私泄露": "Privacy violation",
      "诈骗或售药": "Scam or drug sales",
      "骚扰与攻击": "Harassment or abuse",
      "其他": "Other",
      "提交举报": "Submit report",
      "社区身份": "Community identity",
      "默认使用匿名别名，真实身份与公开身份分离":
          "An alias is used by default; your real and public identities stay separate",
      "允许内容": "Allowed content",
      "经验、问题、情绪支持、资源和审核后的活动信息":
          "Experiences, questions, emotional support, resources, and reviewed event information",
      "禁止内容": "Prohibited content",
      "个体诊断、处方指令、药品售卖、保险承诺、诈骗和隐私泄露":
          "Individual diagnosis, prescription instructions, drug sales, insurance promises, scams, and privacy violations",
      "安全升级": "Safety escalation",
      "急症、自伤、虐待、诈骗与严重错误信息进入人工安全队列":
          "Emergencies, self-harm, abuse, scams, and serious misinformation are sent to a human safety team",
      "通知隐私": "Notification privacy",
      "锁屏、短信和邮件主题默认不显示具体病种":
          "Condition details are hidden from lock screens and message subjects by default",
      "发布到@community": "Post to @community",
      "默认使用匿名别名“晨光 27”，不会带出真实姓名、手机号或保单身份。":
          "Posts use the alias “Morning Light 27” by default and do not include your real name, phone number, or policy identity.",
      "内容类型 *": "Post type *",
      "经验分享": "Experience",
      "问题求助": "Question",
      "情绪支持": "Emotional support",
      "资源分享": "Resource",
      "活动回顾": "Event recap",
      "内容 *": "Post *",
      "分享经历、提出问题，或给同路人一些支持…":
          "Share an experience, ask a question, or support someone on a similar journey…",
      "请至少填写 10 个字": "Enter at least 10 characters",
      "允许评论与回复": "Allow comments and replies",
      "我已移除身份证、病历号、联系方式、精确地址和第三方隐私":
          "I removed ID numbers, medical record numbers, contact details, precise addresses, and other people’s private information.",
      "我理解个人经历不构成医疗建议，紧急情况应联系急救或专业人员":
          "I understand that personal experiences are not medical advice and emergencies require professional help.",
      "发布前会进行隐私与医疗安全检查。普通内容即时发布，高风险内容可能进入人工审核，并提供原因和申诉入口。":
          "Posts are checked for privacy and medical safety. Standard posts appear immediately; high-risk posts may be reviewed by a person, with an explanation and an appeal option.",
      "提交发布": "Publish post",
      "已退出@community，社区通知同时关闭":
          "Left @community. Community notifications are now off.",
      "已使用匿名别名加入@community": "Joined @community with an alias",
      "请先加入一个社区再发布内容": "Join a community before posting",
      "已复制不包含病种名称的站内邀请链接":
          "Copied a private invite link that does not reveal a condition",
      "内容已通过基础隐私检查并发布":
          "The post passed the basic privacy check and was published",
      "回复已使用匿名别名发布": "Reply posted using an alias",
      "把睡眠趋势读懂：比单晚时长更重要的三个信号":
          "Understand sleep trends: three signals that matter more than one night’s duration",
      "结合近期睡眠与呼吸变化，了解哪些波动值得持续关注。":
          "See which changes may need attention by looking at recent sleep and breathing patterns.",
      "家庭心血管复查前，健康档案应该准备什么":
          "What to prepare in your health record before a family cardiovascular check-up",
      "用一份清单整理设备趋势、既往报告和当前用药。":
          "Use a checklist to organize device trends, prior reports, and current medications.",
      "看懂门诊保障：额度、免赔与网络范围":
          "Understand outpatient coverage: limits, deductibles, and provider networks",
      "从家庭当前保障缺口出发，梳理常见保单字段。":
          "Review common policy terms in light of your family’s current coverage gaps.",
      "血压趋势": "Blood pressure trends",
      "睡眠呼吸风险": "Sleep-breathing risk",
      "年度心血管复查": "Annual cardiovascular check-up",
      "门诊保障": "Outpatient coverage",
      "日常健康": "Everyday health",
      "个性化": "Personalized",
      "阅读文章": "Read article",
      "重试": "Retry",
      "社区行为不会用于保险销售、个体精算、核保、费率、拒保或拒赔。所有跨用途访问都需要单独授权。":
          "Community activity is never used for insurance sales, individual actuarial analysis, underwriting, pricing, denials, or claims decisions. Cross-purpose access always requires separate consent.",
    },
  };
}
