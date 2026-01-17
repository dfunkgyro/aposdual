import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ui_theme.dart';
import '../providers/app_state.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
  });

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: uiTheme.panelTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: uiTheme.panelBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: uiTheme.panelShadow,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
