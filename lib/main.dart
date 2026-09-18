import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'account_service.dart';
import 'catalog.dart';
import 'firebase_options.dart';
import 'story.dart';

const ink = Color(0xFF1E344E);
const teal = Color(0xFF1D9EA2);
const coral = Color(0xFFE98B72);
const cream = Color(0xFFFFFCF5);
const lavender = Color(0xFFF0E9FF);
const gold = Color(0xFFFFCF48);
ContentCatalog appCatalog = const ContentCatalog([StoryBook.builtIn], []);

bool _isRemotePath(String path) =>
    path.startsWith('https://') || path.startsWith('http://');

String? _localFallbackFor(String path) {
  final uri = Uri.tryParse(path);
  if (uri == null || !uri.path.startsWith('/v1/assets/')) return null;
  final key = Uri.decodeComponent(uri.path.substring('/v1/assets/'.length));
  return 'assets/content/$key';
}

Widget contentImage(String path, {BoxFit fit = BoxFit.contain}) {
  if (!_isRemotePath(path)) return Image.asset(path, fit: fit);
  return Image.network(
    path,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      final fallback = _localFallbackFor(path);
      return fallback == null
          ? const ColoredBox(color: Color(0xFFF4EEE3))
          : Image.asset(fallback, fit: fit);
    },
  );
}

Source contentAudioSource(String path) => _isRemotePath(path)
    ? UrlSource(path)
    : AssetSource(path.replaceFirst('assets/', ''));

String localReadKey(String storyId, SharedPreferences prefs) {
  if (ParentAccountService.instance.currentUser == null) return 'read_$storyId';
  final childId = prefs.getString('active_child_id') ?? 'primary';
  return 'read_${childId}_$storyId';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final prefs = await SharedPreferences.getInstance();
  final savedName = prefs.getString('child_name');
  if (ParentAccountService.instance.currentUser != null && savedName != null) {
    try {
      await ParentAccountService.instance.ensureParentAndSync(
        childName: savedName,
        prefs: prefs,
      );
    } catch (error) {
      debugPrint('Startup account sync unavailable: $error');
    }
  }
  appCatalog = await ContentCatalog.load();
  runApp(GembalaApp(prefs: prefs));
}

class GembalaApp extends StatefulWidget {
  const GembalaApp({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<GembalaApp> createState() => _GembalaAppState();
}

class _GembalaAppState extends State<GembalaApp> {
  String? get childName => widget.prefs.getString('child_name');
  Future<void> saveName(String name) async {
    await widget.prefs.setString('child_name', name);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gembala Kecil',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: cream,
          fontFamily: 'Fredoka',
          colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: cream),
          appBarTheme: const AppBarTheme(
              backgroundColor: cream,
              foregroundColor: ink,
              surfaceTintColor: Colors.transparent),
          textTheme:
              const TextTheme(bodyMedium: TextStyle(color: ink, fontSize: 16)),
        ),
        home: SplashScreen(
            name: childName, onNameSaved: saveName, prefs: widget.prefs),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen(
      {super.key,
      required this.name,
      required this.onNameSaved,
      required this.prefs});
  final String? name;
  final Future<void> Function(String) onNameSaved;
  final SharedPreferences prefs;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  widget.prefs.getBool('onboarding_complete') != true ||
                          widget.name == null
                      ? NameScreen(
                          onNameSaved: widget.onNameSaved,
                          prefs: widget.prefs,
                          initialName: widget.name)
                      : HomeScreen(
                          name: widget.name!,
                          prefs: widget.prefs,
                          onNameChanged: widget.onNameSaved,
                        )));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(child: Image.asset('assets/brand/logo.png', width: 230)));
}

class NameScreen extends StatefulWidget {
  const NameScreen(
      {super.key,
      required this.onNameSaved,
      required this.prefs,
      this.initialName});
  final Future<void> Function(String) onNameSaved;
  final SharedPreferences prefs;
  final String? initialName;
  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final controller = TextEditingController();
  @override
  void initState() {
    super.initState();
    controller.text = widget.initialName ?? '';
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void next() {
    final name = controller.text.trim();
    if (name.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => AccountIntroScreen(
                name: name,
                onNameSaved: widget.onNameSaved,
                prefs: widget.prefs)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Image.asset('assets/brand/logo.png', height: 90),
                  const SizedBox(height: 32),
                  const Text('Siapa nama panggilanmu?',
                      style: TextStyle(
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                  const SizedBox(height: 8),
                  const Text('Biar Gembala bisa menyapamu setiap hari.',
                      style: TextStyle(color: Color(0xFF687889))),
                  const SizedBox(height: 22),
                  TextField(
                    key: const Key('child-name-input'),
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => next(),
                    decoration: InputDecoration(
                        hintText: 'Contoh: Dante',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide:
                                const BorderSide(color: Color(0xFFE8DDCE))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide:
                                const BorderSide(color: Color(0xFFE8DDCE)))),
                  ),
                  const SizedBox(height: 16),
                  _PrimaryButton('Lanjutkan', next),
                  const Spacer(),
                ],
              ))));
}

class AccountIntroScreen extends StatelessWidget {
  const AccountIntroScreen(
      {super.key,
      required this.name,
      required this.onNameSaved,
      required this.prefs});
  final String name;
  final Future<void> Function(String) onNameSaved;
  final SharedPreferences prefs;
  Future<void> finish(BuildContext context) async {
    await onNameSaved(name);
    await prefs.setBool('onboarding_complete', true);
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
              builder: (_) => HomeScreen(
                    name: name,
                    prefs: prefs,
                    onNameChanged: onNameSaved,
                  )),
          (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const Spacer(),
                  Image.asset('assets/brand/mascot_cutout.png', height: 220),
                  const SizedBox(height: 16),
                  const Text('Simpan perjalanan ceritamu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          height: 1.05,
                          fontWeight: FontWeight.w700,
                          color: ink)),
                  const SizedBox(height: 15),
                  const Text(
                      'Buat akun orang tua untuk menyimpan pembelian, mencadangkan data, dan melanjutkan di perangkat lain.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          height: 1.35,
                          color: Color(0xFF687889))),
                  const SizedBox(height: 28),
                  _PrimaryButton('Buat Akun Orang Tua', () async {
                    final connected = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParentAuthScreen(
                          childName: name,
                          prefs: prefs,
                        ),
                      ),
                    );
                    if (connected == true && context.mounted) {
                      await finish(context);
                    }
                  }),
                  const SizedBox(height: 10),
                  TextButton(
                      onPressed: () => finish(context),
                      child: const Text('Lewati Sekarang',
                          style: TextStyle(
                              color: ink, fontWeight: FontWeight.w600))),
                  const Spacer(),
                ],
              ))));
}

class ParentAuthScreen extends StatefulWidget {
  const ParentAuthScreen({
    super.key,
    required this.childName,
    required this.prefs,
  });

  final String childName;
  final SharedPreferences prefs;

  @override
  State<ParentAuthScreen> createState() => _ParentAuthScreenState();
}

class _ParentAuthScreenState extends State<ParentAuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool createMode = true;
  bool busy = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  String messageFor(Object exception) {
    if (exception is FirebaseAuthException) {
      return switch (exception.code) {
        'email-already-in-use' => 'Email ini sudah memiliki akun. Pilih Masuk.',
        'invalid-email' => 'Format email belum benar.',
        'weak-password' => 'Password perlu minimal 6 karakter.',
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' =>
          'Email atau password tidak cocok.',
        'too-many-requests' => 'Terlalu banyak percobaan. Coba lagi nanti.',
        'network-request-failed' => 'Koneksi internet sedang bermasalah.',
        _ => exception.message ?? 'Akun belum dapat diproses.',
      };
    }
    return 'Akun belum dapat diproses. Silakan coba lagi.';
  }

  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (!email.text.contains('@') || password.text.length < 6) {
      setState(() =>
          error = 'Masukkan email yang benar dan password minimal 6 karakter.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (createMode) {
        await ParentAccountService.instance.createAccount(
          email: email.text,
          password: password.text,
          childName: widget.childName,
          prefs: widget.prefs,
        );
      } else {
        await ParentAccountService.instance.signIn(
          email: email.text,
          password: password.text,
          childName: widget.childName,
          prefs: widget.prefs,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      if (mounted) setState(() => error = messageFor(exception));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (!email.text.contains('@')) {
      setState(() => error = 'Isi email terlebih dahulu untuk reset password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ParentAccountService.instance.sendPasswordReset(email.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link reset password sudah dikirim.')),
        );
      }
    } catch (exception) {
      if (mounted) setState(() => error = messageFor(exception));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Akun Orang Tua')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              Image.asset('assets/brand/logo.png', height: 82),
              const SizedBox(height: 26),
              Text(
                createMode ? 'Buat akun orang tua' : 'Masuk sebagai orang tua',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                createMode
                    ? 'Simpan profil ${widget.childName}, progress membaca, dan pembelian.'
                    : 'Lanjutkan profil anak dan pembelian di perangkat ini.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687889)),
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Buat Akun')),
                  ButtonSegment(value: false, label: Text('Masuk')),
                ],
                selected: {createMode},
                onSelectionChanged: busy
                    ? null
                    : (selection) => setState(() {
                          createMode = selection.first;
                          error = null;
                        }),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const Key('parent-email-input'),
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email orang tua',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const Key('parent-password-input'),
                controller: password,
                obscureText: obscure,
                onSubmitted: (_) => busy ? null : submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFB64A3C))),
              ],
              const SizedBox(height: 18),
              _PrimaryButton(
                busy
                    ? 'Memproses…'
                    : createMode
                        ? 'Buat Akun Orang Tua'
                        : 'Masuk',
                busy ? () {} : submit,
              ),
              if (!createMode)
                TextButton(
                  onPressed: busy ? null : resetPassword,
                  child: const Text('Lupa password?'),
                ),
              if (createMode) ...[
                const SizedBox(height: 10),
                const Text(
                  'Kami akan mengirim email verifikasi. Cerita gratis tetap bisa dibaca tanpa akun.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF687889)),
                ),
              ],
            ],
          ),
        ),
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.name,
    required this.prefs,
    this.onNameChanged,
  });
  final String name;
  final SharedPreferences prefs;
  final Future<void> Function(String)? onNameChanged;
  @override
  Widget build(BuildContext context) {
    final featuredStory = storyOfTheDay(appCatalog.stories, DateTime.now());
    return Scaffold(
        body: Stack(fit: StackFit.expand, children: [
      Image.asset('assets/brand/home_garden_watercolor.png', fit: BoxFit.cover),
      SafeArea(child: LayoutBuilder(builder: (context, size) {
        final compact = size.maxHeight < 680;
        return Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 14, 8),
            child: Column(children: [
              Row(children: [
                Image.asset('assets/brand/logo.png',
                    width: compact ? 126 : 140,
                    height: compact ? 56 : 63,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, .22)),
                const Spacer(),
                IconButton(
                    key: const Key('parent-area'),
                    tooltip: 'Area Orang Tua',
                    onPressed: () async {
                      final selected = await Navigator.push<String>(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ParentScreen(name: name, prefs: prefs),
                        ),
                      );
                      if (selected != null && onNameChanged != null) {
                        await onNameChanged!(selected);
                      }
                    },
                    icon: const CircleAvatar(
                        backgroundColor: Color(0xFFE5F3FF),
                        child: Icon(Icons.person_rounded,
                            color: Color(0xFF4088BA))))
              ]),
              Expanded(
                  flex: 22,
                  child: Stack(children: [
                    Align(
                        alignment: const Alignment(1, -.08),
                        child: Transform.translate(
                            offset: const Offset(10, -7),
                            child: Image.asset('assets/brand/mascot_cutout.png',
                                width: math.min(size.maxWidth * .44, 190),
                                fit: BoxFit.contain))),
                    Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                            width: size.maxWidth * .6,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Halo, $name! 👋',
                                      maxLines: 2,
                                      style: TextStyle(
                                          fontSize: compact ? 23 : 27,
                                          height: 1.0,
                                          fontWeight: FontWeight.w700,
                                          color: ink)),
                                  const SizedBox(height: 7),
                                  Text(
                                      'Gembala punya cerita baru untukmu hari ini.',
                                      style: TextStyle(
                                          fontSize: compact ? 13 : 15,
                                          height: 1.1,
                                          color: ink)),
                                ]))),
                  ])),
              Expanded(
                  flex: 43,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xB3FFFDF7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xCCFFFFFF))),
                    child: Row(children: [
                      Expanded(
                          flex: 47,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Center(
                                  child: AspectRatio(
                                      aspectRatio: 1,
                                      child: contentImage(featuredStory.cover,
                                          fit: BoxFit.contain))))),
                      const SizedBox(width: 9),
                      Expanded(
                          flex: 53,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFDDEFD8),
                                        borderRadius:
                                            BorderRadius.circular(30)),
                                    child: const Text('▣  Cerita Hari Ini',
                                        style: TextStyle(
                                            color: Color(0xFF4E7757),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700))),
                                const SizedBox(height: 6),
                                Text(featuredStory.title,
                                    maxLines: 3,
                                    style: TextStyle(
                                        fontSize: compact ? 17 : 20,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                        color: ink)),
                                const SizedBox(height: 5),
                                Text(featuredStory.summary,
                                    maxLines: compact ? 2 : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: compact ? 11 : 12,
                                        height: 1.08,
                                        color: ink)),
                                const SizedBox(height: 7),
                                _MiniButton(
                                    'Baca Cerita  →',
                                    () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => StoryDetailScreen(
                                                prefs: prefs,
                                                story: featuredStory))),
                                    filled: true),
                                const SizedBox(height: 5),
                                _MiniButton(
                                    '🎧  Dibacakan Gembala',
                                    () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => ReaderScreen(
                                                prefs: prefs,
                                                readAloud: true,
                                                story: featuredStory))),
                                    filled: false),
                              ])),
                    ]),
                  )),
              const SizedBox(height: 10),
              Expanded(
                  flex: 29,
                  child: Row(children: [
                    Expanded(
                        child: _HomeTile(
                            title: 'Semua\nCerita',
                            iconAsset:
                                'assets/brand/icons/semua_cerita_watercolor.png',
                            color: const Color(0xB3FFFDF7),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        StoryListScreen(prefs: prefs))))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _HomeTile(
                            title: 'Ayat\nHafalan',
                            iconAsset:
                                'assets/brand/icons/ayat_hafalan_watercolor.png',
                            color: const Color(0xB3FFFDF7),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const VerseScreen())))),
                  ])),
              if (!compact)
                const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Bertumbuh dalam Kasih-Nya  ♥',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF829987)))),
            ]));
      })),
    ]));
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile(
      {required this.title,
      required this.iconAsset,
      required this.color,
      required this.onTap});
  final String title;
  final String iconAsset;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: color,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xCCFFFFFF))),
      child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.center,
                            child: FractionallySizedBox(
                                widthFactor: .95,
                                heightFactor: .95,
                                child: Image.asset(iconAsset,
                                    fit: BoxFit.contain,
                                    alignment: Alignment.center)))),
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 17,
                                  height: 1,
                                  fontWeight: FontWeight.w700,
                                  color: ink))),
                      const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0x22AA88EE),
                          child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: ink))
                    ]),
                  ]))));
}

class StoryListScreen extends StatefulWidget {
  const StoryListScreen({super.key, required this.prefs});
  final SharedPreferences prefs;
  @override
  State<StoryListScreen> createState() => _StoryListScreenState();
}

class _StoryListScreenState extends State<StoryListScreen> {
  Future<void> openStory(StoryBook story) async {
    if (!story.isFree) {
      final account = ParentAccountService.instance;
      if (account.currentUser == null) {
        final openLogin = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Masuk sebelum membeli'),
            content: const Text(
              'Cerita gratis tetap bisa dibaca tanpa akun. Akun orang tua diperlukan untuk pembelian premium dan pemulihan akses.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Buat Akun / Masuk'),
              ),
            ],
          ),
        );
        if (openLogin == true && mounted) {
          await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ParentAuthScreen(
                childName: widget.prefs.getString('child_name') ?? 'Anak',
                prefs: widget.prefs,
              ),
            ),
          );
        }
        return;
      }
      var entitled = false;
      try {
        entitled = await account.hasActiveEntitlement();
      } catch (_) {}
      if (!mounted) return;
      if (entitled) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                StoryDetailScreen(prefs: widget.prefs, story: story),
          ),
        );
        if (mounted) setState(() {});
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
                title: const Text('Cerita premium'),
                content: const Text(
                    'Akun orang tua sudah terhubung. Pembelian premium akan tersedia setelah produk App Store dan Google Play disiapkan.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Mengerti'))
                ],
              ));
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                StoryDetailScreen(prefs: widget.prefs, story: story)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Semua Cerita',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        const Text('Pilih ceritamu',
            style: TextStyle(
                fontSize: 25, fontWeight: FontWeight.w700, color: ink)),
        const Text('Baca sendiri atau dengarkan Gembala membacakannya.',
            style: TextStyle(color: Color(0xFF687889))),
        const SizedBox(height: 16),
        for (final story in appCatalog.stories) ...[
          Material(
              color: lavender,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => openStory(story),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox.square(
                                dimension: 108,
                                child: contentImage(story.cover))),
                        const SizedBox(width: 14),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(story.title,
                                  style: const TextStyle(
                                      fontSize: 18,
                                      height: 1.05,
                                      fontWeight: FontWeight.w700,
                                      color: ink)),
                              const SizedBox(height: 7),
                              Text(story.reference,
                                  style: const TextStyle(
                                      color: Color(0xFF687889))),
                              const SizedBox(height: 8),
                              if (widget.prefs.getBool(
                                      localReadKey(story.id, widget.prefs)) ==
                                  true)
                                const Row(children: [
                                  Icon(Icons.check_circle,
                                      color: teal, size: 18),
                                  SizedBox(width: 5),
                                  Text('Sudah dibaca',
                                      style: TextStyle(
                                          color: teal,
                                          fontWeight: FontWeight.w600))
                                ]),
                              if (!story.isFree)
                                const Row(children: [
                                  Icon(Icons.lock_outline_rounded,
                                      color: coral, size: 18),
                                  SizedBox(width: 5),
                                  Text('Premium',
                                      style: TextStyle(
                                          color: coral,
                                          fontWeight: FontWeight.w600)),
                                ]),
                            ])),
                      ])))),
          const SizedBox(height: 12),
        ],
      ]));
}

class StoryDetailScreen extends StatelessWidget {
  const StoryDetailScreen(
      {super.key, required this.prefs, this.story = StoryBook.builtIn});
  final SharedPreferences prefs;
  final StoryBook story;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const Text('Cerita Anak',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: SingleChildScrollView(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                          Center(
                              child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: SizedBox.square(
                                      dimension: math.min(
                                          MediaQuery.sizeOf(context).width - 32,
                                          MediaQuery.sizeOf(context).height *
                                              .51),
                                      child: contentImage(story.cover)))),
                          const SizedBox(height: 16),
                          Text(story.title,
                              style: const TextStyle(
                                  fontSize: 25,
                                  height: 1.05,
                                  fontWeight: FontWeight.w700,
                                  color: ink)),
                          const SizedBox(height: 5),
                          Text(story.reference,
                              style: const TextStyle(color: Color(0xFF687889))),
                          const SizedBox(height: 10),
                          Text(story.summary,
                              style: const TextStyle(fontSize: 15, color: ink)),
                        ]))),
                    const SizedBox(height: 8),
                    if (story.audio != null)
                      _PrimaryButton(
                          '🎧  Dibacakan Gembala',
                          () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ReaderScreen(
                                      prefs: prefs,
                                      readAloud: true,
                                      story: story)))),
                    const SizedBox(height: 7),
                    _PrimaryButton(
                        '▣  Baca Sendiri',
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ReaderScreen(
                                    prefs: prefs,
                                    readAloud: false,
                                    story: story))),
                        outline: true),
                  ]))));
}

class VerseScreen extends StatelessWidget {
  const VerseScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Ayat Hafalan')),
      body: appCatalog.verses.isEmpty
          ? const Center(
              child: Text('Ayat Hafalan segera hadir.',
                  style: TextStyle(fontSize: 19, color: ink)))
          : ListView(padding: const EdgeInsets.all(18), children: [
              for (final verse in appCatalog.verses)
                Card(
                    color: const Color(0xFFFFF0D4),
                    child: ListTile(
                        leading:
                            const Icon(Icons.menu_book_rounded, color: teal),
                        title: Text(verse.title),
                        subtitle: Text(verse.reference),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 16),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    VerseDetailScreen(verse: verse))))),
            ]));
}

class VerseDetailScreen extends StatefulWidget {
  const VerseDetailScreen({super.key, required this.verse});
  final VerseItem verse;
  @override
  State<VerseDetailScreen> createState() => _VerseDetailScreenState();
}

class _VerseDetailScreenState extends State<VerseDetailScreen> {
  final player = AudioPlayer();
  @override
  void dispose() {
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.verse.title)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (widget.verse.image != null)
            Center(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SizedBox.square(
                        dimension: math.min(
                            MediaQuery.sizeOf(context).width - 40, 360),
                        child: contentImage(widget.verse.image!)))),
          const SizedBox(height: 20),
          Text(widget.verse.reference,
              style: const TextStyle(color: teal, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(widget.verse.text,
              style: const TextStyle(
                  fontSize: 25,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: ink)),
          if (widget.verse.audio != null) ...[
            const SizedBox(height: 24),
            _PrimaryButton('▶  Dengarkan Ayat',
                () => player.play(contentAudioSource(widget.verse.audio!))),
          ],
        ]),
      );
}

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key, required this.name, required this.prefs});
  final String name;
  final SharedPreferences prefs;
  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  final account = ParentAccountService.instance;
  late List<String> localProfiles = [
    widget.name,
    ...?widget.prefs.getStringList('other_children')
  ];

  Future<String?> askProfileName() async {
    final input = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah profil anak'),
        content: TextField(
          controller: input,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Nama panggilan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    input.dispose();
    return value;
  }

  Future<void> addProfile() async {
    final name = await askProfileName();
    if (name == null || name.isEmpty) return;
    try {
      if (account.currentUser != null) {
        await account.addChild(name);
      } else if (!localProfiles.contains(name)) {
        setState(() => localProfiles.add(name));
        await widget.prefs.setStringList(
          'other_children',
          localProfiles.skip(1).toList(),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil belum tersimpan: $error')),
        );
      }
    }
  }

  Future<void> openAuth() async {
    final connected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ParentAuthScreen(childName: widget.name, prefs: widget.prefs),
      ),
    );
    if (connected == true && mounted) setState(() {});
  }

  Future<void> selectChild(ChildProfile profile) async {
    await widget.prefs.setString('active_child_id', profile.id);
    await widget.prefs.setString('child_name', profile.name);
    try {
      await account.pullCloudProgress(widget.prefs);
    } catch (error) {
      debugPrint('Cloud progress download unavailable: $error');
    }
    if (mounted) Navigator.pop(context, profile.name);
  }

  Future<void> syncNow() async {
    try {
      await account.ensureParentAndSync(
        childName: widget.name,
        prefs: widget.prefs,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress sudah disinkronkan.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync belum berhasil: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: account.authChanges,
        initialData: account.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Scaffold(
            appBar: AppBar(title: const Text('Area Orang Tua')),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: lavender,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Parent account',
                          style: TextStyle(
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                      const SizedBox(height: 4),
                      Text(
                        user == null
                            ? 'Belum terhubung • cerita gratis tetap tersedia'
                            : user.email ?? 'Akun orang tua terhubung',
                        style: const TextStyle(color: Color(0xFF687889)),
                      ),
                      if (user != null && !user.emailVerified) ...[
                        const SizedBox(height: 8),
                        const Text('Email belum diverifikasi.',
                            style: TextStyle(color: coral)),
                        TextButton(
                          onPressed: () async {
                            await user.sendEmailVerification();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Email verifikasi dikirim.')),
                              );
                            }
                          },
                          child: const Text('Kirim ulang verifikasi'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text('Child profile',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                const SizedBox(height: 7),
                if (user == null)
                  for (final profile in localProfiles)
                    Card(
                      color: Colors.white,
                      child: ListTile(
                        leading:
                            const Icon(Icons.child_care_rounded, color: teal),
                        title: Text(profile),
                        trailing: profile == widget.name
                            ? const Icon(Icons.check_circle, color: teal)
                            : null,
                      ),
                    )
                else
                  StreamBuilder<List<ChildProfile>>(
                    stream: account.children(),
                    builder: (context, childSnapshot) {
                      if (childSnapshot.hasError) {
                        return const Text('Profil belum dapat dimuat.');
                      }
                      if (!childSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final active =
                          widget.prefs.getString('active_child_id') ??
                              'primary';
                      return Column(
                        children: [
                          for (final profile in childSnapshot.data!)
                            Card(
                              color: Colors.white,
                              child: ListTile(
                                onTap: () => selectChild(profile),
                                leading: const Icon(Icons.child_care_rounded,
                                    color: teal),
                                title: Text(profile.name),
                                subtitle: const Text('Tersimpan di akun'),
                                trailing: profile.id == active
                                    ? const Icon(Icons.check_circle,
                                        color: teal)
                                    : null,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                TextButton.icon(
                  onPressed: addProfile,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Tambah profil anak'),
                ),
                const SizedBox(height: 16),
                const Text('Pembelian & data',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: ink)),
                if (user == null)
                  const ListTile(
                    leading: Icon(Icons.shopping_bag_outlined),
                    title: Text('Purchase entitlement'),
                    subtitle: Text('Masuk diperlukan sebelum membeli'),
                  )
                else
                  StreamBuilder<List<PurchaseEntitlement>>(
                    stream: account.entitlements(),
                    builder: (context, entitlementSnapshot) {
                      final active = entitlementSnapshot.data
                              ?.where((item) => item.active)
                              .length ??
                          0;
                      return ListTile(
                        leading: const Icon(Icons.shopping_bag_outlined),
                        title: const Text('Purchase entitlement'),
                        subtitle: Text(active == 0
                            ? 'Belum ada pembelian aktif'
                            : '$active pembelian aktif'),
                      );
                    },
                  ),
                ListTile(
                  onTap: user == null ? null : syncNow,
                  leading: const Icon(Icons.sync),
                  title: const Text('Sync'),
                  subtitle: Text(user == null
                      ? 'Data tersimpan lokal di perangkat ini'
                      : 'Profil dan progress tersimpan di cloud'),
                ),
                const SizedBox(height: 12),
                if (user == null)
                  _PrimaryButton('Buat Akun / Masuk', openAuth)
                else
                  _PrimaryButton('Keluar dari Akun', () async {
                    await account.signOut();
                    if (mounted) setState(() {});
                  }, outline: true),
              ],
            ),
          );
        },
      );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton(this.label, this.onPressed, {this.outline = false});
  final String label;
  final VoidCallback onPressed;
  final bool outline;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 48,
      child: outline
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                  foregroundColor: teal,
                  side: const BorderSide(color: teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)))
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: ink,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25))),
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600))));
}

class _MiniButton extends StatelessWidget {
  const _MiniButton(this.label, this.onPressed, {required this.filled});
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 29,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero),
              child: Text(label,
                  maxLines: 1, style: const TextStyle(fontSize: 12)))
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                  foregroundColor: ink,
                  side: const BorderSide(color: Color(0xFF8AC8DC)),
                  padding: EdgeInsets.zero),
              child: Text(label,
                  maxLines: 1, style: const TextStyle(fontSize: 10))));
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen(
      {super.key,
      required this.prefs,
      required this.readAloud,
      this.story = StoryBook.builtIn});
  final SharedPreferences prefs;
  final bool readAloud;
  final StoryBook story;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final player = AudioPlayer();
  StreamSubscription<Duration>? positionSub;
  StreamSubscription<Duration>? durationSub;
  StreamSubscription<PlayerState>? stateSub;
  StreamSubscription<void>? completeSub;
  StoryTimeline? timeline;
  int page = 0;
  int positionMs = 0;
  bool playing = false;
  bool auto = true;
  bool boundaryPause = false;
  bool sourceReady = false;
  int? pendingSeekPage;
  late final Future<void> timingLoad;

  @override
  void initState() {
    super.initState();
    timingLoad = loadTiming();
    positionSub = player.onPositionChanged.listen(onPosition);
    durationSub = player.onDurationChanged.listen((duration) {
      if (mounted && timeline == null && duration.inMilliseconds > 0) {
        setState(() => timeline =
            StoryTimeline(duration.inMilliseconds, pages: widget.story.pages));
      }
    });
    stateSub = player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => playing = state == PlayerState.playing);
    });
    completeSub = player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          playing = false;
          page = widget.story.pages.length - 1;
        });
        markRead();
      }
    });
    if (widget.readAloud) {
      WidgetsBinding.instance.addPostFrameCallback((_) => startAudio());
    }
  }

  Future<void> loadTiming() async {
    try {
      if (widget.story.timingAsset == null) return;
      final timingPath = widget.story.timingAsset!;
      final contents = _isRemotePath(timingPath)
          ? (await http.get(Uri.parse(timingPath))).body
          : await rootBundle.loadString(timingPath);
      final audited = StoryTimeline.fromMap(jsonDecode(contents),
          pages: widget.story.pages);
      if (mounted) setState(() => timeline = audited);
    } catch (error) {
      debugPrint('Audited story timing unavailable: $error');
    }
  }

  void onPosition(Duration position) {
    if (!mounted || timeline == null) return;
    final ms = position.inMilliseconds;
    // A seek can emit the old audio position after the button changed page.
    // Ignore those stale events until playback reaches the requested page.
    if (pendingSeekPage != null) {
      if (timeline!.pageAt(ms) != pendingSeekPage) return;
      pendingSeekPage = null;
    }
    if (widget.readAloud &&
        !auto &&
        !boundaryPause &&
        page < widget.story.pages.length - 1 &&
        ms >= timeline!.starts[page + 1]) {
      boundaryPause = true;
      unawaited(player.pause());
      unawaited(
          player.seek(Duration(milliseconds: timeline!.starts[page + 1] - 1)));
      setState(() => positionMs = timeline!.starts[page + 1] - 1);
      boundaryPause = false;
      return;
    }
    setState(() {
      positionMs = ms;
      if (auto && widget.readAloud) page = timeline!.pageAt(ms);
    });
  }

  Future<void> startAudio() async {
    try {
      await timingLoad;
      if (!sourceReady) {
        final startingPage = page;
        await player.setReleaseMode(ReleaseMode.stop);
        // Match Dunia Pinta: start the source at the selected page position.
        await player.play(
          contentAudioSource(widget.story.audio!),
          position: Duration(milliseconds: timeline?.starts[startingPage] ?? 0),
        );
        sourceReady = true;
        if (page != startingPage && timeline != null) {
          await player.seek(Duration(milliseconds: timeline!.starts[page]));
        }
      } else {
        await player.resume();
      }
      final duration = await player.getDuration();
      if (duration != null &&
          duration.inMilliseconds > 0 &&
          mounted &&
          timeline == null) {
        setState(() => timeline =
            StoryTimeline(duration.inMilliseconds, pages: widget.story.pages));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Audio belum bisa diputar: $error')));
      }
    }
  }

  Future<void> toggleAudio() async {
    if (playing) {
      await player.pause();
    } else if (!sourceReady) {
      await startAudio();
    } else {
      await player.resume();
    }
  }

  Future<void> goTo(int next) async {
    if (next >= widget.story.pages.length) {
      await markRead();
      if (mounted) Navigator.pop(context);
      return;
    }
    if (next < 0) return;
    if (widget.readAloud && timeline != null) {
      pendingSeekPage = next;
    }
    setState(() {
      page = next;
      positionMs = timeline?.starts[next] ?? 0;
    });
    if (widget.readAloud && timeline != null && sourceReady) {
      // The preview server supports byte ranges, so this seeks the existing
      // stream without reloading the MP3 or restarting from zero.
      await player.seek(Duration(milliseconds: timeline!.starts[next]));
    }
  }

  Future<void> markRead() async {
    await widget.prefs.setBool(
      localReadKey(widget.story.id, widget.prefs),
      true,
    );
    try {
      await ParentAccountService.instance.markStoryRead(
        widget.story.id,
        widget.prefs,
        widget.story.pages.length - 1,
      );
    } catch (error) {
      debugPrint('Cloud reading progress sync unavailable: $error');
    }
  }

  @override
  void dispose() {
    unawaited(positionSub?.cancel());
    unawaited(durationSub?.cancel());
    unawaited(stateSub?.cancel());
    unawaited(completeSub?.cancel());
    unawaited(player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: Text(widget.story.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          actions: [
            Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Center(
                    child: Text('${page + 1} dari ${widget.story.pages.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700))))
          ]),
      body: SafeArea(child: LayoutBuilder(builder: (context, size) {
        final imageSize = math.min(size.maxWidth - 28, size.maxHeight * .51);
        final active =
            widget.readAloud ? timeline?.wordAt(page, positionMs) ?? -1 : -1;
        return Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Column(children: [
              Center(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(23),
                      child: SizedBox.square(
                          dimension: imageSize,
                          child:
                              contentImage(widget.story.pages[page].image)))),
              const SizedBox(height: 10),
              Expanded(
                  child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFECDABD))),
                      child: Center(
                          child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: SizedBox(
                                  width: size.maxWidth - 65,
                                  child: RichText(
                                      textAlign: TextAlign.center,
                                      text: TextSpan(
                                          style: const TextStyle(
                                              fontFamily: 'Fredoka',
                                              fontSize: 22,
                                              height: 1.42,
                                              fontWeight: FontWeight.w600,
                                              color: ink),
                                          children: [
                                            for (var i = 0;
                                                i <
                                                    widget.story.pages[page]
                                                        .words.length;
                                                i++)
                                              TextSpan(
                                                  text:
                                                      '${widget.story.pages[page].words[i]}${i == widget.story.pages[page].words.length - 1 ? '' : ' '}',
                                                  style: i == active
                                                      ? const TextStyle(
                                                          color:
                                                              Color(0xFFCE693F),
                                                          backgroundColor:
                                                              Color(0xFFFFE3A0),
                                                          fontWeight:
                                                              FontWeight.w700)
                                                      : null),
                                          ]))))))),
              const SizedBox(height: 11),
              LinearProgressIndicator(
                  value: (page + 1) / widget.story.pages.length,
                  minHeight: 7,
                  borderRadius: BorderRadius.circular(8),
                  color: teal,
                  backgroundColor: lavender),
              const SizedBox(height: 8),
              Row(children: [
                IconButton.filledTonal(
                    onPressed: page == 0 ? null : () => goTo(page - 1),
                    icon: const Icon(Icons.arrow_back_rounded)),
                const Spacer(),
                if (widget.readAloud) ...[
                  FilledButton.icon(
                      onPressed: toggleAudio,
                      style: FilledButton.styleFrom(
                          backgroundColor: gold, foregroundColor: ink),
                      icon: Icon(playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                      label: Text(playing ? 'Jeda' : 'Dengarkan')),
                  const SizedBox(width: 5),
                  FilterChip(
                      key: const Key('auto-toggle'),
                      selected: auto,
                      onSelected: (value) => setState(() => auto = value),
                      showCheckmark: false,
                      avatar: const Icon(Icons.auto_mode_rounded, size: 15),
                      label: const Text('Otomatis',
                          style: TextStyle(fontSize: 11))),
                ] else
                  const Text('Baca sendiri'),
                const Spacer(),
                IconButton.filled(
                    onPressed: () => goTo(page + 1),
                    icon: Icon(page == widget.story.pages.length - 1
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded)),
              ]),
            ]));
      })));
}
