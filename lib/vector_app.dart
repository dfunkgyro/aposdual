import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/app_state.dart';
import 'models/ui_theme.dart';
import 'providers/drawing_provider.dart';
import 'providers/apd_provider.dart';
import 'providers/chatbot_provider.dart';
import 'providers/text_provider.dart';
import 'providers/telemetry_provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/history_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/media_provider.dart';
import 'providers/link_provider.dart';
import 'providers/supabase_provider.dart';
import 'providers/openai_provider.dart';
import 'providers/item_links_provider.dart';
import 'providers/view_preset_provider.dart';
import 'widgets/dual_viewer.dart';
import 'widgets/left_sidebar.dart';
import 'widgets/sidebar.dart';
import 'widgets/timeline_panel.dart';
import 'widgets/glass_panel.dart';
import 'widgets/command_palette.dart';


class VectorApp extends StatefulWidget {
  const VectorApp({super.key});

  @override
  State<VectorApp> createState() => _VectorAppState();
}

class _VectorAppState extends State<VectorApp> {
  @override
  void initState() {
    super.initState();
    // Defer loading to allow provider access
    WidgetsBinding.instance.addPostFrameCallback((_) {
       // We can't access Provider here easily without context below... 
       // Actually we can do it in the Consumer's builder or just modify AppState constructor?
       // AppState constructor cannot differ async.
       // Let's rely on the Sidebar to trigger it? Or a wrapper.
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..loadAssetLists()), 
        ChangeNotifierProvider(create: (_) => DrawingProvider()),
        ChangeNotifierProvider(create: (_) => APDProvider()),
        ChangeNotifierProvider(create: (_) => ChatbotProvider()..loadIntents()), // Load intents here
        ChangeNotifierProvider(create: (_) => TextProvider()),
        ChangeNotifierProvider(create: (_) => TelemetryProvider()),
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider()),
        ChangeNotifierProvider(create: (_) => LinkProvider()),
        ChangeNotifierProvider(create: (_) => ItemLinksProvider()),
        ChangeNotifierProvider(create: (_) => SupabaseProvider()),
        ChangeNotifierProvider(create: (_) => OpenAiProvider()),
        ChangeNotifierProvider(create: (_) => ViewPresetProvider()),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
          return MaterialApp(
            title: 'VectorG35 Port',
            theme: _buildTheme(false, uiTheme, appState.highContrast),
            darkTheme: _buildTheme(true, uiTheme, appState.highContrast),
            themeMode: appState.themeMode,
            builder: (context, child) {
              final media = MediaQuery.of(context);
              return MediaQuery(
                data: media.copyWith(textScaleFactor: appState.textScale),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Scaffold(
              body: Column(
                children: [
                  const Expanded(child: MainScreen()),
                  if (appState.isTimelineVisible) const TimelinePanel(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    // Defer initialization until after first build to ensure context is valid for looking up providers/assets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppState>(context, listen: false).init(context);
      Provider.of<ChatbotProvider>(context, listen: false).loadIntents();
      Provider.of<LinkProvider>(context, listen: false).load();
      Provider.of<TelemetryProvider>(context, listen: false).loadSettings();
      Provider.of<AlarmProvider>(context, listen: false).loadSettings();
      Provider.of<SupabaseProvider>(context, listen: false).initialize();
      Provider.of<OpenAiProvider>(context, listen: false).initialize();
      Provider.of<ViewPresetProvider>(context, listen: false).load();
      final supabase = Provider.of<SupabaseProvider>(context, listen: false);
      Future.delayed(const Duration(seconds: 1), () {
        if (!supabase.isReady || !supabase.isAuthenticated || supabase.isAnonymous) return;
        supabase.applyLatestPortableLinks(
          appState: Provider.of<AppState>(context, listen: false),
          telemetry: Provider.of<TelemetryProvider>(context, listen: false),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final uiTheme = UiThemes.presets[appState.themePreset] ?? UiThemes.glassIce;
            final isCompact = constraints.maxWidth < 900;
            return Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): OpenCommandPaletteIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): ToggleLeftSidebarIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): ToggleRightSidebarIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT): ToggleTimelineIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyM): ToggleMimicIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.equal): ZoomInIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus): ZoomOutIntent(),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0): ResetMainViewIntent(),
                LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowDown): NextItemIntent(),
                LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.arrowUp): PrevItemIntent(),
              },
              child: Actions(
                actions: {
                  OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
                    onInvoke: (intent) {
                      showDialog(context: context, builder: (_) => const CommandPalette());
                      return null;
                    },
                  ),
                  ToggleLeftSidebarIntent: CallbackAction<ToggleLeftSidebarIntent>(
                    onInvoke: (intent) {
                      appState.toggleLeftSidebarCollapsed();
                      return null;
                    },
                  ),
                  ToggleRightSidebarIntent: CallbackAction<ToggleRightSidebarIntent>(
                    onInvoke: (intent) {
                      appState.toggleSidebarCollapsed();
                      return null;
                    },
                  ),
                  ToggleTimelineIntent: CallbackAction<ToggleTimelineIntent>(
                    onInvoke: (intent) {
                      appState.toggleTimeline();
                      return null;
                    },
                  ),
                  ToggleMimicIntent: CallbackAction<ToggleMimicIntent>(
                    onInvoke: (intent) {
                      appState.toggleMimicCollapse();
                      return null;
                    },
                  ),
                  ZoomInIntent: CallbackAction<ZoomInIntent>(
                    onInvoke: (intent) {
                      appState.setMainZoom(appState.mainZoom * 1.1);
                      return null;
                    },
                  ),
                  ZoomOutIntent: CallbackAction<ZoomOutIntent>(
                    onInvoke: (intent) {
                      appState.setMainZoom(appState.mainZoom / 1.1);
                      return null;
                    },
                  ),
                  ResetMainViewIntent: CallbackAction<ResetMainViewIntent>(
                    onInvoke: (intent) {
                      appState.resetMainView();
                      return null;
                    },
                  ),
                  NextItemIntent: CallbackAction<NextItemIntent>(
                    onInvoke: (intent) {
                      final telemetry = context.read<TelemetryProvider>();
                      final item = telemetry.selectNext();
                      if (item != null) {
                        appState.setFocusTarget(Offset(item.x, item.y), lock: true);
                        appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
                      }
                      return null;
                    },
                  ),
                  PrevItemIntent: CallbackAction<PrevItemIntent>(
                    onInvoke: (intent) {
                      final telemetry = context.read<TelemetryProvider>();
                      final item = telemetry.selectPrevious();
                      if (item != null) {
                        appState.setFocusTarget(Offset(item.x, item.y), lock: true);
                        appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
                      }
                      return null;
                    },
                  ),
                },
                child: Focus(
                  autofocus: true,
                  child: Scaffold(
                    drawer: isCompact ? const Drawer(child: LeftSidebar()) : null,
                    endDrawer: isCompact ? const Drawer(child: Sidebar()) : null,
                    body: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: uiTheme.backgroundGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: SafeArea(
                        child: isCompact ? _buildCompactBody(uiTheme) : _buildWideBody(appState, uiTheme),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

class ToggleLeftSidebarIntent extends Intent {
  const ToggleLeftSidebarIntent();
}

class ToggleRightSidebarIntent extends Intent {
  const ToggleRightSidebarIntent();
}

class ToggleTimelineIntent extends Intent {
  const ToggleTimelineIntent();
}

class ToggleMimicIntent extends Intent {
  const ToggleMimicIntent();
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class ResetMainViewIntent extends Intent {
  const ResetMainViewIntent();
}

class NextItemIntent extends Intent {
  const NextItemIntent();
}

class PrevItemIntent extends Intent {
  const PrevItemIntent();
}

ThemeData _buildTheme(bool isDark, UiTheme uiTheme, bool highContrast) {
  final base = isDark
      ? (highContrast ? _buildHighContrastDark() : ThemeData.dark())
      : (highContrast ? _buildHighContrastLight() : ThemeData.light());
  final textTheme = GoogleFonts.spaceGroteskTextTheme(base.textTheme);
  final colorScheme = base.colorScheme.copyWith(
    primary: uiTheme.accent,
    secondary: uiTheme.accentAlt,
    surface: Colors.white.withOpacity(isDark ? 0.08 : 0.18),
  );

  return base.copyWith(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    textTheme: textTheme,
    cardTheme: CardThemeData(
      color: Colors.white.withOpacity(isDark ? 0.08 : 0.2),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerColor: Colors.white.withOpacity(isDark ? 0.2 : 0.35),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(isDark ? 0.06 : 0.25),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: uiTheme.accent),
      ),
    ),
  );
}

ThemeData _buildHighContrastDark() {
  final base = ThemeData.dark();
  return base.copyWith(
    colorScheme: ColorScheme.highContrastDark(),
  );
}

ThemeData _buildHighContrastLight() {
  final base = ThemeData.light();
  return base.copyWith(
    colorScheme: ColorScheme.highContrastLight(),
  );
}

Widget _collapsedRail({
  required String tooltip,
  required IconData icon,
  required VoidCallback onPressed,
  required UiTheme uiTheme,
  required bool isLeft,
}) {
  return Container(
    width: 40,
    decoration: BoxDecoration(
      color: uiTheme.panelTint,
      border: Border(
        right: isLeft ? BorderSide(color: uiTheme.panelBorder) : BorderSide.none,
        left: !isLeft ? BorderSide(color: uiTheme.panelBorder) : BorderSide.none,
      ),
    ),
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon, color: uiTheme.accent),
      onPressed: onPressed,
    ),
  );
}

Widget _buildWideBody(AppState appState, UiTheme uiTheme) {
  return Row(
    children: [
      if (appState.isLeftSidebarCollapsed)
        _collapsedRail(
          tooltip: 'Expand sidebar',
          icon: Icons.chevron_right,
          onPressed: appState.toggleLeftSidebarCollapsed,
          uiTheme: uiTheme,
          isLeft: true,
        )
      else
        const Expanded(
          flex: 2,
          child: LeftSidebar(),
        ),
      const Expanded(
        flex: 7,
        child: DualViewer(),
      ),
      if (appState.isSidebarCollapsed)
        _collapsedRail(
          tooltip: 'Expand sidebar',
          icon: Icons.chevron_left,
          onPressed: appState.toggleSidebarCollapsed,
          uiTheme: uiTheme,
          isLeft: false,
        )
      else
        const Expanded(
          flex: 3,
          child: Sidebar(),
        ),
    ],
  );
}

Widget _buildCompactBody(UiTheme uiTheme) {
  return Stack(
    children: [
      const Positioned.fill(child: DualViewer()),
      Positioned(
        top: 8,
        left: 8,
        child: Builder(
          builder: (context) {
            return GlassPanel(
              padding: EdgeInsets.zero,
              child: IconButton(
                tooltip: 'Open tools panel',
                icon: Icon(Icons.menu, color: uiTheme.accent),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            );
          },
        ),
      ),
      Positioned(
        top: 8,
        right: 8,
        child: Builder(
          builder: (context) {
            return GlassPanel(
              padding: EdgeInsets.zero,
              child: IconButton(
                tooltip: 'Open data panel',
                icon: Icon(Icons.tune, color: uiTheme.accent),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            );
          },
        ),
      ),
    ],
  );
}
