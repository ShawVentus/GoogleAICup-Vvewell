import 'dart:async';
import 'dart:convert';
import 'country_selector.dart';
import '../../foundations/ui/vvewell_theme.dart';
import '../main/chat_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const kApiBase = String.fromEnvironment(
  'DOCTOR_API_BASE',
  defaultValue: 'self',
);
String get apiBase => kApiBase == 'self' ? Uri.base.origin : kApiBase;

const teal = VvewellColors.primary;
const tealDark = VvewellColors.primaryDark;
const tealSoft = VvewellColors.softTeal;
const bg = VvewellColors.background;
const ink = VvewellColors.foreground;
const grey = VvewellColors.muted;
const blueSoft = VvewellColors.softBlue;
const line = VvewellColors.border;

class Bi {
  final String en, zh;
  Bi(Map? j)
    : en = (j?['en'] ?? '').toString(),
      zh = (j?['zh'] ?? '').toString();
}

class DoctorCardData {
  final String nameEn, id;
  final Bi title, dept;
  final List<Bi> matched;
  DoctorCardData(Map j)
    : id = j['doctor_id'] ?? '',
      nameEn = j['name_en'] ?? 'Physician',
      title = Bi(j['title']),
      dept = Bi(j['dept']),
      matched = [for (final m in (j['matched'] ?? [])) Bi(m)];
}

class HospitalCardData {
  final String nameEn, nameZh, districtEn;
  final Bi? feature, recognition, deptOnly;
  final List<DoctorCardData> doctors;
  HospitalCardData(Map j)
    : nameEn = j['name_en'] ?? '',
      nameZh = j['name_zh'] ?? '',
      districtEn = j['district_en'] ?? '',
      feature = j['feature'] == null ? null : Bi(j['feature']),
      recognition = j['recognition'] == null ? null : Bi(j['recognition']),
      deptOnly = j['dept_only'] == null ? null : Bi(j['dept_only']),
      doctors = [for (final d in (j['doctors'] ?? [])) DoctorCardData(d)];
}

class CardSet {
  final Bi department;
  final List<Bi> alsoConsider;
  final List<HospitalCardData> hospitals;
  CardSet(Map j)
    : department = Bi(j['department']),
      alsoConsider = [for (final a in (j['also_consider'] ?? [])) Bi(a)],
      hospitals = [for (final h in (j['hospitals'] ?? [])) HospitalCardData(h)];
}

enum Role { user, assistant }

class Msg {
  final Role role;
  final String text;
  final CardSet? cards;
  final bool emergency, typing;
  Msg(
    this.role,
    this.text, {
    this.cards,
    this.emergency = false,
    this.typing = false,
  });
}

// ---------------------------------------------------------------- 对话页
class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    this.client,
    this.endpoint,
    this.showTopChips = true,
    this.memberName,
  });
  final bool showTopChips;
  final String? memberName;
  final http.Client? client;
  final Uri? endpoint;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final msgs = <Msg>[];
  final input = TextEditingController();
  final patientAge = TextEditingController();
  String sexAtBirth = 'unknown';
  String? ageError;
  final scroll = ScrollController();
  bool busy = false;
  String currentCountry = 'OTHER';
  final shownDoctors = <String>{};
  late final client = widget.client ?? http.Client();

  @override
  void dispose() {
    client.close();
    input.dispose();
    patientAge.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> send(String text) async {
    text = text.trim();
    if (text.isEmpty || busy) return;
    final ageText = patientAge.text.trim();
    final parsedAge = int.tryParse(ageText);
    if (ageText.isNotEmpty &&
        (parsedAge == null || parsedAge < 0 || parsedAge > 120)) {
      setState(() => ageError = 'Enter an age from 0 to 120');
      return;
    }
    setState(() => ageError = null);
    input.clear();
    setState(() {
      busy = true;
      msgs.add(Msg(Role.user, text));
      msgs.add(Msg(Role.assistant, 'Thinking…', typing: true));
    });
    _toBottom();
    final Msg answer = await _liveAnswer();
    if (answer.cards != null) {
      for (final h in answer.cards!.hospitals) {
        for (final d in h.doctors) {
          if (d.id.isNotEmpty) shownDoctors.add(d.id);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      msgs.removeWhere((m) => m.typing);
      msgs.add(answer);
      busy = false;
    });
    _toBottom();
  }

  // 联网：整段对话历史交给后端的对话 AI（它自己决定追问还是调用推荐工具）。
  // 用 SSE 流式接口：服务端会陆续推送进度（status），最后推送结果（result）。
  Future<Msg> _liveAnswer() async {
    try {
      final history = <Map<String, String>>[];
      for (final m in msgs.where((m) => !m.typing && m.text.isNotEmpty)) {
        var content = m.text;
        if (m.cards != null) {
          content +=
              '\nDisplayed hospitals: ${m.cards!.hospitals.map((h) => '${h.nameEn}').join('; ')}';
        }
        history.add({
          'role': m.role == Role.user ? 'user' : 'assistant',
          'content': content.length > 4000
              ? content.substring(0, 4000)
              : content,
        });
      }
      while (history.length > 2 &&
          (history.length > 30 ||
              utf8.encode(jsonEncode(history)).length > 48000)) {
        history.removeAt(1);
      }
      final req =
          http.Request(
              'POST',
              widget.endpoint ?? Uri.parse('$apiBase/api/chat/stream'),
            )
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode({
              'messages': history,
              'shown_doctor_ids': shownDoctors.take(100).toList(),
              'current_country': currentCountry,
              'age': int.tryParse(patientAge.text.trim()),
              'sex_at_birth': sexAtBirth,
            });
      final resp = await client.send(req).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 429)
        return Msg(
          Role.assistant,
          'You are sending messages too quickly. Please wait a minute and try again.',
        );
      if (resp.statusCode == 503)
        return Msg(
          Role.assistant,
          'The service is busy right now. Please try again in a moment.',
        );
      if (resp.statusCode != 200)
        return Msg(
          Role.assistant,
          'Sorry, something went wrong on our side (${resp.statusCode}). Please try again.',
        );
      String event = '', data = '';
      await for (final line
          in resp.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(seconds: 150))) {
        if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data = line.substring(5).trim();
        } else if (line.isEmpty && event.isNotEmpty) {
          final j = jsonDecode(data);
          if (event == 'status') {
            if (mounted)
              setState(() => _setTyping((j['text'] ?? 'Thinking…').toString()));
          } else if (event == 'result') {
            return Msg(
              Role.assistant,
              (j['reply'] ?? '').toString(),
              cards: j['cards'] == null ? null : CardSet(j['cards']),
              emergency: j['type'] == 'emergency',
            );
          } else if (event == 'error') {
            return Msg(
              Role.assistant,
              'Sorry, something went wrong on our side. Please try again.',
            );
          }
          event = '';
          data = '';
        }
      }
      return Msg(
        Role.assistant,
        'Sorry, the connection ended before I could answer. Please try again.',
      );
    } catch (_) {
      return Msg(
        Role.assistant,
        "Sorry, I couldn't reach the service. Please check your connection and try again.",
      );
    }
  }

  void _setTyping(String text) {
    final i = msgs.lastIndexWhere((m) => m.typing);
    if (i >= 0) msgs[i] = Msg(Role.assistant, text, typing: true);
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (scroll.hasClients) {
      scroll.animateTo(
        scroll.position.maxScrollExtent + 300,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });

  Widget _patientDetails() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 64,
        child: TextField(
          key: const Key('doctor-patient-age'),
          controller: patientAge,
          enabled: !busy,
          style: const TextStyle(fontSize: 12),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            labelText: 'Age',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 12,
            ),
            errorText: ageError,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 4,
        child: DropdownButtonFormField<String>(
          key: const Key('doctor-patient-sex'),
          initialValue: sexAtBirth,
          isExpanded: true,
          iconSize: 18,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: const InputDecoration(
            labelText: 'Sex at birth',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          ),
          selectedItemBuilder: (context) => const [
            Text('Unknown', overflow: TextOverflow.ellipsis),
            Text('Female'),
            Text('Male'),
          ],
          items: const [
            DropdownMenuItem(value: 'unknown', child: Text('Not specified')),
            DropdownMenuItem(value: 'F', child: Text('Female')),
            DropdownMenuItem(value: 'M', child: Text('Male')),
          ],
          onChanged: busy
              ? null
              : (value) => setState(() => sexAtBirth = value ?? 'unknown'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        flex: 5,
        child: IgnorePointer(
          ignoring: busy,
          child: CountrySelector(
            value: currentCountry,
            compact: true,
            onChanged: (value) => setState(() => currentCountry = value),
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.showTopChips) const TopChips(),
      Expanded(
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 18),
          children: [
            if (msgs.isEmpty) ...[
              Header(memberName: widget.memberName),
              const SizedBox(height: 22),
              const Text(
                'Try one of these questions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              QuickQuestion(
                tag: 'Find a doctor',
                text: 'Can you help me find a suitable doctor?',
                onTap: () => send('Can you help me find a suitable doctor?'),
              ),
              QuickQuestion(
                tag: 'Gynecology',
                text:
                    'I am 38, female. I have uterine fibroids and would like to find a doctor.',
                onTap: () => send(
                  'I am 38, female. I have uterine fibroids and would like to find a doctor.',
                ),
              ),
              QuickQuestion(
                tag: 'Urgent signs',
                text: 'My father has crushing chest pain and is sweating',
                onTap: () =>
                    send('My father has crushing chest pain and is sweating'),
              ),
            ],
            for (final m in msgs) _bubble(m),
          ],
        ),
      ),
      ChatComposer(
        controller: input,
        onSend: () => send(input.text),
        hintText: 'Ask about finding a doctor',
        enabled: !busy,
        inputKey: const Key('doctor-message'),
        header: _patientDetails(),
      ),
    ],
  );

  Widget _bubble(Msg m) {
    if (m.typing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: teal),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                m.text.isEmpty ? 'Thinking…' : m.text,
                style: const TextStyle(color: grey),
              ),
            ),
          ],
        ),
      );
    }
    if (m.role == Role.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          constraints: BoxConstraints(maxWidth: 300),
          decoration: BoxDecoration(
            color: teal,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            m.text,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      );
    }
    if (m.emergency) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE57373)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF7F1D1D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (m.text.isNotEmpty)
          BotBox(
            child: Text(
              m.text,
              style: const TextStyle(height: 1.4, color: ink),
            ),
          ),
        if (m.cards != null) ...[
          if (m.cards!.alsoConsider.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
              child: Text(
                'May also involve: ${m.cards!.alsoConsider.map((a) => a.en).join(', ')}',
                style: const TextStyle(fontSize: 12.5, color: grey),
              ),
            ),
          for (var i = 0; i < m.cards!.hospitals.length; i++)
            HospitalCard(index: i + 1, h: m.cards!.hospitals[i]),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Text(
              'For reference only; it does not replace a doctor. Your care coordinator will help arrange the visit. Physician names are romanized and may differ from their preferred English spelling.',
              style: TextStyle(fontSize: 12, color: grey, height: 1.5),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- 组件
class BiText extends StatelessWidget {
  final String en, zh;
  final double enSize, zhSize;
  final FontWeight enWeight;
  const BiText(
    this.en,
    this.zh, {
    super.key,
    this.enSize = 15,
    this.zhSize = 12.5,
    this.enWeight = FontWeight.w600,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (en.isNotEmpty)
        Text(
          en,
          style: TextStyle(
            fontSize: enSize,
            fontWeight: enWeight,
            color: ink,
            height: 1.3,
          ),
        ),
    ],
  );
}

class TopChips extends StatelessWidget {
  const TopChips({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.local_hospital_outlined, 'Find a doctor'),
      (Icons.description_outlined, 'Reports'),
      (Icons.restaurant_outlined, 'Nutrition'),
      (Icons.medication_outlined, 'Medication'),
    ];
    return Container(
      color: Colors.white,
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemCount: items.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final sel = i == 0;
          return GestureDetector(
            onTap: sel
                ? null
                : () => ScaffoldMessenger.of(c).showSnackBar(
                    const SnackBar(
                      content: Text('Not available in this preview'),
                      duration: Duration(seconds: 1),
                    ),
                  ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: sel ? teal : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: sel ? teal : const Color(0xFFD5DEDC)),
              ),
              child: Row(
                children: [
                  Icon(items[i].$1, size: 20, color: sel ? Colors.white : ink),
                  const SizedBox(width: 6),
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key, this.memberName});
  final String? memberName;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: teal.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(15.6),
        ),
        child: const Icon(Icons.person_search_outlined, color: teal, size: 26),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Find a doctor',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
            ),
            SizedBox(height: 2),
            Text(
              memberName == null
                  ? 'Find care for your health needs'
                  : "${memberName}'s personalized consultation",
              style: const TextStyle(color: grey, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color, fg;
  const Pill(this.text, {super.key, this.color = Colors.white, this.fg = ink});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(8),
      border: color == Colors.white
          ? Border.all(color: const Color(0xFFD5DEDC))
          : null,
    ),
    child: Text(text, style: TextStyle(fontSize: 12.5, color: fg)),
  );
}

class QuickQuestion extends StatelessWidget {
  final String tag, text;
  final VoidCallback onTap;
  const QuickQuestion({
    super.key,
    required this.tag,
    required this.text,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: line),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tealSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: tealDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: ink, height: 1.4),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: grey,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BotBox extends StatelessWidget {
  final Widget child;
  const BotBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 300),
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: line),
    ),
    child: child,
  );
}

class HospitalCard extends StatelessWidget {
  final int index;
  final HospitalCardData h;
  const HospitalCard({super.key, required this.index, required this.h});
  Widget _note(IconData icon, Color color, Bi b) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: tealDark),
        const SizedBox(width: 8),
        Expanded(
          child: BiText(
            b.en,
            b.zh,
            enSize: 13,
            zhSize: 12,
            enWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 6),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: teal,
              child: Text(
                '$index',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BiText(
                h.nameEn.isEmpty ? 'Hospital' : h.nameEn,
                h.nameEn.isEmpty ? '' : h.nameZh,
                enSize: 16.5,
                zhSize: 13,
                enWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (h.districtEn.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 36),
            child: Pill(h.districtEn, color: tealSoft, fg: tealDark),
          ),
        if (h.feature != null) _note(Icons.public, tealSoft, h.feature!),
        if (h.recognition != null)
          _note(Icons.verified_outlined, blueSoft, h.recognition!),
        if (h.deptOnly != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: BiText(
              'Register with: ${h.deptOnly!.en} (no matching doctor in our list)',
              h.deptOnly!.zh,
              enSize: 13.5,
              enWeight: FontWeight.w400,
            ),
          ),
        for (final d in h.doctors) DoctorCard(d: d),
      ],
    ),
  );
}

class DoctorCard extends StatelessWidget {
  final DoctorCardData d;
  const DoctorCard({super.key, required this.d});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF6FAF9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: tealSoft,
              child: Text(
                d.nameEn.characters.isEmpty ? '?' : d.nameEn.characters.first,
                style: const TextStyle(
                  color: tealDark,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.nameEn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  BiText(d.title.en, d.title.zh, enSize: 13.5, zhSize: 12),
                  const SizedBox(height: 4),
                  BiText(
                    d.dept.en,
                    d.dept.zh,
                    enSize: 13.5,
                    zhSize: 12,
                    enWeight: FontWeight.w400,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (d.matched.any((k) => k.en.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Related to your concern:',
                style: TextStyle(fontSize: 12.5, color: grey),
              ),
              for (final k in d.matched.where((k) => k.en.isNotEmpty))
                Pill(k.en, color: tealSoft, fg: tealDark),
            ],
          ),
        ],
      ],
    ),
  );
}
