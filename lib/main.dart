import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'models/folder.dart';
import 'models/card_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CardOrganizerApp());
}

class CardOrganizerApp extends StatelessWidget {
  const CardOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Card Organizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const FolderListScreen(),
    );
  }
}

class FolderListScreen extends StatefulWidget {
  const FolderListScreen({super.key});

  @override
  State<FolderListScreen> createState() => _FolderListScreenState();
}

class _FolderListScreenState extends State<FolderListScreen> {
  late Future<List<Folder>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getFolders();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = DatabaseHelper.instance.getFolders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      body: FutureBuilder<List<Folder>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final folders = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: folders.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final f = folders[i];
                return FutureBuilder(
                  future: Future.wait([
                    DatabaseHelper.instance.cardCountInFolder(f.id!),
                    DatabaseHelper.instance.firstCardInFolder(f.id!),
                  ]),
                  builder: (context, AsyncSnapshot<List<Object?>> ss) {
                    final count = (ss.data?[0] as int?) ?? 0;
                    final first = (ss.data?[1] as CardModel?);
                    return ListTile(
                      leading: first?.imageUrl != null
                          ? CircleAvatar(
                        backgroundImage: NetworkImage(first!.imageUrl!),
                      )
                          : const CircleAvatar(child: Icon(Icons.folder)),
                      title: Text(f.name),
                      subtitle: Text('$count card(s)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardListScreen(folder: f),
                        ),
                      ).then((_) => _refresh()),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class CardListScreen extends StatefulWidget {
  final Folder folder;
  const CardListScreen({super.key, required this.folder});

  @override
  State<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends State<CardListScreen> {
  late Future<List<CardModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = DatabaseHelper.instance.getCardsByFolder(widget.folder.id!);
  }

  Future<void> _reload() async {
    setState(() {
      _future = DatabaseHelper.instance.getCardsByFolder(widget.folder.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.folder.name)),
      body: FutureBuilder<List<CardModel>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final cards = snap.data!;
          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, i) {
              final c = cards[i];
              return ListTile(
                leading: c.imageUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(c.imageUrl!))
                    : const CircleAvatar(child: Icon(Icons.image_not_supported)),
                title: Text('${c.name} of ${c.suit}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  onPressed: () async {
                    await DatabaseHelper.instance.deleteCard(c.id!);
                    final left = await DatabaseHelper.instance
                        .cardCountInFolder(widget.folder.id!);
                    if (left < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Warning: fewer than 3 cards remain.')),
                      );
                    }
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final newCard = await showDialog<CardModel?>(
            context: context,
            builder: (_) => _AddCardDialog(folderName: widget.folder.name, folderId: widget.folder.id!),
          );
          if (newCard != null) {
            try {
              await DatabaseHelper.instance.addCard(newCard);
              _reload();
            } on StateError catch (e) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Folder Full'),
                  content: Text(e.message ?? 'This folder is full (max 6).'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Card'),
      ),
    );
  }
}

class _AddCardDialog extends StatefulWidget {
  final String folderName;
  final int folderId;
  const _AddCardDialog({required this.folderName, required this.folderId});

  @override
  State<_AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<_AddCardDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rankCtrl = TextEditingController();   // 1-13 or A,2..K
  final _imageCtrl = TextEditingController();  // optional URL

  @override
  void dispose() {
    _rankCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  String _normalizeRank(String v) {
    final t = v.trim().toUpperCase();
    if (t == '1') return 'A';
    if (t == '11') return 'J';
    if (t == '12') return 'Q';
    if (t == '13') return 'K';
    return t; // A,2..10,J,Q,K
  }

  String _defaultImageUrl(String suit, String rank) {
    // Simple Wikimedia pattern; works for A, J, Q, K and 2..10
    final suitLower = suit.toLowerCase();
    final rankName = {
      'A':'A', 'J':'J', 'Q':'Q', 'K':'K',
      '2':'2', '3':'3', '4':'4', '5':'5',
      '6':'6', '7':'7', '8':'8', '9':'9', '10':'10'
    }[rank]!;
    final suitWord = suitLower.substring(0,1).toUpperCase()+suitLower.substring(1);
    return 'https://upload.wikimedia.org/wikipedia/commons/${{
      'hearts':'5/57','spades':'2/25','diamonds':'d/d3','clubs':'a/ab'
    }[suitLower]}/Playing_card_${suitLower}_${rankName}.svg';
    // Note: Wikimedia uses SVG; Android renders SVG via network fine in WebView,
    // but Image.network shows SVG as bytes not rasterized. For class purposes, keep URL;
    // or use PNG URLs if you prefer another source.
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add to ${widget.folderName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _rankCtrl,
              decoration: const InputDecoration(
                labelText: 'Rank (A,2..10,J,Q,K or 1..13)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter a rank';
                final t = v.trim().toUpperCase();
                const allowed = {'A','2','3','4','5','6','7','8','9','10','J','Q','K','1','11','12','13'};
                if (!allowed.contains(t)) return 'Invalid rank';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _imageCtrl,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final rank = _normalizeRank(_rankCtrl.text);
            final url = _imageCtrl.text.trim().isEmpty
                ? _defaultImageUrl(widget.folderName, rank)
                : _imageCtrl.text.trim();

            final card = CardModel(
              name: rank,
              suit: widget.folderName,
              folderId: widget.folderId,
              imageUrl: url,
            );
            Navigator.pop(context, card);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
