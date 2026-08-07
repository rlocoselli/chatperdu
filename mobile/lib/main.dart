import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
    final message = await showDialog<String>(
        context: context,
        builder: (dialog) => AlertDialog(
                title: Text('Une information sur ${report.name}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: controller, maxLines: 3),
            const SizedBox(height: 12),
            TextField(
              controller: place,
              decoration: const InputDecoration(labelText: 'Lieu')),
            const SizedBox(height: 12),
            TextField(
              controller: contact,
              decoration:
                const InputDecoration(labelText: 'Contact (facultatif)'))
          ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(dialog, controller.text),
                      child: const Text('Envoyer'))
                ]));
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
                  child: FilledButton.icon(
                      onPressed: _login,
                      icon: const Icon(Icons.login),
                      label: const Text('Se connecter')));
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
    await showDialog(
        context: context,
        builder: (dialog) => AlertDialog(
                title: const Text('Se connecter'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: email,
                      decoration: const InputDecoration(labelText: 'Email')),
                  TextField(
                      controller: password,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Mot de passe'))
                ]),
                actions: [
                  FilledButton(
                      onPressed: () async {
                        await widget.api.authenticate('login',
                            email: email.text, password: password.text);
                        if (dialog.mounted) Navigator.pop(dialog);
                      },
                      child: const Text('Continuer'))
                ]));
    setState(() => future = widget.api.notifications());
  }
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
