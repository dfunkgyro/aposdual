import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'controls/apd_control.dart';
import 'controls/drawing_control.dart';
import 'controls/texting_control.dart';
import 'glass_panel.dart';
import '../models/ui_theme.dart';

class LeftSidebar extends StatelessWidget {
  const LeftSidebar({super.key});

  Widget _panel(Widget child) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: uiTheme.backgroundGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                const Text(
                  "Workspace Tools",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Collapse sidebar',
                  onPressed: appState.toggleLeftSidebarCollapsed,
                  icon: Icon(Icons.chevron_left, size: 22, color: uiTheme.accent),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  _panel(const ApdControl()),
                  _panel(const DrawingControl()),
                  _panel(const TextingControl()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
