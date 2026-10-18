import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../web/web_records.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../../../foundations/ui/vvewell_theme.dart';
import '../data/medical_ocr_service.dart';
import '../data/medical_report_store.dart';

Future<MedicalReportResult?> showMedicalReportUploadSheet(
  BuildContext context, {
  required String memberName,
  String? memberId,
  bool saveToMedicalArchive = true,
}) {
  if (kIsWeb)
    return showWebReportUpload(
      context,
      memberId: saveToMedicalArchive ? memberId : null,
    );
  return showModalBottomSheet<MedicalReportResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _MedicalReportUploadSheet(
      memberName: memberName,
      saveToMedicalArchive: saveToMedicalArchive,
    ),
  );
}

class _MedicalReportUploadSheet extends StatefulWidget {
  const _MedicalReportUploadSheet({
    required this.memberName,
    required this.saveToMedicalArchive,
  });

  final String memberName;
  final bool saveToMedicalArchive;

  @override
  State<_MedicalReportUploadSheet> createState() =>
      _MedicalReportUploadSheetState();
}

class _MedicalReportUploadSheetState extends State<_MedicalReportUploadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _institutionController = TextEditingController(
    text: Get.locale?.languageCode == 'en'
        ? 'Peking Union Medical College Hospital'
        : '北京协和医院',
  );
  final _picker = ImagePicker();
  String _reportType = '体检报告';
  DateTime _reportDate = DateTime.now();
  File? _photo;
  bool _useDemo = false;
  bool _consent = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _institutionController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file != null && mounted) {
      setState(() {
        _photo = File(file.path);
        _useDemo = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _reportDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (result != null) setState(() => _reportDate = result);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        (_photo == null && !_useDemo) ||
        !_consent) {
      setState(() {});
      return;
    }
    setState(() => _isSubmitting = true);
    MedicalOcrResult? ocrResult;
    if (_photo != null) {
      try {
        ocrResult = await MedicalOcrService().recognize(_photo!);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${'报告识别失败'.tr}: $error')));
          setState(() => _isSubmitting = false);
        }
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      MedicalReportResult(
        reportType: _reportType,
        institution: _institutionController.text.trim(),
        reportDate: _reportDate,
        summary:
            ocrResult?.summary ??
            switch (_reportType) {
              '检验报告' => 'Mock OCR：血常规主要指标处于参考范围，维生素 D 指标建议结合原报告复核。'.tr,
              '影像报告' => 'Mock OCR：已提取检查部位、检查方法和影像结论，建议由专业医生结合原片解读。'.tr,
              '出院小结' => 'Mock OCR：已提取诊断、治疗经过、出院用药与复诊计划，请人工确认药名及剂量。'.tr,
              _ => 'Mock OCR：已提取体检项目与异常提示，发现内容需结合原报告和医生意见复核。'.tr,
            },
        photoPath: _photo?.path,
        isDemo: _useDemo,
        ocrResult: ocrResult,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date =
        '${_reportDate.year}-${_reportDate.month.toString().padLeft(2, '0')}-${_reportDate.day.toString().padLeft(2, '0')}';
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          key: const Key('medical-report-upload-scroll'),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '上传医疗报告'.tr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.saveToMedicalArchive
                      ? '报告将归入 @member 的独立健康档案。OCR 结果必须与原件核对。'.trParams({
                          'member': widget.memberName,
                        })
                      : '报告仅用于本次咨询，不会写入医疗档案。OCR 结果必须与原件核对。'.tr,
                  style: const TextStyle(
                    color: VvewellColors.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _reportType,
                  decoration: InputDecoration(labelText: '报告类型'.tr),
                  items: const ['体检报告', '检验报告', '影像报告', '出院小结']
                      .map(
                        (type) =>
                            DropdownMenuItem(value: type, child: Text(type.tr)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _reportType = value!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _institutionController,
                  decoration: InputDecoration(labelText: '${'医疗机构'.tr}*'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? '请输入医疗机构'.tr
                      : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: '报告日期'.tr,
                      suffixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(date),
                  ),
                ),
                const SizedBox(height: 16),
                if (_photo == null && !_useDemo)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: Text('拍摄报告'.tr),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined),
                          label: Text('选择图片'.tr),
                        ),
                      ),
                    ],
                  )
                else if (_photo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _photo!,
                      width: double.infinity,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: VvewellColors.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: Color(0xFF3A8DD9),
                        ),
                        SizedBox(width: 10),
                        Expanded(child: Text('已载入用于流程演示的脱敏体检报告'.tr)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('use-demo-medical-report'),
                  onPressed: () => setState(() {
                    _useDemo = true;
                    _photo = null;
                  }),
                  icon: const Icon(Icons.science_outlined),
                  label: Text('使用脱敏演示报告'.tr),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _consent,
                  title: Text(
                    widget.saveToMedicalArchive
                        ? '确认报告归属与内容，并同意用于本人的健康档案分析'.tr
                        : '确认报告内容，并同意用于本次报告咨询'.tr,
                  ),
                  subtitle: Text('分析结果仅作信息整理，不替代医生诊断。'.tr),
                  onChanged: (value) => setState(() => _consent = value!),
                ),
                if ((_photo == null && !_useDemo) || !_consent)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      '请选择报告并确认授权后提交'.tr,
                      style: const TextStyle(
                        color: VvewellColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    key: const Key('submit-medical-report'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      (_isSubmitting ? '正在识别报告...' : '上传并生成 OCR 分析').tr,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
