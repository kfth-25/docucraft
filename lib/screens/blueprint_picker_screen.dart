// DocuCraft Flutter — Blueprint Picker Screen (Sprint 12)
//
// Halaman modal Material 3 (full-screen di mobile) yang menampilkan daftar
// blueprint DocuCraft tersimpan. Kotak pencarian + chip tag (All / Forked /
// Recent), aksi per baris Open / Fork / Delete.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deck_blueprint.dart';
import '../providers/blueprint_picker_provider.dart';

class BlueprintPickerScreen extends StatefulWidget {
  final void Function(DeckBlueprint blueprint, {required bool isFork}) onPick;
  const BlueprintPickerScreen({super.key, required this.onPick});

  /// Convenience: push as a full-screen modal route.
  static Future<void> show(
    BuildContext context, {
    required void Function(DeckBlueprint, {required bool isFork}) onPick,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlueprintPickerScreen(onPick: onPick),
      ),
    );
  }

  @override
  State<BlueprintPickerScreen> createState() => _BlueprintPickerScreenState();
}

class _BlueprintPickerScreenState extends State<BlueprintPickerScreen> {
  final _searchController = TextEditingController();
  String? _pendingDeleteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BlueprintPickerProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved decks'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<BlueprintPickerProvider>().refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<BlueprintPickerProvider>(
        builder: (context, p, _) {
          return Column(
            children: [
              if (p.hasBlueprints) _buildSearchBar(p),
              Expanded(child: _buildBody(p)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BlueprintPickerProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search by name or topic…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: p.setQuery,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (final t in BlueprintTag.values)
                ChoiceChip(
                  label: Text(_label(t, p)),
                  selected: p.tag == t,
                  onSelected: (_) => p.setTag(t),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(BlueprintTag t, BlueprintPickerProvider p) {
    switch (t) {
      case BlueprintTag.all:
        return 'All (${p.blueprints.length})';
      case BlueprintTag.forked:
        return 'Forked (${p.forkedCount})';
      case BlueprintTag.recent:
        return 'Recent (${p.blueprints.length < BlueprintPickerProvider.recentLimit ? p.blueprints.length : BlueprintPickerProvider.recentLimit})';
    }
  }

  Widget _buildBody(BlueprintPickerProvider p) {
    if (p.loading && p.blueprints.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(p.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    if (!p.hasBlueprints) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No saved decks yet.\nGenerate a deck in DocuCraft mode to save it here.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (!p.hasMatches) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No decks match your filter.'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  p.clearFilter();
                },
                child: const Text('Clear filter'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: p.visibleBlueprints.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final bp = p.visibleBlueprints[i];
        return _buildRow(bp, p);
      },
    );
  }

  Widget _buildRow(DeckBlueprint bp, BlueprintPickerProvider p) {
    return ListTile(
      title: Text(bp.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bp.topic.isNotEmpty && bp.topic != bp.name)
            Text(bp.topic, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (bp.forkedFrom != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Forked from ${bp.forkedFrom}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            _formatMeta(bp),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
      trailing: _pendingDeleteId == bp.id
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    if (await p.delete(bp.id)) {
                      setState(() => _pendingDeleteId = null);
                    }
                  },
                  child: const Text('Delete'),
                ),
                TextButton(
                  onPressed: () => setState(() => _pendingDeleteId = null),
                  child: const Text('Cancel'),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  tooltip: 'Open',
                  onPressed: () => widget.onPick(bp, isFork: false),
                ),
                IconButton(
                  icon: const Icon(Icons.call_split),
                  tooltip: 'Fork',
                  onPressed: () => widget.onPick(bp, isFork: true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: () => setState(() => _pendingDeleteId = bp.id),
                ),
              ],
            ),
    );
  }

  String _formatMeta(DeckBlueprint bp) {
    final parts = <String>[];
    if (bp.pageCount != null) parts.add('${bp.pageCount} pages');
    if (bp.createdAt.isNotEmpty) {
      final d = DateTime.tryParse(bp.createdAt);
      if (d != null) {
        parts.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
      }
    }
    return parts.join(' • ');
  }
}
