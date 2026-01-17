import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../providers/drawing_provider.dart';
import '../providers/telemetry_provider.dart';
import '../providers/text_provider.dart';
import '../providers/alarm_provider.dart';
import '../providers/history_provider.dart';
import '../providers/media_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/item_links_provider.dart';
import '../models/telemetry_item.dart';

class SvgCanvas extends StatefulWidget {
  final Color backgroundColor;
  final String? svgContent; 
  final bool isMimic;
  final List<TelemetryItem> items;
  final TelemetryItem? selectedItem;
  final List<TelemetryItem> alarmItems;

  const SvgCanvas({
    super.key,
    required this.backgroundColor,
    this.svgContent,
    this.isMimic = false,
    this.items = const [],
    this.selectedItem,
    this.alarmItems = const [],
  });

  @override
  State<SvgCanvas> createState() => _SvgCanvasState();
}

class _SvgCanvasState extends State<SvgCanvas> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _lastCursorUpdateMs = 0;
  TelemetryItem? _hoveredItem;
  Offset? _hoverPosition;
  String? _lastSelectedId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return Container(
          color: widget.backgroundColor,
          child: Consumer6<AppState, DrawingProvider, TelemetryProvider, TextProvider, AlarmProvider, HistoryProvider>(
            builder: (context, appState, drawingProvider, telemetry, textProvider, alarmProvider, history, _) {
              final media = context.watch<MediaProvider>();
              final notes = context.watch<NotesProvider>();
              final itemLinks = context.watch<ItemLinksProvider>();
              final offset = widget.isMimic ? appState.mimicViewOffset : appState.mainViewOffset;
              final zoom = widget.isMimic ? appState.mimicZoom : appState.mainZoom;
              final svgSize = widget.isMimic ? appState.mimicSvgSize : appState.mainSvgSize;
              final worldSize = svgSize ?? size;
              final baseScale = (worldSize.width <= 0 || worldSize.height <= 0)
                  ? 1.0
                  : math.min(size.width / worldSize.width, size.height / worldSize.height);
              final baseOffset = Offset(
                (size.width - worldSize.width * baseScale) / 2,
                (size.height - worldSize.height * baseScale) / 2,
              );
              final effectiveZoom = zoom * baseScale;
              final effectiveOffset = baseOffset + offset;
              final focusOffset = widget.isMimic ? appState.mimicFocusOffset : appState.mainFocusOffset;
              final targetCenter = Offset(
                size.width * (0.5 + focusOffset.dx),
                size.height * (0.5 + focusOffset.dy),
              );
              if (appState.reduceMotion) {
                if (_pulseController.isAnimating) {
                  _pulseController.stop();
                }
              } else if (!_pulseController.isAnimating) {
                _pulseController.repeat(reverse: true);
              }

              return Listener(
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    final delta = event.scrollDelta.dy;
                    final currentZoom = widget.isMimic ? appState.mimicZoom : appState.mainZoom;
                    final newZoom = delta < 0 ? currentZoom + 0.1 : currentZoom - 0.1;
                    if (widget.isMimic) {
                      appState.setMimicZoom(newZoom);
                    } else {
                      appState.setMainZoom(newZoom);
                    }
                    final focus = appState.focusLocked ? appState.focusTarget : null;
                    if (focus != null) {
                      final effectiveZoomNew = baseScale * newZoom;
                      final desiredOffset = Offset(
                        targetCenter.dx - baseOffset.dx - focus.dx * worldSize.width * effectiveZoomNew,
                        targetCenter.dy - baseOffset.dy - focus.dy * worldSize.height * effectiveZoomNew,
                      );
                      if (widget.isMimic) {
                        appState.setMimicViewOffset(desiredOffset);
                      } else {
                        appState.setMainViewOffset(desiredOffset);
                      }
                    }
                  }
                },
                child: _buildCanvasBody(
                  context,
                  appState,
                  drawingProvider,
                  telemetry,
                  textProvider,
                  alarmProvider,
                  history,
                  media,
                  notes,
                  itemLinks,
                  size,
                  worldSize,
                  baseScale,
                  baseOffset,
                  effectiveZoom,
                  effectiveOffset,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCanvasBody(
    BuildContext context,
    AppState appState,
    DrawingProvider drawingProvider,
    TelemetryProvider telemetry,
    TextProvider textProvider,
    AlarmProvider alarmProvider,
    HistoryProvider history,
    MediaProvider media,
    NotesProvider notes,
    ItemLinksProvider itemLinks,
    Size size,
    Size worldSize,
    double baseScale,
    Offset baseOffset,
    double effectiveZoom,
    Offset effectiveOffset,
  ) {
    final focusOffset = widget.isMimic ? appState.mimicFocusOffset : appState.mainFocusOffset;
    final targetCenter = Offset(
      size.width * (0.5 + focusOffset.dx),
      size.height * (0.5 + focusOffset.dy),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final focus = appState.consumeFocus(isMimic: widget.isMimic);
      if (focus == null) return;
      final newOffset = Offset(
        targetCenter.dx - baseOffset.dx - focus.dx * worldSize.width * effectiveZoom,
        targetCenter.dy - baseOffset.dy - focus.dy * worldSize.height * effectiveZoom,
      );
      if (widget.isMimic) {
        appState.setMimicViewOffset(newOffset);
      } else {
        appState.setMainViewOffset(newOffset);
      }
    });

    final selected = widget.selectedItem;
    if (selected != null && selected.id != _lastSelectedId) {
      _lastSelectedId = selected.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        appState.setFocusTarget(Offset(selected.x, selected.y), lock: true);
        appState.requestFocus(Offset(selected.x, selected.y), includeMimic: true);
      });
    }

    return Focus(
      autofocus: !widget.isMimic,
      onKey: (node, event) {
        if (widget.isMimic || !appState.keyboardPanEnabled) return KeyEventResult.ignored;
        if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.pageDown) {
          final item = context.read<TelemetryProvider>().selectNext();
          if (item != null) {
            appState.setFocusTarget(Offset(item.x, item.y), lock: true);
            appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.pageUp) {
          final item = context.read<TelemetryProvider>().selectPrevious();
          if (item != null) {
            appState.setFocusTarget(Offset(item.x, item.y), lock: true);
            appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
          }
          return KeyEventResult.handled;
        }
        const panAmount = 50.0;
        switch (event.logicalKey.keyLabel) {
          case 'Arrow Left':
            appState.panMain(const Offset(panAmount, 0));
            return KeyEventResult.handled;
          case 'Arrow Right':
            appState.panMain(const Offset(-panAmount, 0));
            return KeyEventResult.handled;
          case 'Arrow Up':
            appState.panMain(const Offset(0, panAmount));
            return KeyEventResult.handled;
          case 'Arrow Down':
            appState.panMain(const Offset(0, -panAmount));
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: MouseRegion(
        onHover: (event) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastCursorUpdateMs < 30) return;
          _lastCursorUpdateMs = now;
          if (appState.showCursorPosition) {
            final world = (event.localPosition - effectiveOffset) / effectiveZoom;
            appState.updateCursorPosition(world);
          }
                      final hit = _hitTestTelemetry(
                        event.localPosition,
                        widget.items,
                        worldSize,
                        effectiveOffset,
                        effectiveZoom,
                        appState.tooltipHitRadius,
                      );
          setState(() {
            _hoveredItem = hit;
            _hoverPosition = event.localPosition;
          });
        },
        onExit: (_) {
          appState.updateCursorPosition(null);
          if (_hoveredItem != null) {
            setState(() {
              _hoveredItem = null;
              _hoverPosition = null;
            });
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
                        // Transform Layer for Zoom and Pan
                        Positioned.fill(
                          child: Transform(
                            transform: Matrix4.identity()
                              ..translate(effectiveOffset.dx, effectiveOffset.dy)
                              ..scale(effectiveZoom),
                            alignment: Alignment.topLeft,
                            child: widget.svgContent != null
                                ? SizedBox(
                                    width: worldSize.width,
                                    height: worldSize.height,
                                    child: SvgPicture.string(
                                      widget.svgContent!,
                                      fit: BoxFit.none,
                                      alignment: Alignment.topLeft,
                                      allowDrawingOutsideViewBox: true,
                                    ),
                                  )
                                : const Center(child: Text("No SVG Loaded")),
                          ),
                        ),
                        // Telemetry markers
                        if (telemetry.showMarkers)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: TelemetryMarkerPainter(
                                      items: widget.items,
                                      worldSize: worldSize,
                                      offset: effectiveOffset,
                                      zoom: effectiveZoom,
                                      selectedId: widget.selectedItem?.id,
                                      selectedIds: telemetry.selectedIds,
                                      markerStyle: telemetry.markerStyle,
                                      pulse: appState.reduceMotion ? 0.0 : _pulseController.value,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        // Alarm markers
                        if (alarmProvider.showMarkers && widget.alarmItems.isNotEmpty)
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return CustomPaint(
                                    painter: AlarmMarkerPainter(
                                      items: widget.alarmItems,
                                      worldSize: worldSize,
                                      offset: effectiveOffset,
                                      zoom: effectiveZoom,
                                      pulse: appState.reduceMotion ? 0.0 : _pulseController.value,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        // Text layer
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: textProvider.texts.where((t) => textProvider.isVisible(t.id)).map((text) {
                                final x = text.position.dx * effectiveZoom + effectiveOffset.dx;
                                final y = text.position.dy * effectiveZoom + effectiveOffset.dy;
                                final isSelected = textProvider.selectedText?.id == text.id;
                                final baseText = Text(
                                  text.text,
                                  style: TextStyle(
                                    color: textProvider.currentEffectColor(text),
                                    fontSize: text.fontSize * effectiveZoom,
                                    fontFamily: text.fontFamily,
                                    backgroundColor: isSelected ? Colors.yellow.withOpacity(0.4) : null,
                                  ),
                                );
                                final oriented = text.orientation == TextOrientation.vertical
                                    ? RotatedBox(quarterTurns: 1, child: baseText)
                                    : baseText;
                                final textWidget = Transform.rotate(
                                  angle: text.rotation,
                                  child: oriented,
                                );
                                return Positioned(
                                  left: x,
                                  top: y,
                                  child: GestureDetector(
                                    onTap: () => textProvider.selectText(text.id),
                                    onPanUpdate: (details) {
                                      if (textProvider.selectedText?.id != text.id) return;
                                      textProvider.moveSelectedText(details.delta / effectiveZoom);
                                    },
                                    child: textWidget,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        // Drawing/Interaction Layer
                        Positioned.fill(
                          child: GestureDetector(
                            onTapDown: (details) {
                              final hit = _hitTestTelemetry(
                                details.localPosition,
                                widget.items,
                                worldSize,
                                effectiveOffset,
                                effectiveZoom,
                                appState.tooltipHitRadius,
                              );
                              if (hit != null) {
                                final keys = RawKeyboard.instance.keysPressed;
                                final isShift = keys.contains(LogicalKeyboardKey.shiftLeft) ||
                                    keys.contains(LogicalKeyboardKey.shiftRight);
                                final isCtrl = keys.contains(LogicalKeyboardKey.controlLeft) ||
                                    keys.contains(LogicalKeyboardKey.controlRight) ||
                                    keys.contains(LogicalKeyboardKey.metaLeft) ||
                                    keys.contains(LogicalKeyboardKey.metaRight);
                                if (isShift) {
                                  telemetry.selectRange(hit);
                                } else if (isCtrl) {
                                  telemetry.toggleSelection(hit);
                                } else {
                                  telemetry.selectItem(hit);
                                }
                                appState.setFocusTarget(
                                  Offset(hit.x, hit.y),
                                  lock: true,
                                );
                                appState.requestFocus(Offset(hit.x, hit.y), includeMimic: true);
                                history.addEntry("Selected ${hit.title}", category: "Telemetry");
                                return;
                              }
                              if (!appState.showCursorPosition) return;
                              final point = (details.localPosition - effectiveOffset) / effectiveZoom;
                              appState.updateCursorPosition(point);
                            },
                            onTapUp: (details) {
                              if (!textProvider.placingText) return;
                              final point = (details.localPosition - effectiveOffset) / effectiveZoom;
                              textProvider.addText(point);
                              textProvider.setPlacingText(false);
                            },
                            onPanStart: (details) {
                              final point = (details.localPosition - effectiveOffset) / effectiveZoom;
                              if (drawingProvider.currentTool == DrawingTool.none) {
                                drawingProvider.selectAt(point);
                              } else {
                                drawingProvider.startDrawing(point);
                              }
                            },
                            onPanUpdate: (details) {
                              if (drawingProvider.currentTool == DrawingTool.none) {
                                if (drawingProvider.selectedDrawing != null) {
                                  drawingProvider.moveSelected(details.delta / effectiveZoom);
                                } else if (!textProvider.placingText) {
                                  if (widget.isMimic) {
                                    appState.panMimic(details.delta);
                                  } else {
                                    appState.panMain(details.delta);
                                  }
                                }
                              } else {
                                final point = (details.localPosition - effectiveOffset) / effectiveZoom;
                                drawingProvider.updateDrawing(point);
                              }
                            },
                            onPanEnd: (details) {
                              drawingProvider.endDrawing();
                            },
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: DrawingPainter(
                                  drawings: drawingProvider.drawings,
                                  activeDrawing: drawingProvider.activeDrawing,
                                  scale: effectiveZoom,
                                  offset: effectiveOffset,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (appState.tooltipsEnabled && appState.tooltipHoverEnabled && _hoveredItem != null && _hoverPosition != null)
                          Builder(
                            builder: (context) {
                              final imageEntry = media.imageFor(_hoveredItem!.id);
                              final noteEntry = notes.noteFor(_hoveredItem!.id);
                              final links = itemLinks.linksFor(_hoveredItem!.id);
                              if (imageEntry.data.isEmpty && !appState.tooltipShowLabel && noteEntry.title.isEmpty && noteEntry.description.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final bytes = imageEntry.data.isNotEmpty ? base64Decode(imageEntry.data) : null;
                              final tooltipWidth = 220.0 * appState.tooltipScale;
                              final tooltipHeight = 140.0 * appState.tooltipScale;
                              final tooltipColor = appState.tooltipBackgroundColor;
                              final tooltipTextColor = appState.tooltipAutoText
                                  ? _autoTextColor(tooltipColor)
                                  : appState.tooltipTextColor;
                              final pos = _hoverPosition!;
                              final maxX = size.width - tooltipWidth - 8;
                              final maxY = size.height - tooltipHeight - 8;
                              final dx = pos.dx.clamp(8.0, maxX < 8 ? 8.0 : maxX);
                              final dy = (pos.dy + 16).clamp(8.0, maxY < 8 ? 8.0 : maxY);
                              return Positioned(
                                left: dx,
                                top: dy,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: appState.tooltipOpacity,
                                    child: Container(
                                      width: tooltipWidth,
                                      height: tooltipHeight,
                                      decoration: BoxDecoration(
                                        color: tooltipColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: _buildTooltipContent(
                                        item: _hoveredItem!,
                                        textColor: tooltipTextColor,
                                        imageBytes: bytes,
                                        noteEntry: noteEntry,
                                        linkCount: links.length,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        if (appState.tooltipsEnabled && appState.tooltipSelectedEnabled && widget.selectedItem != null)
                          Builder(
                            builder: (context) {
                              final imageEntry = media.imageFor(widget.selectedItem!.id);
                              final noteEntry = notes.noteFor(widget.selectedItem!.id);
                              final links = itemLinks.linksFor(widget.selectedItem!.id);
                              if (imageEntry.data.isEmpty && !appState.tooltipShowLabel && noteEntry.title.isEmpty && noteEntry.description.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              final bytes = imageEntry.data.isNotEmpty ? base64Decode(imageEntry.data) : null;
                              final tooltipWidth = 220.0 * appState.tooltipScale;
                              final tooltipHeight = 140.0 * appState.tooltipScale;
                              final tooltipColor = appState.tooltipBackgroundColor;
                              final tooltipTextColor = appState.tooltipAutoText
                                  ? _autoTextColor(tooltipColor)
                                  : appState.tooltipTextColor;
                              final itemDx = widget.selectedItem!.x * worldSize.width * effectiveZoom + effectiveOffset.dx;
                              final itemDy = widget.selectedItem!.y * worldSize.height * effectiveZoom + effectiveOffset.dy;
                              final maxX = size.width - tooltipWidth - 8;
                              final maxY = size.height - tooltipHeight - 8;
                              final dx = (itemDx + 12).clamp(8.0, maxX < 8 ? 8.0 : maxX);
                              final dy = (itemDy - tooltipHeight - 12).clamp(8.0, maxY < 8 ? 8.0 : maxY);
                              return Positioned(
                                left: dx,
                                top: dy,
                                child: IgnorePointer(
                                  child: Opacity(
                                    opacity: appState.tooltipOpacity,
                                    child: Container(
                                      width: tooltipWidth,
                                      height: tooltipHeight,
                                      decoration: BoxDecoration(
                                        color: tooltipColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white24),
                                      ),
                                      child: _buildTooltipContent(
                                        item: widget.selectedItem!,
                                        textColor: tooltipTextColor,
                                        imageBytes: bytes,
                                        noteEntry: noteEntry,
                                        linkCount: links.length,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
  }
}

class TelemetryMarkerPainter extends CustomPainter {
  final List<TelemetryItem> items;
  final Size worldSize;
  final Offset offset;
  final double zoom;
  final String? selectedId;
  final Set<String> selectedIds;
  final String markerStyle;
  final double pulse;

  TelemetryMarkerPainter({
    required this.items,
    required this.worldSize,
    required this.offset,
    required this.zoom,
    required this.selectedId,
    required this.selectedIds,
    required this.markerStyle,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (markerStyle == 'invisible') return;
    final baseRadius = 4.0;
    final pulseRadius = baseRadius + 2.0 * pulse;
    for (final item in items) {
      final x = item.x * worldSize.width * zoom + offset.dx;
      final y = item.y * worldSize.height * zoom + offset.dy;
      final isSelected = selectedId == item.id || selectedIds.contains(item.id);
      final paint = Paint()..color = _categoryColor(item.category);
      final radius = markerStyle == 'pulsing' ? pulseRadius : baseRadius;
      canvas.drawCircle(Offset(x, y), isSelected ? radius + 2 : radius, paint);
      if (isSelected) {
        final border = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black;
        canvas.drawCircle(Offset(x, y), radius + 3, border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TelemetryMarkerPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.offset != offset ||
        oldDelegate.zoom != zoom ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.selectedIds != selectedIds ||
        oldDelegate.markerStyle != markerStyle ||
        oldDelegate.pulse != pulse;
  }
}

class AlarmMarkerPainter extends CustomPainter {
  final List<TelemetryItem> items;
  final Size worldSize;
  final Offset offset;
  final double zoom;
  final double pulse;

  AlarmMarkerPainter({
    required this.items,
    required this.worldSize,
    required this.offset,
    required this.zoom,
    required this.pulse,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final baseRadius = 6.0;
    final radius = baseRadius + 3.0 * pulse;
    final paint = Paint()..color = Colors.red;
    for (final item in items) {
      final x = item.x * worldSize.width * zoom + offset.dx;
      final y = item.y * worldSize.height * zoom + offset.dy;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AlarmMarkerPainter oldDelegate) {
    return oldDelegate.items != items ||
        oldDelegate.offset != offset ||
        oldDelegate.zoom != zoom ||
        oldDelegate.pulse != pulse;
  }
}

TelemetryItem? _hitTestTelemetry(
  Offset localPosition,
  List<TelemetryItem> items,
  Size worldSize,
  Offset offset,
  double zoom,
  double hitRadius,
) {
  final hitRadiusSq = hitRadius * hitRadius;
  TelemetryItem? best;
  double bestDist = hitRadiusSq;
  for (final item in items) {
    final x = item.x * worldSize.width * zoom + offset.dx;
    final y = item.y * worldSize.height * zoom + offset.dy;
    final dx = localPosition.dx - x;
    final dy = localPosition.dy - y;
    final dist = dx * dx + dy * dy;
    if (dist <= bestDist) {
      bestDist = dist;
      best = item;
    }
  }
  return best;
}

Color _categoryColor(String category) {
  const colors = {
    'VCC1_T6,TRANSPONDERS': Color(0xFFFF0000),
    'VCC1_AXLECOUNTERS': Color(0xFF00FF00),
    'VCC1_T1,TRANSPONDERS': Color(0xFF0000FF),
    'VCC1_BLOCKS': Color(0xFFFFFF00),
    'VCC1_WRU': Color(0xFFFF00FF),
    'VCC1_VT,TRANSPONDERS': Color(0xFF00FFFF),
    'LCS': Color(0xFFFFA500),
    'VCC1_T3,TRANSPONDERS': Color(0xFF008000),
    'VCC1_T2,TRANSPONDERS': Color(0xFF000080),
    'RS': Color(0xFF800000),
    'RGI': Color(0xFF008080),
    'WLMD': Color(0xFF808000),
  };
  return colors[category] ?? const Color(0xFF000000);
}

Color _autoTextColor(Color background) {
  return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}

Widget _buildTooltipContent({
  required TelemetryItem item,
  required Color textColor,
  required Uint8List? imageBytes,
  required NoteEntry noteEntry,
  required int linkCount,
}) {
  return Padding(
    padding: const EdgeInsets.all(6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        if (item.category.isNotEmpty)
          Text(
            item.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor.withOpacity(0.85), fontSize: 11),
          ),
        const SizedBox(height: 4),
        if (imageBytes != null)
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                imageBytes,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          )
        else
          Expanded(
            child: Text(
              noteEntry.title.isNotEmpty
                  ? noteEntry.title
                  : (noteEntry.description.isNotEmpty ? noteEntry.description : (item.about ?? item.description ?? '')),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 11),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.link, size: 12, color: textColor.withOpacity(0.8)),
            const SizedBox(width: 4),
            Text(
              '$linkCount',
              style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

class DrawingPainter extends CustomPainter {
  final List<DrawingObject> drawings;
  final DrawingObject? activeDrawing;
  final double scale;
  final Offset offset;

  DrawingPainter({required this.drawings, this.activeDrawing, required this.scale, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);
    
    // Draw committed drawings
    for (final drawing in drawings) {
      _drawObject(canvas, drawing);
    }
    
    // Draw active drawing
    if (activeDrawing != null) {
      _drawObject(canvas, activeDrawing!);
    }
  }

  void _drawObject(Canvas canvas, DrawingObject drawing) {
      canvas.save();
      // Apply transforms
      // 1. Translate
      canvas.translate(drawing.offset.dx, drawing.offset.dy);
      
      // Calculate center for rotation/scale (Centroid)
      Offset center = Offset.zero;
      if (drawing.points.isNotEmpty) {
         double sumX = 0, sumY = 0;
         for (final p in drawing.points) {
           sumX += p.dx; 
           sumY += p.dy;
         }
         center = Offset(sumX / drawing.points.length, sumY / drawing.points.length);
      }
      
      // 2. Translate to center, Rotate, Scale, Translate back
      canvas.translate(center.dx, center.dy);
      canvas.rotate(drawing.rotation);
      canvas.scale(drawing.scale);
      canvas.translate(-center.dx, -center.dy);

      final paint = Paint()
        ..color = drawing.color.withOpacity(drawing.opacity)
        ..strokeWidth = drawing.strokeWidth
        ..style = drawing.isFilled ? PaintingStyle.fill : PaintingStyle.stroke;

      if (drawing.type == DrawingTool.freehand && drawing.path != null) {
        canvas.drawPath(drawing.path!, paint);
        canvas.restore();
        return;
      }

      // Fallback or Shape logic
      if (drawing.points.isEmpty) { 
          canvas.restore(); 
          return;
      }

      switch (drawing.type) {
        case DrawingTool.line:
          if (drawing.points.length >= 2) {
            canvas.drawLine(drawing.points.first, drawing.points.last, paint);
          }
          break;
        case DrawingTool.circle:
           if (drawing.points.length >= 2) {
             final c = drawing.points.first;
             final end = drawing.points.last;
             final radius = (end - c).distance;
             canvas.drawCircle(c, radius, paint);
           }
          break;
        case DrawingTool.rectangle:
           if (drawing.points.length >= 2) {
             final rect = Rect.fromPoints(drawing.points.first, drawing.points.last);
             canvas.drawRect(rect, paint);
           }
          break;
        case DrawingTool.triangle:
        case DrawingTool.star:
           // Simple polygons can be drawn here if path is generated
           // For now treat as basic impl or placeholder
           break;
        case DrawingTool.freehand:
           if (drawing.points.length > 1) {
             for (int i=0; i < drawing.points.length - 1; i++) {
               canvas.drawLine(drawing.points[i], drawing.points[i+1], paint);
             }
           }
           break;
        default:
          break;
      }
      canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
