import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/telemetry_provider.dart';
import '../providers/alarm_provider.dart';
import '../models/telemetry_item.dart';

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  List<_CommandItem> _commands = [];
  List<TelemetryItem> _results = [];

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final telemetry = context.read<TelemetryProvider>();
    final alarms = context.read<AlarmProvider>();
    _commands = [
      _CommandItem('Toggle left sidebar', 'Ctrl+1', () => appState.toggleLeftSidebarCollapsed()),
      _CommandItem('Toggle right sidebar', 'Ctrl+2', () => appState.toggleSidebarCollapsed()),
      _CommandItem('Toggle timeline', 'Ctrl+T', () => appState.toggleTimeline()),
      _CommandItem('Toggle mimic view', 'Ctrl+M', () => appState.toggleMimicCollapse()),
      _CommandItem('Zoom in', 'Ctrl+=', () => appState.setMainZoom(appState.mainZoom * 1.1)),
      _CommandItem('Zoom out', 'Ctrl+-', () => appState.setMainZoom(appState.mainZoom / 1.1)),
      _CommandItem('Reset main view', 'Ctrl+0', () => appState.resetMainView()),
      _CommandItem('Next item', 'Alt+Down', () => _selectItem(telemetry.selectNext())),
      _CommandItem('Previous item', 'Alt+Up', () => _selectItem(telemetry.selectPrevious())),
      _CommandItem('Toggle markers', 'Ctrl+Shift+M', () => telemetry.setShowMarkers(!telemetry.showMarkers)),
      _CommandItem('Toggle alarm markers', 'Ctrl+Shift+A', () => alarms.toggleMarkers()),
      _CommandItem('Clear selection', 'Esc', () => telemetry.clearSelection()),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectItem(TelemetryItem? item) {
    if (item == null) return;
    final appState = context.read<AppState>();
    final telemetry = context.read<TelemetryProvider>();
    telemetry.selectItem(item);
    appState.setFocusTarget(Offset(item.x, item.y), lock: true);
    appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
  }

  void _updateQuery(String query) {
    final telemetry = context.read<TelemetryProvider>();
    setState(() {
      _results = query.trim().isEmpty ? [] : telemetry.search(query.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      child: SizedBox(
        width: 520,
        height: 420,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _updateQuery,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Type a command or item...',
                  hintStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: Colors.white70),
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_results.isNotEmpty)
                Expanded(
                  child: ListView(
                    children: [
                      const Text('Items', style: TextStyle(color: Colors.white70)),
                      ..._results.take(12).map(
                            (item) => ListTile(
                              dense: true,
                              title: Text(item.title, style: const TextStyle(color: Colors.white)),
                              subtitle: Text(item.id, style: const TextStyle(color: Colors.white54)),
                              onTap: () {
                                _selectItem(item);
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                      const Divider(color: Colors.white24),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    children: [
                      const Text('Commands', style: TextStyle(color: Colors.white70)),
                      ..._commands.map(
                        (command) => ListTile(
                          dense: true,
                          title: Text(command.label, style: const TextStyle(color: Colors.white)),
                          trailing: Text(command.shortcut, style: const TextStyle(color: Colors.white54)),
                          onTap: () {
                            command.action();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandItem {
  final String label;
  final String shortcut;
  final VoidCallback action;

  const _CommandItem(this.label, this.shortcut, this.action);
}
