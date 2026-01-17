import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/telemetry_provider.dart';
import '../providers/alarm_provider.dart';
import 'glass_panel.dart';
import 'svg_canvas.dart';
import '../models/ui_theme.dart';

class DualViewer extends StatelessWidget {
  const DualViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AppState, TelemetryProvider, AlarmProvider>(
      builder: (context, appState, telemetry, alarmProvider, child) {
        final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
        final mainSize = appState.mainSvgSize;
        final mimicSize = appState.mimicSvgSize;
        return LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            final handleHeight = appState.isMimicCollapsed ? 0.0 : 12.0;
            final available = totalHeight - handleHeight;
            final mainHeight = appState.isMimicCollapsed ? available : available * appState.mainSplitRatio;
            final mimicHeight = appState.isMimicCollapsed ? 0.0 : available - mainHeight;

            return Column(
              children: [
                // Main Map Container
                SizedBox(
                  height: mainHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = mainSize?.width ?? constraints.maxWidth;
                      final height = mainSize?.height ?? constraints.maxHeight;
                      return GlassPanel(
                        padding: EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: uiTheme.panelBorder),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: SvgCanvas(
                                  backgroundColor: appState.mainBackgroundColor,
                                  svgContent: appState.mainSvgContent,
                                  items: telemetry.filteredItems,
                                  selectedItem: telemetry.selectedItem,
                                  alarmItems: alarmProvider.matches,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!appState.isMimicCollapsed)
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanUpdate: (details) {
                      final delta = details.delta.dy;
                      if (available <= 0) return;
                      final next = (mainHeight + delta) / available;
                      appState.setMainSplitRatio(next);
                    },
                    child: Container(
                      height: handleHeight,
                      color: uiTheme.panelTint,
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade500,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Mimic Map Container
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: mimicHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (appState.isMimicCollapsed) return const SizedBox.shrink();
                      final width = mimicSize?.width ?? constraints.maxWidth;
                      final height = mimicSize?.height ?? constraints.maxHeight;
                      return GlassPanel(
                        padding: EdgeInsets.zero,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: uiTheme.panelBorder)),
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SizedBox(
                                width: width,
                                height: height,
                                child: SvgCanvas(
                                  backgroundColor: appState.mimicBackgroundColor,
                                  svgContent: appState.mimicSvgContent,
                                  items: telemetry.filteredItems,
                                  selectedItem: telemetry.selectedItem,
                                  alarmItems: alarmProvider.matches,
                                  isMimic: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
