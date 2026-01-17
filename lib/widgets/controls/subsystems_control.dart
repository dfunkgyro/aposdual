import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../providers/telemetry_provider.dart';
import '../../models/telemetry_item.dart';

class SubSystemsControl extends StatefulWidget {
  const SubSystemsControl({super.key});

  @override
  State<SubSystemsControl> createState() => _SubSystemsControlState();
}

class _SubSystemsControlState extends State<SubSystemsControl> {
  String _viewMode = 'category'; // 'category' or 'simple'

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text("Sub-Systems", style: TextStyle(fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              value: _viewMode,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'category', child: Text("Categorized List")),
                DropdownMenuItem(value: 'simple', child: Text("Simple List")),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _viewMode = val);
              },
            ),
            Consumer<TelemetryProvider>(
              builder: (context, telemetry, _) {
                final groups = telemetry.groupedByCategory();
                return Container(
                  height: 180,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
                  child: telemetry.items.isEmpty
                      ? const Center(child: Text("No telemetry loaded"))
                      : ListView(
                          children: _viewMode == 'category'
                              ? _buildCategoryList(context, groups)
                              : telemetry.filteredItems.map((item) => _buildItemTile(context, item)).toList(),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryList(BuildContext context, Map<String, List<TelemetryItem>> groups) {
    final categories = groups.keys.toList()..sort();
    final widgets = <Widget>[];
    for (final category in categories) {
      widgets.add(Padding(
        padding: const EdgeInsets.all(4),
        child: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
      ));
      final items = groups[category]!..sort((a, b) => a.title.compareTo(b.title));
      widgets.addAll(items.map((item) => _buildItemTile(context, item)));
    }
    return widgets;
  }

  Widget _buildItemTile(BuildContext context, TelemetryItem item) {
    return InkWell(
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(item.title),
      ),
    );
  }
}
