import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'web_cloud.dart';
import '../features/health_reports/data/medical_ocr_service.dart';
import '../features/health_reports/data/medical_report_store.dart';

class WebReadingsPanel extends StatelessWidget {
  const WebReadingsPanel({super.key, this.category, this.source});
  final String? category;
  final String? source;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: WebCloud.instance,
    builder: (context, _) {
      if (WebCloud.instance.error != null)
        return Column(
          children: [
            Text(WebCloud.instance.error!),
            TextButton(
              onPressed: () async {
                try {
                  await WebCloud.instance.refresh();
                } catch (_) {}
              },
              child: const Text('Retry'),
            ),
          ],
        );
      final rows = WebCloud.instance.readings.where((row) {
        final metric = '${row['metric_type']}';
        return (source == null || '${row['source']}'.contains(source!)) &&
            (category == null ||
                (category == 'sleep'
                    ? metric.contains('sleep')
                    : category == 'activity'
                    ? [
                        'steps',
                        'calories',
                        'distance',
                        'sport',
                      ].contains(metric)
                    : category == 'women'
                    ? ['cycle', 'period'].any(metric.contains)
                    : true));
      }).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Cloud health records',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Records uploaded by your mobile app. No sample measurements are shown.',
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No uploaded records are available for this member. Collect and sync measurements in the mobile app.',
              ),
            ),
          for (final row in rows.take(100))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${row['metric_type']}'.replaceAll('_', ' ')),
              trailing: Text('${row['value']} ${row['unit']}'),
              subtitle: Text(
                '${DateTime.parse(row['recorded_at']).toLocal()} · ${row['source']}',
              ),
            ),
        ],
      );
    },
  );
}

const hardwareRoutes = <String, String>{
  '/scan': 'Scan and connect',
  '/deviceDetail': 'Device details',
  '/algorithmVerify': 'Algorithm verification',
  '/historySyncDebug': 'History synchronization',
  '/aizoringDeviceDetail': 'AIZO Ring',
  '/aizoringMeasurement': 'Ring measurement',
  '/aizoringHealthData': 'Ring health data',
  '/aizoringSleep': 'Ring sleep records',
  '/xiaozhiDeviceDetail': 'XiaoZhi assistant',
  '/radarDeviceDetail': 'Radar records',
  '/robotDeviceDetail': 'Robot',
  '/rppgMeasurement': 'Phone camera measurement',
  '/rokidGlasses': 'Smart glasses',
  '/thermalCamera': 'Thermal camera',
};

class WebHardwarePage extends StatelessWidget {
  const WebHardwarePage({
    super.key,
    required this.title,
    this.showDevices = false,
    this.source,
  });
  final String title;
  final bool showDevices;
  final String? source;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Direct measurement and device connection require the mobile app. This page shows uploaded records and reports.',
        ),
        const SizedBox(height: 16),
        if (showDevices) ...[
          for (final entry in hardwareRoutes.entries)
            ListTile(
              title: Text(entry.value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Get.toNamed(entry.key),
            ),
          const Divider(),
        ],
        WebReadingsPanel(source: source),
      ],
    ),
  );
}

Future<MedicalReportResult?> showWebReportUpload(
  BuildContext context, {
  String? memberId,
}) => showModalBottomSheet<MedicalReportResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => WebReportUpload(memberId: memberId),
);

class WebReportUpload extends StatefulWidget {
  const WebReportUpload({super.key, this.memberId});
  final String? memberId;
  @override
  State<WebReportUpload> createState() => _WebReportUploadState();
}

class _WebReportUploadState extends State<WebReportUpload> {
  XFile? image;
  bool busy = false;
  String? error;
  Future<void> upload() async {
    if (image == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final bytes = await image!.readAsBytes();
      final extension = image!.name.toLowerCase().split('.').last;
      final mime = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
          ? 'image/webp'
          : ['jpg', 'jpeg'].contains(extension)
          ? 'image/jpeg'
          : '';
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024 || mime.isEmpty) {
        throw const FormatException(
          'Choose a PNG, JPEG, or WebP image smaller than 5 MB.',
        );
      }
      final result = await WebCloud.instance.request(
        '/api/ocr',
        body: {
          'member_id':
              WebCloud.instance.profiles.any((p) => p['id'] == widget.memberId)
              ? widget.memberId
              : null,
          'image': base64Encode(bytes),
          'mime': mime,
        },
      );
      final ocr = MedicalOcrResult.fromJson(Map<String, dynamic>.from(result));
      if (!mounted) return;
      Navigator.pop(
        context,
        MedicalReportResult(
          reportType: ocr.examType,
          institution: ocr.hospital,
          reportDate: DateTime.tryParse(ocr.examDate),
          summary: ocr.summary,
          photoPath: null,
          isDemo: false,
          ocrResult: ocr,
        ),
      );
    } catch (e) {
      if (mounted)
        setState(
          () => error = e is FormatException
              ? e.message
              : 'Unable to read or save this report. No sample result has been substituted.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Upload a medical report',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'The selected image is sent to the configured AI service for text recognition. Verify extracted values against the original report.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Without a linked cloud profile, extracted reports stay in this preview session.',
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => Navigator.pop(
                    context,
                    MedicalReportResult(
                      reportType: 'Sample examination report',
                      institution: 'Sample hospital',
                      reportDate: DateTime(2026, 7, 25),
                      summary:
                          'Sample OCR report for exploring the original app workflow. This is not your medical record.',
                      photoPath: null,
                      isDemo: true,
                    ),
                  ),
            child: const Text('Use the original sample-report workflow'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final selected = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 2000,
                      imageQuality: 90,
                    );
                    if (mounted && selected != null)
                      setState(() {
                        image = selected;
                        error = null;
                      });
                  },
            icon: const Icon(Icons.upload_file),
            label: Text(image?.name ?? 'Choose report image'),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(error!),
            ),
          FilledButton(
            onPressed: busy || image == null ? null : upload,
            child: Text(busy ? 'Reading report…' : 'Read report'),
          ),
        ],
      ),
    ),
  );
}
