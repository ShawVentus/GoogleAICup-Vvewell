import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../foundations/ui/vvewell_theme.dart';

class ReferralIntakeResult {
  const ReferralIntakeResult({
    required this.complaint,
    required this.urgency,
    required this.channel,
    required this.hasRecords,
  });

  final String complaint;
  final String urgency;
  final String channel;
  final bool hasRecords;
}

class InsuranceNeedsResult {
  const InsuranceNeedsResult({
    required this.annualBudget,
    required this.priority,
    required this.hasExistingPolicy,
  });

  final int annualBudget;
  final String priority;
  final bool hasExistingPolicy;
}

class ClaimDraftResult {
  const ClaimDraftResult({required this.type, required this.amount});

  final String type;
  final int amount;
}

class CommunityPostDraft {
  const CommunityPostDraft({required this.type, required this.content});

  final String type;
  final String content;
}

class AdvisorContactResult {
  const AdvisorContactResult({
    required this.name,
    required this.phone,
    required this.contactChannel,
    required this.preferredTime,
    required this.productName,
  });

  final String name;
  final String phone;
  final String contactChannel;
  final String preferredTime;
  final String productName;
}

Future<ReferralIntakeResult?> showReferralIntakeSheet(
  BuildContext context, {
  required String memberName,
  String initialChannel = "In-person visit",
}) {
  return showModalBottomSheet<ReferralIntakeResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReferralIntakeSheet(
      memberName: memberName,
      initialChannel: initialChannel,
    ),
  );
}

Future<bool?> showQuoteConfirmationSheet(
  BuildContext context, {
  required String serviceName,
  required String serviceFee,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _QuoteConfirmationSheet(
      serviceName: serviceName,
      serviceFee: serviceFee,
    ),
  );
}

Future<InsuranceNeedsResult?> showInsuranceNeedsSheet(
  BuildContext context, {
  required String memberName,
}) {
  return showModalBottomSheet<InsuranceNeedsResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _InsuranceNeedsSheet(memberName: memberName),
  );
}

Future<ClaimDraftResult?> showClaimDraftSheet(
  BuildContext context, {
  required String memberName,
  String initialType = '医疗费用理赔',
}) {
  return showModalBottomSheet<ClaimDraftResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _ClaimDraftSheet(memberName: memberName, initialType: initialType),
  );
}

Future<CommunityPostDraft?> showCommunityPostSheet(
  BuildContext context, {
  required String communityName,
}) {
  return showModalBottomSheet<CommunityPostDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CommunityPostSheet(communityName: communityName),
  );
}

Future<AdvisorContactResult?> showAdvisorContactSheet(
  BuildContext context, {
  required String memberName,
  required String productName,
}) {
  return showModalBottomSheet<AdvisorContactResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        _AdvisorContactSheet(memberName: memberName, productName: productName),
  );
}

class _ReferralIntakeSheet extends StatefulWidget {
  const _ReferralIntakeSheet({
    required this.memberName,
    required this.initialChannel,
  });

  final String memberName;
  final String initialChannel;

  @override
  State<_ReferralIntakeSheet> createState() => _ReferralIntakeSheetState();
}

class _ReferralIntakeSheetState extends State<_ReferralIntakeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _complaintController = TextEditingController();
  final _diagnosisController = TextEditingController();
  String _urgency = 'A3 计划就诊';
  late String _channel = widget.initialChannel;
  bool _hasRecords = false;
  bool _identityConfirmed = false;
  bool _consent = false;

  @override
  void dispose() {
    _complaintController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        !_identityConfirmed ||
        !_consent) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      ReferralIntakeResult(
        complaint: _complaintController.text.trim(),
        urgency: _urgency,
        channel: _channel,
        hasRecords: _hasRecords,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: "Start referral assessment",
      subtitle: 'Create a separate case for ${widget.memberName}. Rule out emergencies first, then describe the care needed.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SafetyCallout(),
            const SizedBox(height: 20),
            const _FormSectionTitle("Symptoms and care needs"),
            const SizedBox(height: 10),
            TextFormField(
              key: const Key('referral-complaint'),
              controller: _complaintController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Main symptoms or care needs *",
                hintText: "For example: recurring chest tightness for two weeks; seeking a cardiology assessment",
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().length < 6
                  ? "Enter at least 6 characters to explain your care needs"
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diagnosisController,
              decoration: const InputDecoration(
                labelText: "Existing diagnosis or treatment (optional)",
                helperText: "Leave blank if unsure. Unknown information is not treated as a negative answer.",
              ),
            ),
            const SizedBox(height: 20),
            const _FormSectionTitle("Preferred timeframe"),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ["A1 Same-day assessment", "A2 Within 24–72 hours", 'A3 计划就诊', "A4 Routine consultation"]
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value),
                      selected: _urgency == value,
                      onSelected: (_) => setState(() => _urgency = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _channel,
              decoration: const InputDecoration(labelText: "Preferred care setting"),
              items: const ["In-person visit", "Online consultation / eConsult", '跨境医疗', "Tests and examinations"]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.tr)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _channel = value!),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasRecords,
              title: const Text("I have medical records, images or test results"),
              subtitle: const Text("A categorized upload checklist will be created after submission. OCR confidence and original text will be retained."),
              onChanged: (value) => setState(() => _hasRecords = value),
            ),
            CheckboxListTile(
              value: _identityConfirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Confirm the patient is ${widget.memberName}'),
              onChanged: (value) => setState(() => _identityConfirmed = value!),
            ),
            CheckboxListTile(
              value: _consent,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text("I consent to the minimum necessary information being used for referral assessment and care coordination"),
              subtitle: const Text("Information will not be automatically shared with insurance sales, underwriting or communities."),
              onChanged: (value) => setState(() => _consent = value!),
            ),
            if (!_identityConfirmed || !_consent)
              const Padding(
                padding: EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  "Confirm the patient and consent to the stated use before submitting",
                  style: TextStyle(color: VvewellColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('submit-referral-intake'),
                onPressed: _submit,
                icon: const Icon(Icons.assignment_turned_in_outlined),
                label: const Text("Submit for review"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteConfirmationSheet extends StatefulWidget {
  const _QuoteConfirmationSheet({
    required this.serviceName,
    required this.serviceFee,
  });

  final String serviceName;
  final String serviceFee;

  @override
  State<_QuoteConfirmationSheet> createState() =>
      _QuoteConfirmationSheetState();
}

class _QuoteConfirmationSheetState extends State<_QuoteConfirmationSheet> {
  bool _platformFee = false;
  bool _hospitalFee = false;
  bool _thirdPartyFee = false;
  bool _agreement = false;

  bool get _canConfirm =>
      _platformFee && _hospitalFee && _thirdPartyFee && _agreement;

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: "Confirm service plan and quote",
      subtitle: "Quotes are valid for 48 hours. Any changes will be shown and require confirmation again.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VvewellColors.softTeal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.serviceFee,
                  style: const TextStyle(
                    color: VvewellColors.primaryDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text("Platform care service fee · One payment for this service"),
                const SizedBox(height: 4),
                const Text(
                  "Estimated duration: 2–6 weeks, including records preparation, provider matching, appointment coordination and follow-up",
                  style: TextStyle(color: VvewellColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _FormSectionTitle("Confirm what the fees cover"),
          const SizedBox(height: 6),
          _BoundaryCheckbox(
            value: _platformFee,
            title: "I understand the amount above covers platform care services only",
            onChanged: (value) => setState(() => _platformFee = value),
          ),
          _BoundaryCheckbox(
            value: _hospitalFee,
            title: "I understand hospital medical charges are not included",
            subtitle: "I pay registration, tests, medication, treatment, surgery and inpatient charges directly to the hospital.",
            onChanged: (value) => setState(() => _hospitalFee = value),
          ),
          _BoundaryCheckbox(
            value: _thirdPartyFee,
            title: "I understand visa, flight, hotel, transport and other third-party costs are separate",
            onChanged: (value) => setState(() => _thirdPartyFee = value),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VvewellColors.softOrange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: VvewellColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Hospital estimates are provided by the hospital for reference and are not part of this payment. The platform does not combine these into an order total.",
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreement,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text("I have read the service agreement, privacy consent and refund policy"),
            onChanged: (value) => setState(() => _agreement = value!),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('confirm-medical-quote'),
              onPressed: _canConfirm
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text("Confirm plan and continue to agreement"),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsuranceNeedsSheet extends StatefulWidget {
  const _InsuranceNeedsSheet({required this.memberName});

  final String memberName;

  @override
  State<_InsuranceNeedsSheet> createState() => _InsuranceNeedsSheetState();
}

class _InsuranceNeedsSheetState extends State<_InsuranceNeedsSheet> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController(text: '12000');
  String _priority = '住院与门诊医疗';
  bool _hasExistingPolicy = true;
  bool _financialConfirmed = false;
  bool _licensedHandoff = false;

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        !_financialConfirmed ||
        !_licensedHandoff) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      InsuranceNeedsResult(
        annualBudget: int.parse(_budgetController.text),
        priority: _priority,
        hasExistingPolicy: _hasExistingPolicy,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '家庭保障规划',
      subtitle:
          '${'保障缺口评估适用于'.tr} ${widget.memberName}。${'平台提供适当性辅助，正式报价和核保由持牌机构完成。'.tr}',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FormSectionTitle('优先保障目标'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['住院与门诊医疗', '重大疾病', '家庭收入责任', '全球医疗']
                  .map(
                    (value) => ChoiceChip(
                      label: Text(value.tr),
                      selected: _priority == value,
                      onSelected: (_) => setState(() => _priority = value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('insurance-annual-budget'),
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '年度可持续预算（人民币）*'.tr,
                helperText: '预算用于适当性与支付可持续评估，不等同正式保费。'.tr,
                prefixText: '¥ ',
              ),
              validator: (value) {
                final budget = int.tryParse(value ?? '');
                if (budget == null || budget < 1000 || budget > 1000000) {
                  return '请输入 1,000 至 1,000,000 之间的年度预算'.tr;
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasExistingPolicy,
              title: Text('已有医疗或健康保险'.tr),
              subtitle: Text('下一步可上传电子保单，逐项确认责任、等待期、除外和网络。'.tr),
              onChanged: (value) => setState(() => _hasExistingPolicy = value),
            ),
            CheckboxListTile(
              value: _financialConfirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('我确认预算与家庭责任信息真实，并理解可随时修改'.tr),
              onChanged: (value) =>
                  setState(() => _financialConfirmed = value!),
            ),
            CheckboxListTile(
              value: _licensedHandoff,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('同意在我确认后，将必要信息交给具名持牌顾问复核'.tr),
              subtitle: Text('交接前可撤回；社区行为与设备风险预测不会自动进入核保。'.tr),
              onChanged: (value) => setState(() => _licensedHandoff = value!),
            ),
            if (!_financialConfirmed || !_licensedHandoff)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  '提交前需确认资料和持牌交接授权'.tr,
                  style: TextStyle(color: VvewellColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('submit-insurance-needs'),
                onPressed: _submit,
                icon: const Icon(Icons.calculate_outlined),
                label: Text('生成保障缺口与候选方案'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClaimDraftSheet extends StatefulWidget {
  const _ClaimDraftSheet({required this.memberName, required this.initialType});

  final String memberName;
  final String initialType;

  @override
  State<_ClaimDraftSheet> createState() => _ClaimDraftSheetState();
}

class _ClaimDraftSheetState extends State<_ClaimDraftSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  late String _type = widget.initialType;
  bool _invoice = false;
  bool _medicalRecord = false;
  bool _accuracyConfirmed = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || !_accuracyConfirmed) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      ClaimDraftResult(type: _type, amount: int.parse(_amountController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '新建理赔草稿',
      subtitle: '为 @member 整理材料。系统只做预填、完整度检查和状态跟踪，不会自动拒赔。'.trParams({
        'member': widget.memberName,
      }),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: '理赔类型 *'.tr),
              items: const ['医疗费用理赔', '重大疾病理赔', '意外医疗理赔', '预授权申请']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.tr)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('claim-amount'),
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '申请金额 *'.tr,
                prefixText: '¥ ',
              ),
              validator: (value) {
                final amount = int.tryParse(value ?? '');
                return amount == null || amount <= 0 ? '请输入有效金额'.tr : null;
              },
            ),
            const SizedBox(height: 16),
            const _FormSectionTitle('材料清单'),
            CheckboxListTile(
              value: _invoice,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('医疗发票与费用清单'.tr),
              subtitle: Text('上传后保留原图、页码、字段置信度和证据位置。'.tr),
              onChanged: (value) => setState(() => _invoice = value!),
            ),
            CheckboxListTile(
              value: _medicalRecord,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('病历、诊断证明或出院小结'.tr),
              onChanged: (value) => setState(() => _medicalRecord = value!),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VvewellColors.softOrange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _invoice && _medicalRecord
                    ? '材料完整度预估 86%。提交后仍以保险机构正式要求为准。'.tr
                    : '当前材料不完整。系统会一次性生成最小补件清单，不会重复索取已上传材料。'.tr,
              ),
            ),
            CheckboxListTile(
              value: _accuracyConfirmed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('我确认资料真实，并同意提交前再次核对抽取字段'.tr),
              onChanged: (value) => setState(() => _accuracyConfirmed = value!),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('submit-claim-draft'),
                onPressed: _submit,
                icon: const Icon(Icons.description_outlined),
                label: Text('保存理赔草稿'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityPostSheet extends StatefulWidget {
  const _CommunityPostSheet({required this.communityName});

  final String communityName;

  @override
  State<_CommunityPostSheet> createState() => _CommunityPostSheetState();
}

class _CommunityPostSheetState extends State<_CommunityPostSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _type = '经验分享';
  bool _allowComments = true;
  bool _privacyChecked = false;
  bool _experienceNotice = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        !_privacyChecked ||
        !_experienceNotice) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      CommunityPostDraft(type: _type, content: _contentController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '发布到@community'.trParams({'community': widget.communityName}),
      subtitle: '默认使用匿名别名“晨光 27”，不会带出真实姓名、手机号或保单身份。'.tr,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _type,
              decoration: InputDecoration(labelText: '内容类型 *'.tr),
              items: const ['经验分享', '问题求助', '情绪支持', '资源分享', '活动回顾']
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value.tr)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('community-post-content'),
              controller: _contentController,
              minLines: 5,
              maxLines: 9,
              decoration: InputDecoration(
                labelText: '内容 *'.tr,
                hintText: '分享经历、提出问题，或给同路人一些支持…'.tr,
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().length < 10
                  ? '请至少填写 10 个字'.tr
                  : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _allowComments,
              title: Text('允许评论与回复'.tr),
              onChanged: (value) => setState(() => _allowComments = value),
            ),
            CheckboxListTile(
              value: _privacyChecked,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('我已移除身份证、病历号、联系方式、精确地址和第三方隐私'.tr),
              onChanged: (value) => setState(() => _privacyChecked = value!),
            ),
            CheckboxListTile(
              value: _experienceNotice,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('我理解个人经历不构成医疗建议，紧急情况应联系急救或专业人员'.tr),
              onChanged: (value) => setState(() => _experienceNotice = value!),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: VvewellColors.softBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '发布前会进行隐私与医疗安全检查。普通内容即时发布，高风险内容可能进入人工审核，并提供原因和申诉入口。'.tr,
                style: TextStyle(height: 1.45),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('submit-community-post'),
                onPressed: _submit,
                icon: const Icon(Icons.send_outlined),
                label: Text('提交发布'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvisorContactSheet extends StatefulWidget {
  const _AdvisorContactSheet({
    required this.memberName,
    required this.productName,
  });

  final String memberName;
  final String productName;

  @override
  State<_AdvisorContactSheet> createState() => _AdvisorContactSheetState();
}

class _AdvisorContactSheetState extends State<_AdvisorContactSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController = TextEditingController(
    text: widget.memberName,
  );
  final _phoneController = TextEditingController();
  String _contactChannel = '电话';
  String _preferredTime = '工作日 09:00-12:00';
  bool _consent = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || !_consent) {
      setState(() {});
      return;
    }
    Navigator.pop(
      context,
      AdvisorContactResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        contactChannel: _contactChannel,
        preferredTime: _preferredTime,
        productName: widget.productName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: '预约具名持牌顾问复核',
      subtitle: '留下联系信息后，平台仅提交回访申请。正式报价、核保结论与销售建议由具名持牌人员提供。',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VvewellColors.softBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '复核方案：@product'.trParams({'product': widget.productName}),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('advisor-contact-name'),
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: '联系人姓名*'.tr),
              validator: (value) => value == null || value.trim().length < 2
                  ? '请输入联系人姓名'.tr
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('advisor-contact-phone'),
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '联系电话*'.tr,
                hintText: '手机号或可接听的国际号码'.tr,
              ),
              validator: (value) {
                final phone = value?.replaceAll(RegExp(r'[\s()+-]'), '') ?? '';
                if (!RegExp(r'^\d{6,15}$').hasMatch(phone)) {
                  return '请输入 6 至 15 位有效联系电话'.tr;
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            const _FormSectionTitle('希望如何联系'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['电话', '短信', '微信确认后通话']
                  .map(
                    (channel) => ChoiceChip(
                      label: Text(channel.tr),
                      selected: _contactChannel == channel,
                      onSelected: (_) =>
                          setState(() => _contactChannel = channel),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _preferredTime,
              decoration: InputDecoration(labelText: '方便联系的时间'.tr),
              items:
                  const [
                        '工作日 09:00-12:00',
                        '工作日 14:00-18:00',
                        '工作日 18:00-20:00',
                        '周末 10:00-18:00',
                      ]
                      .map(
                        (time) =>
                            DropdownMenuItem(value: time, child: Text(time.tr)),
                      )
                      .toList(),
              onChanged: (value) => setState(() => _preferredTime = value!),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('advisor-contact-consent'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _consent,
              title: Text('同意将联系信息与本次候选方案交给具名持牌顾问'.tr),
              subtitle: Text('不会自动共享社区行为、预测标签或未确认的医疗信息。'.tr),
              onChanged: (value) => setState(() => _consent = value!),
            ),
            if (!_consent)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  '提交前需确认最小必要信息授权'.tr,
                  style: TextStyle(color: VvewellColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('submit-advisor-contact'),
                onPressed: _submit,
                icon: const Icon(Icons.support_agent_outlined),
                label: Text('提交回访申请'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, keyboard + 16),
        child: SingleChildScrollView(
          key: const Key('medical-flow-sheet-scroll'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle.tr,
                style: const TextStyle(
                  color: VvewellColors.muted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyCallout extends StatelessWidget {
  const _SafetyCallout();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VvewellColors.softRed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VvewellColors.error.withValues(alpha: .24)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: VvewellColors.error),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "For persistent chest pain, severe breathing difficulty, altered consciousness, heavy bleeding or any life-threatening condition, contact local emergency services immediately. Do not wait for an online assessment.",
              style: TextStyle(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoundaryCheckbox extends StatelessWidget {
  const _BoundaryCheckbox({
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onChanged: (value) => onChanged(value!),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  const _FormSectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.tr,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}
