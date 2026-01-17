import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/text_provider.dart';

class TextingControl extends StatelessWidget {
  const TextingControl({super.key});

  @override
  Widget build(BuildContext context) {
    final textController = TextEditingController();
    final fonts = const [
      'Arial',
      'Helvetica',
      'Times New Roman',
      'Courier New',
      'Verdana',
      'Georgia',
      'Trebuchet MS',
      'Arial Black',
    ];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Consumer<TextProvider>(
          builder: (context, textProvider, _) {
            textController.text = textProvider.currentTextInput;
            textController.selection = TextSelection.fromPosition(TextPosition(offset: textController.text.length));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Texting Control Panel", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    labelText: "Enter text...",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => textProvider.updateToolSettings(text: val),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                     const Text("Color: "),
                     _colorDot(textProvider, Colors.black),
                     _colorDot(textProvider, Colors.red),
                     _colorDot(textProvider, Colors.blue),
                  ],
                ),
                 Row(
                  children: [
                     const Text("Size: "),
                     Expanded(
                       child: Slider(
                         value: textProvider.currentFontSize,
                         min: 8,
                         max: 72,
                         onChanged: (v) => textProvider.updateToolSettings(fontSize: v),
                       ),
                     ),
                     Text(textProvider.currentFontSize.toInt().toString()),
                  ],
                ),
                DropdownButtonFormField<String>(
                  value: textProvider.currentFontFamily,
                  decoration: const InputDecoration(labelText: "Font"),
                  items: fonts.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    textProvider.updateToolSettings(fontFamily: value);
                  },
                ),
                DropdownButtonFormField<String>(
                  value: textProvider.currentEffectType,
                  decoration: const InputDecoration(labelText: "Effect"),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text("None")),
                    DropdownMenuItem(value: 'flash', child: Text("Flash")),
                    DropdownMenuItem(value: 'disappear', child: Text("Disappear")),
                    DropdownMenuItem(value: 'colorChange', child: Text("Color Change")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    textProvider.updateToolSettings(effectType: value);
                  },
                ),
                DropdownButtonFormField<TextOrientation>(
                  value: textProvider.currentOrientation,
                  decoration: const InputDecoration(labelText: "Orientation"),
                  items: const [
                    DropdownMenuItem(value: TextOrientation.horizontal, child: Text("Horizontal")),
                    DropdownMenuItem(value: TextOrientation.vertical, child: Text("Vertical")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    textProvider.updateToolSettings(orientation: value);
                  },
                ),
                Row(
                  children: [
                    const Text("Effect Interval: "),
                    Expanded(
                      child: Slider(
                        value: textProvider.currentEffectInterval.toDouble(),
                        min: 200,
                        max: 5000,
                        divisions: 24,
                        onChanged: (v) => textProvider.updateToolSettings(effectInterval: v.toInt()),
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_comment),
                  label: const Text("Add Text (Click on Map)"),
                  onPressed: () {
                     textProvider.setPlacingText(true);
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tap on map to place text.")));
                  },
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.saveFile(
                          dialogTitle: 'Save text',
                          fileName: 'texts.json',
                          allowedExtensions: ['json'],
                          type: FileType.custom,
                        );
                        if (path == null) return;
                        await File(path).writeAsString(textProvider.toJsonString());
                      },
                      child: const Text("Save Texts"),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['json'],
                        );
                        if (result == null || result.files.single.path == null) return;
                        final content = await File(result.files.single.path!).readAsString();
                        textProvider.loadFromJsonString(content);
                      },
                      child: const Text("Load Texts"),
                    ),
                  ],
                ),
                if (textProvider.selectedText != null) ...[
                   const Divider(),
                   const Text("Selected Text", style: TextStyle(fontWeight: FontWeight.bold)),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                     children: [
                       IconButton(icon: const Icon(Icons.update), onPressed: textProvider.updateSelectedText, tooltip: "Update"),
                       IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: textProvider.removeSelectedText, tooltip: "Remove"),
                     ],
                   ),
                ]
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _colorDot(TextProvider provider, Color color) {
    return GestureDetector(
      onTap: () => provider.updateToolSettings(color: color),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: provider.currentColor == color ? Border.all(color: Colors.blue, width: 2) : null,
        ),
      ),
    );
  }
}
