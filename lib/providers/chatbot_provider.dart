import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'telemetry_provider.dart';
import 'apd_provider.dart';
import 'history_provider.dart';
import 'drawing_provider.dart';
import 'text_provider.dart';
import 'openai_provider.dart';
import 'alarm_provider.dart';
import '../models/ui_theme.dart';
import '../models/telemetry_item.dart';


class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage({required this.text, required this.isUser});
}

class ChatIntent {
  final List<String> triggers;
  final String response;
  final String actionType;
  
  ChatIntent({required this.triggers, required this.response, required this.actionType});
  
  factory ChatIntent.fromJson(Map<String, dynamic> json) {
    return ChatIntent(
      triggers: List<String>.from(json['triggers'] ?? []),
      response: json['response'] ?? "",
      actionType: json['action']?['type'] ?? "none",
    );
  }
}

class ChatbotProvider with ChangeNotifier {
  final List<ChatMessage> _messages = [
    ChatMessage(text: "Hello! I am Gyro. How can I assist you?", isUser: false),
  ];
  List<ChatMessage> get messages => _messages;
  
  List<ChatIntent> _intents = [];
  _PendingChatAction? _pendingAction;
  String? _pendingPrompt;

  Future<void> loadIntents() async {
    try {
      final String content = await rootBundle.loadString('assets/chat/chatapos8.json');
      final List<dynamic> data = jsonDecode(content);
      _intents = data.map((e) => ChatIntent.fromJson(e)).toList();
      _messages.add(ChatMessage(text: "Intents loaded. (${_intents.length} commands available)", isUser: false));
      notifyListeners();
    } catch (e) {
      print("Error loading chat intents: $e");
      _messages.add(ChatMessage(text: "Error loading intents.", isUser: false));
      notifyListeners();
    }
  }

  Future<void> processCommand(
    String input, {
    AppState? appState,
    TelemetryProvider? telemetry,
    APDProvider? apd,
    HistoryProvider? history,
    DrawingProvider? drawing,
    TextProvider? textProvider,
    AlarmProvider? alarms,
    OpenAiProvider? openai,
  }) async {
    _messages.add(ChatMessage(text: input, isUser: true));
    notifyListeners();

    if (_pendingAction != null && telemetry != null) {
      _handlePendingInput(
        input,
        telemetry: telemetry,
        apd: apd,
        appState: appState,
        history: history,
      );
      return;
    }

    final lowerInput = input.toLowerCase();
    
    // Find matching intent
    ChatIntent? match;
    for (final intent in _intents) {
       for (final trigger in intent.triggers) {
          if (lowerInput.contains(trigger.toLowerCase())) {
             match = intent;
             break;
          }
       }
       if (match != null) break;
    }

    if (match != null) {
       _messages.add(ChatMessage(text: match.response, isUser: false));
       _executeAction(
         match.actionType,
         input,
         appState: appState,
         telemetry: telemetry,
         apd: apd,
         history: history,
         drawing: drawing,
         textProvider: textProvider,
         alarms: alarms,
       );
    } else if (openai != null && openai.isReady && telemetry != null) {
       final response = await _handleOpenAi(
         openai,
         input,
         telemetry: telemetry,
         appState: appState,
         history: history,
         alarms: alarms,
       );
       if (response == null) {
         _messages.add(ChatMessage(text: "I didn't understand that command. Try 'help'.", isUser: false));
       }
    } else {
       _messages.add(ChatMessage(text: "I didn't understand that command. Try 'help'.", isUser: false));
    }
    notifyListeners();
  }

  void loadIntentsFromJsonString(String jsonString) {
    final List<dynamic> data = jsonDecode(jsonString);
    _intents = data.map((e) => ChatIntent.fromJson(e)).toList();
    _messages.add(ChatMessage(text: "Intents loaded. (${_intents.length} commands available)", isUser: false));
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _messages.add(ChatMessage(text: "Chat cleared.", isUser: false));
    notifyListeners();
  }

  Future<OpenAiResult?> _handleOpenAi(
    OpenAiProvider openai,
    String input, {
    required TelemetryProvider telemetry,
    AppState? appState,
    HistoryProvider? history,
    AlarmProvider? alarms,
  }) async {
    final context = _buildContext(telemetry, appState);
    final system = _systemPrompt();
    final result = await openai.ask(system: system, user: input, context: context);
    if (result == null) return null;
    _messages.add(ChatMessage(text: result.reply, isUser: false));
    if (result.action != null) {
      _executeAction(
        result.action!,
        result.target ?? result.query ?? input,
        appState: appState,
        telemetry: telemetry,
        history: history,
        alarms: alarms,
      );
    }
    return result;
  }

  Map<String, dynamic> _buildContext(TelemetryProvider telemetry, AppState? appState) {
    final selected = telemetry.selectedItem;
    return {
      'counts': {
        'total': telemetry.items.length,
        'filtered': telemetry.filteredItems.length,
      },
      'selected': selected == null
          ? null
          : {
              'id': selected.id,
              'title': selected.title,
              'category': selected.category,
              'x': selected.x,
              'y': selected.y,
            },
      'filters': {
        'query': telemetry.query,
        'category': telemetry.categoryFilter,
        'level': telemetry.levelFilter,
        'action': telemetry.actionFilter,
      },
      'focusLocked': appState?.focusLocked ?? true,
    };
  }

  String _systemPrompt() {
    return '''
You are Gyro, an ops assistant for a telemetry SVG viewer.
Respond with a JSON object: {"reply": "...", "action": "goTo|search|zoom|pan|help|listItems|set_marker_style|toggle_markers|toggle_alarm_markers|toggle_mimic|reset_main|reset_mimic|set_focus_lock|link_zoom|set_max_zoom|show_cursor|keyboard_pan|apd_activate|apd_deactivate|apd_section_a|apd_section_a_chainage|apd_section_b|apd_section_b_chainage|apd_pinpoint|apd_pegpoint|apd_distance", "target": "...", "query": "..."}.
If required input is missing (e.g. APD item id), set the action and leave target empty; the app will ask a follow-up question.
Use action only when the user explicitly asks to navigate, search, or adjust view.
Keep replies concise and operational.
''';
  }
  
  void _executeAction(
    String actionType,
    String input, {
    AppState? appState,
    TelemetryProvider? telemetry,
    APDProvider? apd,
    HistoryProvider? history,
    DrawingProvider? drawing,
    TextProvider? textProvider,
    AlarmProvider? alarms,
  }) {
     print("Executing action: $actionType");
     if (actionType == "clearChat") {
       _messages.clear();
       _messages.add(ChatMessage(text: "Chat cleared.", isUser: false));
       notifyListeners();
       return;
     }
     if (actionType == "goTo" && appState != null && telemetry != null) {
       final item = _findItemFromInput(input, telemetry);
       if (item != null) {
         telemetry.selectItem(item);
         appState.setFocusTarget(Offset(item.x, item.y), lock: true);
         appState.requestFocus(Offset(item.x, item.y), includeMimic: true);
         history?.addEntry("Go to ${item.title}", category: "Chatbot");
       } else {
         _messages.add(ChatMessage(text: "Item not found.", isUser: false));
       }
       return;
     }
     if (actionType == "apd_activate" && apd != null) {
       apd.activateAPD();
       _messages.add(ChatMessage(text: "APD activated.", isUser: false));
       history?.addEntry("APD activated", category: "Chatbot");
       return;
     }
     if (actionType == "apd_deactivate" && apd != null) {
       apd.deactivateAPD();
       _messages.add(ChatMessage(text: "APD deactivated.", isUser: false));
       history?.addEntry("APD deactivated", category: "Chatbot");
       return;
     }
     if (actionType == "apd_section_a" && apd != null && telemetry != null) {
       final item = _findItemFromInput(input, telemetry);
       if (item == null) {
         _requestInput("Which item ID should be Section A?", _PendingChatAction.apdSectionAItem);
         return;
       }
       apd.setSectionA(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
       _messages.add(ChatMessage(text: "Section A set to ${item.title}.", isUser: false));
       return;
     }
     if (actionType == "apd_section_a_chainage" && apd != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _requestInput("Enter Section A chainage value.", _PendingChatAction.apdSectionAChainage);
         return;
       }
       apd.setSectionASegment(value.toDouble());
       _messages.add(ChatMessage(text: "Section A chainage set to $value.", isUser: false));
       return;
     }
     if (actionType == "apd_section_b" && apd != null && telemetry != null) {
       final item = _findItemFromInput(input, telemetry);
       if (item == null) {
         _requestInput("Which item ID should be Section B?", _PendingChatAction.apdSectionBItem);
         return;
       }
       apd.setSectionB(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
       _messages.add(ChatMessage(text: "Section B set to ${item.title}.", isUser: false));
       return;
     }
     if (actionType == "apd_section_b_chainage" && apd != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _requestInput("Enter Section B chainage value.", _PendingChatAction.apdSectionBChainage);
         return;
       }
       apd.setSectionBSegment(value.toDouble());
       _messages.add(ChatMessage(text: "Section B chainage set to $value.", isUser: false));
       return;
     }
     if (actionType == "apd_pinpoint" && apd != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _requestInput("Enter pinpoint value (+/-).", _PendingChatAction.apdPinpoint);
         return;
       }
       apd.calculateSectionCFromChainage(value.toDouble());
       _messages.add(ChatMessage(text: "Pinpoint applied: $value.", isUser: false));
       return;
     }
     if (actionType == "apd_pegpoint" && apd != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _requestInput("Enter pegpoint value.", _PendingChatAction.apdPegpoint);
         return;
       }
       apd.calculateSectionCFromChainage(value.toDouble());
       _messages.add(ChatMessage(text: "Pegpoint applied: $value.", isUser: false));
       return;
     }
     if (actionType == "apd_distance" && apd != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _requestInput("Enter distance value (m).", _PendingChatAction.apdDistance);
         return;
       }
       apd.calculateSectionCFromDistance(value.toDouble());
       _messages.add(ChatMessage(text: "Distance plotted: $value.", isUser: false));
       return;
     }
     if (actionType == "zoom" && appState != null) {
       final lower = input.toLowerCase();
       if (lower.contains("in")) {
         appState.setMainZoom(appState.mainZoom * 1.1);
       } else if (lower.contains("out") || lower.contains("reduce")) {
         appState.setMainZoom(appState.mainZoom / 1.1);
       } else {
         final level = _extractNumber(lower);
         if (level != null) {
           appState.setMainZoom(level.toDouble());
         }
       }
       if (appState.focusLocked && appState.focusTarget != null) {
         appState.requestFocus(appState.focusTarget!, includeMimic: true);
       }
       history?.addEntry("Zoom command: $input", category: "Chatbot");
       return;
     }
     if (actionType == "pan" && appState != null) {
       final lower = input.toLowerCase();
       const panAmount = 50.0;
       if (lower.contains("left")) appState.panMain(const Offset(panAmount, 0));
       if (lower.contains("right")) appState.panMain(const Offset(-panAmount, 0));
       if (lower.contains("up")) appState.panMain(const Offset(0, panAmount));
       if (lower.contains("down")) appState.panMain(const Offset(0, -panAmount));
       history?.addEntry("Pan command: $input", category: "Chatbot");
       return;
     }
     if (actionType == "changeBackground" && appState != null) {
       final lower = input.toLowerCase();
       final color = lower.contains("dark") ? Colors.black : Colors.white;
       appState.setMainBackgroundColor(color);
       appState.setMimicBackgroundColor(color);
       history?.addEntry("Background change: $input", category: "Chatbot");
       return;
     }
     if (actionType == "activateAPD" && apd != null) {
       apd.activateAPD();
       history?.addEntry("APD activated", category: "Chatbot");
       return;
     }
     if (actionType == "deactivateAPD" && apd != null) {
       apd.deactivateAPD();
       history?.addEntry("APD deactivated", category: "Chatbot");
       return;
     }
     if (actionType == "clearAPD" && apd != null) {
       apd.deactivateAPD();
       history?.addEntry("APD cleared", category: "Chatbot");
       return;
     }
     if (actionType == "listItems" && telemetry != null) {
       _messages.add(ChatMessage(text: "Loaded items: ${telemetry.items.length}", isUser: false));
       return;
     }
     if (actionType == "search" && telemetry != null) {
       final results = telemetry.search(input);
       _messages.add(ChatMessage(text: "Search results: ${results.take(5).map((e) => e.title).join(', ')}", isUser: false));
       return;
     }
     if (actionType == "drawLine" && drawing != null) {
       drawing.setTool(DrawingTool.line);
       _messages.add(ChatMessage(text: "Drawing tool set to line.", isUser: false));
       return;
     }
     if (actionType == "draw" && drawing != null) {
       drawing.setTool(DrawingTool.freehand);
       _messages.add(ChatMessage(text: "Drawing tool set to freehand.", isUser: false));
       return;
     }
     if (actionType == "inputAPD" && apd != null) {
       _messages.add(ChatMessage(text: "APD input recorded: $input", isUser: false));
       return;
     }
     if (actionType == "help") {
       _messages.add(ChatMessage(text: "Try: go to <item>, zoom in/out, pan left/right/up/down.", isUser: false));
       return;
     }
     if (actionType == "toggle_markers" && telemetry != null) {
       telemetry.setShowMarkers(!telemetry.showMarkers);
       _messages.add(ChatMessage(text: "Telemetry markers toggled.", isUser: false));
       return;
     }
     if (actionType == "toggle_alarm_markers" && alarms != null) {
       alarms.toggleMarkers();
       _messages.add(ChatMessage(text: "Alarm markers toggled.", isUser: false));
       return;
     }
     if (actionType == "toggle_mimic" && appState != null) {
       appState.toggleMimicCollapse();
       _messages.add(ChatMessage(text: "Mimic view toggled.", isUser: false));
       return;
     }
     if (actionType == "reset_main" && appState != null) {
       appState.resetMainView();
       _messages.add(ChatMessage(text: "Main view reset.", isUser: false));
       return;
     }
     if (actionType == "reset_mimic" && appState != null) {
       appState.resetMimicView();
       _messages.add(ChatMessage(text: "Mimic view reset.", isUser: false));
       return;
     }
     if (actionType == "set_marker_style" && telemetry != null) {
       final lower = input.toLowerCase();
       if (lower.contains("pulse")) {
         telemetry.setMarkerStyle("pulsing");
       } else if (lower.contains("invisible") || lower.contains("hide")) {
         telemetry.setMarkerStyle("invisible");
       } else {
         telemetry.setMarkerStyle("static");
       }
       _messages.add(ChatMessage(text: "Marker style updated.", isUser: false));
       return;
     }
     if (actionType == "set_focus_lock" && appState != null) {
       final lower = input.toLowerCase();
       final lock = lower.contains("lock") || lower.contains("on") || lower.contains("enable");
       appState.setFocusLocked(lock);
       _messages.add(ChatMessage(text: "Focus lock ${lock ? 'enabled' : 'disabled'}.", isUser: false));
       return;
     }
     if (actionType == "link_zoom" && appState != null) {
       final lower = input.toLowerCase();
       final enabled = lower.contains("on") || lower.contains("enable");
       appState.setLinkZoom(enabled);
       _messages.add(ChatMessage(text: "Link zoom ${enabled ? 'enabled' : 'disabled'}.", isUser: false));
       return;
     }
     if (actionType == "set_max_zoom" && appState != null) {
       final value = _extractNumber(input);
       if (value == null) {
         _messages.add(ChatMessage(text: "Provide a max zoom value.", isUser: false));
         return;
       }
       appState.setMaxZoom(value.toDouble());
       _messages.add(ChatMessage(text: "Max zoom set to $value.", isUser: false));
       return;
     }
     if (actionType == "show_cursor" && appState != null) {
       final lower = input.toLowerCase();
       final enabled = lower.contains("on") || lower.contains("show") || lower.contains("enable");
       appState.setShowCursorPosition(enabled);
       _messages.add(ChatMessage(text: "Cursor position ${enabled ? 'shown' : 'hidden'}.", isUser: false));
       return;
     }
     if (actionType == "keyboard_pan" && appState != null) {
       final lower = input.toLowerCase();
       final enabled = lower.contains("on") || lower.contains("enable");
       appState.setKeyboardPanEnabled(enabled);
       _messages.add(ChatMessage(text: "Keyboard pan ${enabled ? 'enabled' : 'disabled'}.", isUser: false));
       return;
     }
  }

  TelemetryItem? _findItemFromInput(String input, TelemetryProvider telemetry) {
    final lower = input.toLowerCase();
    for (final item in telemetry.items) {
      if (lower.contains(item.id.toLowerCase()) || lower.contains(item.title.toLowerCase())) {
        return item;
      }
    }
    final results = telemetry.search(input);
    return results.isNotEmpty ? results.first : null;
  }

  num? _extractNumber(String input) {
    final match = RegExp(r'([0-9]+(\\.[0-9]+)?)').firstMatch(input);
    if (match == null) return null;
    return num.tryParse(match.group(1) ?? '');
  }

  void _requestInput(String prompt, _PendingChatAction action) {
    _pendingAction = action;
    _pendingPrompt = prompt;
    _messages.add(ChatMessage(text: prompt, isUser: false));
    notifyListeners();
  }

  void _clearPending() {
    _pendingAction = null;
    _pendingPrompt = null;
  }

  void _handlePendingInput(
    String input, {
    required TelemetryProvider telemetry,
    APDProvider? apd,
    AppState? appState,
    HistoryProvider? history,
  }) {
    final action = _pendingAction;
    _clearPending();
    if (action == null) return;
    switch (action) {
      case _PendingChatAction.apdSectionAItem:
        if (apd == null) break;
        final item = _findItemFromInput(input, telemetry);
        if (item == null) {
          _requestInput("Item not found. Try another ID for Section A.", _PendingChatAction.apdSectionAItem);
          return;
        }
        apd.setSectionA(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
        _messages.add(ChatMessage(text: "Section A set to ${item.title}.", isUser: false));
        break;
      case _PendingChatAction.apdSectionAChainage:
        if (apd == null) break;
        final value = _extractNumber(input);
        if (value == null) {
          _requestInput("Enter a numeric chainage for Section A.", _PendingChatAction.apdSectionAChainage);
          return;
        }
        apd.setSectionASegment(value.toDouble());
        _messages.add(ChatMessage(text: "Section A chainage set to $value.", isUser: false));
        break;
      case _PendingChatAction.apdSectionBItem:
        if (apd == null) break;
        final item = _findItemFromInput(input, telemetry);
        if (item == null) {
          _requestInput("Item not found. Try another ID for Section B.", _PendingChatAction.apdSectionBItem);
          return;
        }
        apd.setSectionB(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
        _messages.add(ChatMessage(text: "Section B set to ${item.title}.", isUser: false));
        break;
      case _PendingChatAction.apdSectionBChainage:
        if (apd == null) break;
        final value = _extractNumber(input);
        if (value == null) {
          _requestInput("Enter a numeric chainage for Section B.", _PendingChatAction.apdSectionBChainage);
          return;
        }
        apd.setSectionBSegment(value.toDouble());
        _messages.add(ChatMessage(text: "Section B chainage set to $value.", isUser: false));
        break;
      case _PendingChatAction.apdPinpoint:
        if (apd == null) break;
        final value = _extractNumber(input);
        if (value == null) {
          _requestInput("Enter a numeric pinpoint value.", _PendingChatAction.apdPinpoint);
          return;
        }
        apd.calculateSectionCFromChainage(value.toDouble());
        _messages.add(ChatMessage(text: "Pinpoint applied: $value.", isUser: false));
        break;
      case _PendingChatAction.apdPegpoint:
        if (apd == null) break;
        final value = _extractNumber(input);
        if (value == null) {
          _requestInput("Enter a numeric pegpoint value.", _PendingChatAction.apdPegpoint);
          return;
        }
        apd.calculateSectionCFromChainage(value.toDouble());
        _messages.add(ChatMessage(text: "Pegpoint applied: $value.", isUser: false));
        break;
      case _PendingChatAction.apdDistance:
        if (apd == null) break;
        final value = _extractNumber(input);
        if (value == null) {
          _requestInput("Enter a numeric distance value.", _PendingChatAction.apdDistance);
          return;
        }
        apd.calculateSectionCFromDistance(value.toDouble());
        _messages.add(ChatMessage(text: "Distance plotted: $value.", isUser: false));
        break;
    }
    if (appState != null && history != null) {
      history.addEntry("Chatbot input handled: $input", category: "Chatbot");
    }
    notifyListeners();
  }
}

enum _PendingChatAction {
  apdSectionAItem,
  apdSectionAChainage,
  apdSectionBItem,
  apdSectionBChainage,
  apdPinpoint,
  apdPegpoint,
  apdDistance,
}
