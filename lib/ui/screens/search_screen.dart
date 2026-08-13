import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/media_item.dart';
import '../../state/app_controller.dart';
import '../widgets/poster_card.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<MediaItem> _results = [];
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onChanged(String value) async {
    final c = context.read<AppController>();

    // 1) Commande secrète : totalement transparente. On ne montre AUCUN
    //    indice de son existence ailleurs dans l'app ; ici on se contente de
    //    vider le champ et d'appliquer le changement d'accès.
    final handled = await c.handleSecretCommand(value);
    if (handled) {
      _ctrl.clear();
      setState(() {
        _query = '';
        _results = [];
      });
      _discreetConfirm(c.adultUnlocked);
      return;
    }

    // 2) Recherche normale (débounce).
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      setState(() {
        _query = value.trim();
        _results = _query.isEmpty ? [] : c.search(_query);
      });
    });
  }

  /// Confirmation minimaliste, sans texte explicite, visible seulement par
  /// celui qui vient de taper la commande.
  void _discreetConfirm(bool unlocked) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1200),
          width: 120,
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(unlocked ? Icons.lock_open : Icons.lock,
                  size: 18, color: Colors.white70),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _ctrl,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'Rechercher un film, une série, une chaîne…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() {
                            _query = '';
                            _results = [];
                          });
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const _SearchHint()
                : _results.isEmpty
                    ? const Center(
                        child: Text('Aucun résultat',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 130,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _results.length,
                        itemBuilder: (context, i) {
                          final item = _results[i];
                          return PosterCard(
                            item: item,
                            width: 130,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => DetailScreen(item: item)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 64, color: Colors.white24),
          SizedBox(height: 12),
          Text('Cherche parmi tes films, séries et chaînes',
              style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
