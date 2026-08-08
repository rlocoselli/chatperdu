import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/report.dart';
import 'services/ad_service.dart';
import 'services/api_service.dart';
import 'widgets/ad_banner.dart';

const green = Color(0xff173c35);
const orange = Color(0xffef6b43);
const cream = Color(0xfff7f4ed);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChatPerduApp());
}

class ChatPerduApp extends StatefulWidget {
  const ChatPerduApp({super.key});
  @override
  State<ChatPerduApp> createState() => _ChatPerduAppState();
}

class _ChatPerduAppState extends State<ChatPerduApp> {
  final ads = AdService();
  @override
  void initState() {
    super.initState();
    ads.requestConsentAndStart();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Chat Perdu',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: green, primary: green, secondary: orange),
          textTheme: GoogleFonts.dmSansTextTheme(),
          scaffoldBackgroundColor: const Color(0xfffcfcf9),
          useMaterial3: true,
        ),
        home: Home(ads: ads),
      );
}

class Home extends StatefulWidget {
  final AdService ads;
  const Home({super.key, required this.ads});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final api = ApiService();
  final search = TextEditingController();
  String filter = 'Tous';
  late Future<List<Report>> future;

  @override
  void initState() {
    super.initState();
    future = api.reports();
  }

  void reload() =>
      setState(() => future = api.reports(query: search.text, status: filter));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AdBanner(ads: widget.ads),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Publier'),
        onPressed: () async {
          final made = await Navigator.push<bool>(context,
              MaterialPageRoute(builder: (_) => PublishPage(api: api)));
          if (made == true) {
            widget.ads.showAtNaturalTransition();
            reload();
          }
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async => reload(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 315,
              pinned: true,
              backgroundColor: green,
              foregroundColor: Colors.white,
              title: const Text('chatperdu',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotificationsPage(api: api))),
                ),
                IconButton(
                  icon: const Icon(Icons.shield_outlined),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => PrivacyPage(ads: widget.ads))),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/chat-perdu-hero.png', fit: BoxFit.cover),
                  Container(
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xdd102f28), Color(0x22102f28)]))),
                  const Positioned(
                      left: 22,
                      right: 22,
                      bottom: 35,
                      child: Text('Chaque moustache\nmérite de rentrer.',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'serif',
                              fontSize: 36,
                              height: 1.05,
                              fontWeight: FontWeight.bold))),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SearchBar(
                          controller: search,
                          onSubmitted: (_) => reload(),
                          hintText: 'Ville, quartier ou code postal',
                          leading: const Icon(Icons.search),
                          trailing: [
                            IconButton(
                                onPressed: reload,
                                icon: const Icon(Icons.arrow_forward))
                          ]),
                      const SizedBox(height: 20),
                      const Text('PRÈS DE CHEZ VOUS',
                          style: TextStyle(
                              color: orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.4)),
                      const Text('Ils ont besoin de vos yeux',
                          style: TextStyle(
                              color: green,
                              fontFamily: 'serif',
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 8,
                          children: ['Tous', 'Perdu', 'Aperçu', 'Retrouvé']
                              .map((value) => ChoiceChip(
                                  label: Text(value),
                                  selected: filter == value,
                                  onSelected: (_) {
                                    filter = value;
                                    reload();
                                  }))
                              .toList()),
                    ]),
              ),
            ),
            FutureBuilder<List<Report>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return SliverFillRemaining(
                      child: Center(
                          child: TextButton.icon(
                              onPressed: reload,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'))));
                if (!snapshot.hasData)
                  return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()));
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 5, 18, 100),
                  sliver: SliverList.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (_, index) => ReportCard(
                        report: snapshot.data![index],
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailPage(
                                    report: snapshot.data![index], api: api)))),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReportCard extends StatelessWidget {
  final Report report;
  final VoidCallback onTap;
  const ReportCard({super.key, required this.report, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xffe4e7e1)),
            borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          child: Row(children: [
            SizedBox(
                width: 125,
                height: 130,
                child: report.image.isEmpty
                    ? Container(
                        color: cream,
                        child: const Icon(Icons.pets, size: 42, color: orange))
                    : Image.network(report.image, fit: BoxFit.cover)),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(report.status.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: orange,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(report.name,
                              style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 23,
                                  fontWeight: FontWeight.bold,
                                  color: green)),
                          const SizedBox(height: 7),
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 16, color: orange),
                            Expanded(
                                child: Text(report.place,
                                    maxLines: 2,
                                    style: const TextStyle(fontSize: 12)))
                          ]),
                        ]))),
          ]),
        ),
      );
}

class DetailPage extends StatelessWidget {
  final Report report;
  final ApiService api;
  const DetailPage({super.key, required this.report, required this.api});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: ListView(children: [
          if (report.image.isNotEmpty)
            Image.network(report.image, height: 290, fit: BoxFit.cover),
          Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.status.toUpperCase(),
                        style: const TextStyle(
                            color: orange, fontWeight: FontWeight.bold)),
                    Text(report.name,
                        style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 38,
                            color: green,
                            fontWeight: FontWeight.bold)),
                    Text('📍 ${report.place}'),
                    const SizedBox(height: 25),
                    Text(report.description,
                        style: const TextStyle(height: 1.6)),
                    const SizedBox(height: 30),
                    FilledButton.icon(
                        onPressed: () => _inform(context),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text("J'ai une information")),
                  ])),
        ]),
      );
  Future<void> _inform(BuildContext context) async {
    final controller = TextEditingController();
    final place = TextEditingController();
    final contact = TextEditingController();
    final message = await _showFancyFormDialog(
        context,
        title: 'Une information sur ${report.name}',
        subtitle: 'Chaque détail peut accélérer les retrouvailles.',
        primaryLabel: 'Envoyer',
        fields: [
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Votre message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: place,
            decoration: const InputDecoration(
                labelText: 'Lieu', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contact,
            decoration: const InputDecoration(
                labelText: 'Contact (facultatif)', border: OutlineInputBorder()),
          ),
        ],
        valueBuilder: () => controller.text,
        canSubmit: () => controller.text.trim().length > 2);
    if (message != null && message.length > 2)
      await api.sighting(report.id, message,
          place: place.text, contact: contact.text);
  }
}

class PublishPage extends StatefulWidget {
  final ApiService api;
  const PublishPage({super.key, required this.api});
  @override
  State<PublishPage> createState() => _PublishPageState();
}

class _PublishPageState extends State<PublishPage> {
  final name = TextEditingController(),
      place = TextEditingController(),
      description = TextEditingController();
  final picker = ImagePicker();
  bool busy = false;
  XFile? image;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Nouveau signalement')),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const Text('Parlez-nous de lui',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 30,
                color: green,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
            controller: name,
            decoration: const InputDecoration(
                labelText: 'Son prénom', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(
            controller: place,
            decoration: const InputDecoration(
                labelText: 'Dernier lieu connu', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        TextField(
            controller: description,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Description', border: OutlineInputBorder())),
        const SizedBox(height: 14),
        OutlinedButton.icon(
            onPressed: busy
                ? null
                : () async {
                    final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 88,
                        maxWidth: 1800);
                    if (picked != null && mounted) {
                      setState(() => image = picked);
                    }
                },
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(image == null ? 'Ajouter une photo' : image!.name)),
        if (image != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(File(image!.path), height: 180, fit: BoxFit.cover)),
        ],
        const SizedBox(height: 20),
        FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (name.text.isEmpty || place.text.isEmpty) return;
                    setState(() => busy = true);
                    try {
                      final imageUrl =
                          image == null ? '' : await widget.api.uploadImage(image!.path);
                      await widget.api.publish({
                        'name': name.text,
                        'place': place.text,
                        'description': description.text,
                        'status': 'Perdu',
                        'image_url': imageUrl
                      });
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                    if (context.mounted) Navigator.pop(context, true);
                  },
            child: Text(busy ? 'Publication…' : 'Publier gratuitement')),
      ]));
}

class NotificationsPage extends StatefulWidget {
  final ApiService api;
  const NotificationsPage({super.key, required this.api});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    future = widget.api.notifications();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (_, snapshot) {
            if (snapshot.hasError)
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                FilledButton.icon(
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: const Text('Se connecter')),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loginWithGoogle,
                  icon: Image.network(
                    'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata),
                  ),
                  label: const Text('Continuer avec Google')),
                ]));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.data!.isEmpty)
              return const Center(
                  child: Text('Aucune notification pour le moment.'));
            return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.length,
                itemBuilder: (_, i) {
                  final item = snapshot.data![i];
                  return Card(
                      child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.pets)),
                          title: Text(item['title']),
                          subtitle: Text(item['message'])));
                });
          }));
  Future<void> _login() async {
    final email = TextEditingController(), password = TextEditingController();
    final payload = await _showFancyFormDialog<Map<String, String>>(
      context,
      title: 'Connexion propriétaire',
      subtitle: 'Retrouvez vos notifications privées.',
      primaryLabel: 'Continuer',
      fields: [
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(
                labelText: 'Mot de passe', border: OutlineInputBorder()))
      ],
      valueBuilder: () => {
        'email': email.text.trim(),
        'password': password.text,
      },
      canSubmit: () => email.text.trim().contains('@') && password.text.isNotEmpty,
    );
    if (payload != null) {
      await widget.api.authenticate('login',
          email: payload['email']!, password: payload['password']!);
    }
    setState(() => future = widget.api.notifications());
  }

  Future<void> _loginWithGoogle() async {
    final url = widget.api.audelaGoogleLoginUri();
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => _GoogleOAuthPage(startUrl: url)),
    );
    if (token != null && token.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      await p.setString('audela-token', token);
    }
    if (mounted) setState(() => future = widget.api.notifications());
  }
}

Future<T?> _showFancyFormDialog<T>(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String primaryLabel,
  required List<Widget> fields,
  required T Function() valueBuilder,
  required bool Function() canSubmit,
}) {
  return showDialog<T>(
      context: context,
      barrierColor: const Color(0xcc102f28),
      builder: (dialog) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xfff8faf7), Color(0xfff0f5f3)]),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x40112e28),
                      blurRadius: 34,
                      offset: Offset(0, 18))
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: StatefulBuilder(builder: (ctx, setLocalState) {
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                            color: orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.pets, color: orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    color: green,
                                    fontFamily: 'serif',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: const TextStyle(
                                    color: Color(0xff55766d),
                                    fontSize: 13,
                                    height: 1.4))
                          ])),
                      IconButton(
                          onPressed: () => Navigator.pop(dialog),
                          icon: const Icon(Icons.close))
                    ]),
                    const SizedBox(height: 14),
                    ...fields,
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialog),
                              child: const Text('Annuler'))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: FilledButton(
                              style: FilledButton.styleFrom(backgroundColor: orange),
                              onPressed: canSubmit()
                                  ? () => Navigator.pop(dialog, valueBuilder())
                                  : null,
                              child: Text(primaryLabel)))
                    ])
                  ]);
                }),
              ),
            ),
          ));
}

class PrivacyPage extends StatelessWidget {
  final AdService ads;
  const PrivacyPage({super.key, required this.ads});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Vie privée')),
      body: ListView(padding: const EdgeInsets.all(22), children: [
        const Icon(Icons.shield_outlined, size: 55, color: green),
        const SizedBox(height: 15),
        const Text('Vos données restent sous votre contrôle',
            style: TextStyle(
                fontFamily: 'serif',
                fontSize: 28,
                color: green,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        const Text(
            "La position n'est utilisée qu'à votre demande et n'est jamais suivie en arrière-plan.",
            style: TextStyle(height: 1.6)),
        ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Choix publicitaires'),
            onTap: ads.showPrivacyOptions),
      ]));
}

class _GoogleOAuthPage extends StatefulWidget {
  final Uri startUrl;
  const _GoogleOAuthPage({required this.startUrl});
  @override
  State<_GoogleOAuthPage> createState() => _GoogleOAuthPageState();
}

class _GoogleOAuthPageState extends State<_GoogleOAuthPage> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.navigate;
          final fragment = uri.fragment;
          if (fragment.contains('token=')) {
            final token = Uri.splitQueryString(fragment)['token'] ?? '';
            if (token.isNotEmpty) {
              Navigator.pop(context, token);
              return NavigationDecision.prevent;
            }
          }
          if (fragment.contains('google_error=')) {
            Navigator.pop(context, null);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(widget.startUrl);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Connexion Google'),
          backgroundColor: green,
          foregroundColor: Colors.white,
          leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context, null)),
        ),
        body: WebViewWidget(controller: _controller),
      );
}
