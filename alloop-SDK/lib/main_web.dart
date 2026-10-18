import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'foundations/localization/app_localization.dart';
import 'foundations/navigation/al_routes.dart';
import 'foundations/ui/vvewell_theme.dart';
import 'features/avatar_coach/data/mock_avatar_coach_service.dart';
import 'features/avatar_coach/presentation/controllers/avatar_coach_controller.dart';
import 'features/family/domain/family_member.dart';
import 'features/family/presentation/controllers/family_profile_controller.dart';
import 'features/main/home_page.dart';
import 'web/web_cloud.dart';
import 'web/web_records.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final response = await http
        .get(Uri.base.resolve('/api/config'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200)
      throw StateError('Server configuration is unavailable.');
    final config = jsonDecode(response.body);
    await Supabase.initialize(
      url: config['supabase_url'],
      publishableKey: config['supabase_public_key'],
    );
    Get.put(
      AppLanguageController()..currentLocale.value = const Locale('en', 'US'),
      permanent: true,
    );
    runApp(const WebApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Unable to start the app. Check the server configuration and reload.',
            ),
          ),
        ),
      ),
    );
  }
}

class WebApp extends StatelessWidget {
  const WebApp({super.key});
  @override
  Widget build(BuildContext context) => GetMaterialApp(
    title: 'vvewell',
    debugShowCheckedModeBanner: false,
    locale: const Locale('en', 'US'),
    fallbackLocale: const Locale('en', 'US'),
    translations: VvewellTranslations(),
    theme: vvewellTheme(),
    getPages: [
      for (final page in AlPages.pages)
        if (hardwareRoutes.containsKey(page.name) ||
            page.name == '/deviceCenter')
          GetPage(
            name: page.name,
            page: () => WebHardwarePage(
              title: hardwareRoutes[page.name] ?? 'Devices',
              showDevices: page.name == '/deviceCenter',
              source: page.name.contains('aizoring')
                  ? 'aizo'
                  : page.name == '/deviceDetail'
                  ? 'alloop'
                  : page.name.contains('radar')
                  ? 'radar'
                  : page.name.contains('thermal')
                  ? 'infrared'
                  : page.name.contains('rppg')
                  ? 'rppg'
                  : null,
            ),
          )
        else if (page.name == AlRoutes.home || page.name == AlRoutes.splash)
          GetPage(name: page.name, page: () => const DemoWebHome())
        else
          page,
      GetPage(
        name: '/sign-in',
        page: () => const WebAuthGate(child: WebAccountReady()),
      ),
      GetPage(
        name: '/cloud-records',
        page: () => const WebAuthGate(child: WebHome()),
      ),
      GetPage(
        name: '/find-doctor',
        page: () => const HomePage(initialTabIndex: 2),
      ),
    ],
    home: const DemoWebHome(),
    builder: (context, child) => Column(
      children: [
        Material(
          color: VvewellColors.softTeal,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Web preview · Includes original sample data',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(child: child ?? const SizedBox()),
      ],
    ),
  );
}

class DemoWebHome extends StatelessWidget {
  const DemoWebHome({super.key});
  @override
  Widget build(BuildContext context) => const HomePage();
}

class WebAccountReady extends StatelessWidget {
  const WebAccountReady({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('AI account')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'You are signed in. AI consultations and doctor recommendations are available.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Get.toNamed('/find-doctor'),
            child: const Text('Find a doctor'),
          ),
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    ),
  );
}

class WebAuthGate extends StatefulWidget {
  const WebAuthGate({super.key, required this.child});
  final Widget child;
  @override
  State<WebAuthGate> createState() => _WebAuthGateState();
}

class _WebAuthGateState extends State<WebAuthGate> {
  StreamSubscription<AuthState>? subscription;
  @override
  void initState() {
    super.initState();
    subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      state,
    ) {
      if (state.event == AuthChangeEvent.signedOut) WebCloud.instance.clear();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Supabase.instance.client.auth.currentSession == null
      ? const WebSignIn()
      : widget.child;
}

class WebSignIn extends StatefulWidget {
  const WebSignIn({super.key});
  @override
  State<WebSignIn> createState() => _WebSignInState();
}

class _WebSignInState extends State<WebSignIn> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false;
  String? message;
  Future<void> submit({bool create = false}) async {
    if (email.text.trim().isEmpty ||
        (create ? password.text.length < 8 : password.text.isEmpty)) {
      setState(
        () => message =
            'Enter an email address and a password of at least 8 characters.',
      );
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (create) {
        final result = await Supabase.instance.client.auth.signUp(
          email: email.text.trim(),
          password: password.text,
        );
        if (mounted && result.session == null)
          setState(
            () => message =
                'Check your email to confirm your account, then sign in.',
          );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on AuthException catch (_) {
      if (mounted)
        setState(
          () => message =
              'Unable to sign in or create the account. Check your details and email confirmation.',
        );
    } catch (_) {
      if (mounted)
        setState(() => message = 'Unable to connect. Please try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/images/vvewell-logo.png', height: 64),
              const SizedBox(height: 24),
              Text(
                'Sign in to your health account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to view private cloud records. The sample app and AI preview can be used without an account.',
              ),
              const SizedBox(height: 24),
              TextField(
                controller: email,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Password'),
                onSubmitted: busy ? null : (_) => submit(),
              ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(message!, semanticsLabel: message),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Text(busy ? 'Signing in…' : 'Sign in'),
              ),
              TextButton(
                onPressed: busy ? null : () => submit(create: true),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class WebHome extends StatefulWidget {
  const WebHome({super.key});
  @override
  State<WebHome> createState() => _WebHomeState();
}

class _WebHomeState extends State<WebHome> {
  Future<void>? loading;
  FamilyProfileController? family;
  final avatar = AvatarCoachController()
    ..switchFixture(AvatarCoachFixture.empty);
  @override
  void initState() {
    super.initState();
    loading = load();
  }

  Future<void> load() async {
    await WebCloud.instance.refresh();
    if (WebCloud.instance.profiles.isEmpty) return;
    family?.dispose();
    family = FamilyProfileController(
      initialMembers: WebCloud.instance.profiles
          .map(
            (p) => FamilyMember(
              id: p['id'],
              name: p['name'],
              relationship: p['relationship'],
              gender: p['gender'],
              birthYear: p['birth_year'] ?? 0,
              healthScore: 0,
              tags: const [],
              isSelf: p['relationship'] == 'self',
            ),
          )
          .toList(),
    );
    family!.addListener(() {
      final id = family!.activeMember.id;
      if (id != WebCloud.instance.memberId &&
          WebCloud.instance.profiles.any((p) => p['id'] == id)) {
        WebCloud.instance.selectMember(id).catchError((_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to load this member’s records.'),
              ),
            );
        });
      }
    });
  }

  @override
  void dispose() {
    avatar.onClose();
    family?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: loading,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.hasError)
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load cloud records. No sample records have been substituted.',
                ),
                TextButton(
                  onPressed: () => setState(() => loading = load()),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        );
      if (family == null)
        return WebCreateProfile(
          onSaved: () => setState(() => loading = load()),
        );
      return HomePage(
        avatarCoachController: avatar,
        familyProfileController: family,
      );
    },
  );
}

class WebCreateProfile extends StatefulWidget {
  const WebCreateProfile({super.key, required this.onSaved});
  final VoidCallback onSaved;
  @override
  State<WebCreateProfile> createState() => _WebCreateProfileState();
}

class _WebCreateProfileState extends State<WebCreateProfile> {
  final name = TextEditingController();
  final year = TextEditingController();
  String gender = 'unknown';
  bool busy = false;
  String? error;
  Future<void> save() async {
    final birth = int.tryParse(year.text);
    if (name.text.trim().isEmpty ||
        birth == null ||
        birth < 1900 ||
        birth > DateTime.now().year) {
      setState(() => error = 'Enter your name and a valid birth year.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await WebCloud.instance.request(
        '/api/cloud/profiles',
        body: {
          'profiles': [
            {
              'id': Supabase.instance.client.auth.currentUser!.id,
              'name': name.text.trim(),
              'birth_year': birth,
              'gender': gender,
              'relationship': 'owner',
            },
          ],
        },
      );
      if (mounted) widget.onSaved();
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'Unable to save your profile. Please try again.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your health profile')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No health profile is linked to this account. Create one to get started.',
              ),
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: year,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Birth year'),
              ),
              DropdownButtonFormField<String>(
                initialValue: gender,
                items: const [
                  DropdownMenuItem(
                    value: 'unknown',
                    child: Text('Sex not specified'),
                  ),
                  DropdownMenuItem(value: 'M', child: Text('Male')),
                  DropdownMenuItem(value: 'F', child: Text('Female')),
                ],
                onChanged: busy
                    ? null
                    : (value) => setState(() => gender = value!),
              ),
              if (error != null) Text(error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : save,
                child: Text(busy ? 'Saving…' : 'Save profile'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
