import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../providers/telemetry_provider.dart';
import '../../models/telemetry_item.dart';

class SearchControl extends StatefulWidget {
  const SearchControl({super.key});

  @override
  State<SearchControl> createState() => _SearchControlState();
}

class _SearchControlState extends State<SearchControl> {
  final _searchController = TextEditingController();
  final _presetController = TextEditingController();
  List<TelemetryItem> _results = [];
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _presetController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final telemetry = context.read<TelemetryProvider>();
      telemetry.setQuery(query);
      if (query.trim().isEmpty) {
        setState(() => _results = []);
        return;
      }
      setState(() => _results = telemetry.search(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text("Search", style: TextStyle(fontWeight: FontWeight.bold)),
            Consumer<TelemetryProvider>(
              builder: (context, telemetry, _) {
                final chips = _buildActiveChips(telemetry);
                if (chips.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: chips,
                  ),
                );
              },
            ),
            Consumer<TelemetryProvider>(
              builder: (context, telemetry, _) {
                if (telemetry.items.isNotEmpty) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text("Load telemetry to enable search"),
                );
              },
            ),
            Consumer<TelemetryProvider>(
              builder: (context, telemetry, _) {
                final categories = telemetry.categories();
                final levels = telemetry.levels();
                final actions = telemetry.actions();
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: telemetry.categoryFilter ?? 'all',
                      decoration: const InputDecoration(labelText: "Category"),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text("All Categories")),
                        ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                      ],
                      onChanged: (value) => telemetry.setCategoryFilter(value == 'all' ? null : value),
                    ),
                    DropdownButtonFormField<String>(
                      value: telemetry.levelFilter ?? 'all',
                      decoration: const InputDecoration(labelText: "Level"),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text("All Levels")),
                        ...levels.map((l) => DropdownMenuItem(value: l, child: Text(l))),
                      ],
                      onChanged: (value) => telemetry.setLevelFilter(value == 'all' ? null : value),
                    ),
                    DropdownButtonFormField<String>(
                      value: telemetry.actionFilter ?? 'all',
                      decoration: const InputDecoration(labelText: "Action"),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text("All Actions")),
                        ...actions.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                      ],
                      onChanged: (value) => telemetry.setActionFilter(value == 'all' ? null : value),
                    ),
                    DropdownButtonFormField<String>(
                      value: telemetry.pinFilter,
                      decoration: const InputDecoration(labelText: "Pin Visibility"),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text("All")),
                        DropdownMenuItem(value: 'visible', child: Text("Visible Only")),
                        DropdownMenuItem(value: 'hidden', child: Text("Hidden Only")),
                      ],
                      onChanged: (value) => telemetry.setPinFilter(value ?? 'all'),
                    ),
                    DropdownButtonFormField<String>(
                      value: telemetry.sortMode,
                      decoration: const InputDecoration(labelText: "Sort By"),
                      items: const [
                        DropdownMenuItem(value: 'title', child: Text("Title")),
                        DropdownMenuItem(value: 'id', child: Text("ID")),
                        DropdownMenuItem(value: 'category', child: Text("Category")),
                        DropdownMenuItem(value: 'level', child: Text("Level")),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        telemetry.setSortMode(value);
                      },
                    ),
                    SwitchListTile(
                      title: const Text("Only Items with Notes"),
                      value: telemetry.requireAbout,
                      onChanged: telemetry.setRequireAbout,
                      dense: true,
                    ),
                    SwitchListTile(
                      title: const Text("Fuzzy Search"),
                      value: telemetry.fuzzySearchEnabled,
                      onChanged: telemetry.setFuzzySearchEnabled,
                      dense: true,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Filtered: ${telemetry.filteredItems.length}"),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {
                          telemetry.setCategoryFilter(null);
                          telemetry.setLevelFilter(null);
                          telemetry.setActionFilter(null);
                          telemetry.setPinFilter('all');
                          telemetry.setRequireAbout(false);
                          telemetry.setSortMode('title');
                          telemetry.setQuery('');
                          _searchController.clear();
                          setState(() => _results = []);
                        },
                        child: const Text("Clear Filters"),
                      ),
                    ),
                  ],
                );
              },
            ),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search...",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _performSearch(_searchController.text),
                ),
              ),
              onSubmitted: _performSearch,
              onChanged: _performSearch,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _presetController,
                    decoration: const InputDecoration(
                      labelText: "Save search preset",
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ElevatedButton(
                  onPressed: () {
                    final name = _presetController.text.trim();
                    if (name.isEmpty) return;
                    context.read<TelemetryProvider>().savePreset(name);
                    _presetController.clear();
                  },
                  child: const Text("Save"),
                ),
              ],
            ),
            if (_results.isNotEmpty)
              Container(
                height: 200,
                color: Colors.white,
                child: Builder(
                  builder: (context) {
                    final telemetry = context.watch<TelemetryProvider>();
                    return ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          visualDensity: VisualDensity.comfortable,
                          title: Text(item.title),
                          subtitle: Text("${item.id} - ${item.category} - ${item.level}"),
                          dense: true,
                          trailing: Checkbox(
                            value: telemetry.selectedIds.contains(item.id),
                            onChanged: (_) {
                              telemetry.toggleSelection(item);
                            },
                          ),
                          onTap: () {
                            context.read<TelemetryProvider>().selectItem(item);
                            context.read<AppState>().setFocusTarget(
                                  Offset(item.x, item.y),
                                  lock: true,
                                );
                            context.read<AppState>().requestFocus(
                                  Offset(item.x, item.y),
                                  includeMimic: true,
                                );
                          },
                        );
                      },
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text("No results found"),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActiveChips(TelemetryProvider telemetry) {
    final chips = <Widget>[];
    if (telemetry.categoryFilter != null) {
      chips.add(
        InputChip(
          label: Text('Category: ${telemetry.categoryFilter}'),
          onDeleted: () => telemetry.setCategoryFilter(null),
        ),
      );
    }
    if (telemetry.levelFilter != null) {
      chips.add(
        InputChip(
          label: Text('Level: ${telemetry.levelFilter}'),
          onDeleted: () => telemetry.setLevelFilter(null),
        ),
      );
    }
    if (telemetry.actionFilter != null) {
      chips.add(
        InputChip(
          label: Text('Action: ${telemetry.actionFilter}'),
          onDeleted: () => telemetry.setActionFilter(null),
        ),
      );
    }
    if (telemetry.pinFilter != 'all') {
      chips.add(
        InputChip(
          label: Text('Pin: ${telemetry.pinFilter}'),
          onDeleted: () => telemetry.setPinFilter('all'),
        ),
      );
    }
    if (telemetry.requireAbout) {
      chips.add(
        InputChip(
          label: const Text('Only with notes'),
          onDeleted: () => telemetry.setRequireAbout(false),
        ),
      );
    }
    if (telemetry.onlyMissingDetails) {
      chips.add(
        InputChip(
          label: const Text('Missing details'),
          onDeleted: () => telemetry.setOnlyMissingDetails(false),
        ),
      );
    }
    if (telemetry.onlyAlarms) {
      chips.add(
        InputChip(
          label: const Text('Only alarms'),
          onDeleted: () => telemetry.setOnlyAlarms(false),
        ),
      );
    }
    if (telemetry.query.isNotEmpty) {
      chips.add(
        InputChip(
          label: Text('Query: ${telemetry.query}'),
          onDeleted: () {
            telemetry.setQuery('');
            _searchController.clear();
          },
        ),
      );
    }
    return chips;
  }
}
