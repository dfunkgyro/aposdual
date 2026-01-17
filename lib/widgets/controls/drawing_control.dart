import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/drawing_provider.dart';

class DrawingControl extends StatelessWidget {
  const DrawingControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Consumer<DrawingProvider>(
          builder: (context, draw, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Drawing Tools", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 5,
                  children: [
                    _toolButton(draw, DrawingTool.none, Icons.mouse),
                    _toolButton(draw, DrawingTool.line, Icons.show_chart),
                    _toolButton(draw, DrawingTool.circle, Icons.circle_outlined),
                    _toolButton(draw, DrawingTool.rectangle, Icons.crop_square),
                    _toolButton(draw, DrawingTool.triangle, Icons.change_history),
                    _toolButton(draw, DrawingTool.star, Icons.star_border),
                    _toolButton(draw, DrawingTool.freehand, Icons.edit),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                   children: [
                     const Text("Width: "),
                     Expanded(
                       child: Slider(
                         value: draw.currentStrokeWidth,
                         min: 1.0, 
                         max: 10.0,
                         onChanged: (v) => draw.setStrokeWidth(v),
                       ),
                     ),
                   ],
                ),
                Row(
                  children: [
                    const Text("Opacity: "),
                    Expanded(
                      child: Slider(
                        value: draw.selectedDrawing?.opacity ?? 1.0,
                        min: 0.1,
                        max: 1.0,
                        onChanged: (v) => draw.setOpacity(v),
                      ),
                    ),
                  ],
                ),
                Row(
                   children: [
                     const Text("Color: "),
                     _colorDot(draw, Colors.black),
                     _colorDot(draw, Colors.red),
                     _colorDot(draw, Colors.blue),
                     _colorDot(draw, Colors.green),
                   ],
                ),
                CheckboxListTile(
                  title: const Text("Fill Shape"),
                  value: draw.isFilled,
                  onChanged: (v) => draw.toggleFill(v ?? false),
                ),
                const Divider(),
                const Text("Manipulation", style: TextStyle(fontWeight: FontWeight.w600)),
                Wrap(
                  spacing: 5,
                  children: [
                    IconButton(icon: const Icon(Icons.rotate_right), onPressed: () => draw.rotateSelected(0.26), tooltip: "Rotate +15°"),
                    IconButton(icon: const Icon(Icons.rotate_left), onPressed: () => draw.rotateSelected(-0.26), tooltip: "Rotate -15°"),
                    IconButton(icon: const Icon(Icons.zoom_out_map), onPressed: () => draw.resizeSelected(1.1), tooltip: "Scale Up"),
                    IconButton(icon: const Icon(Icons.zoom_in_map), onPressed: () => draw.resizeSelected(0.9), tooltip: "Scale Down"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo),
                      onPressed: draw.canUndo ? draw.undo : null,
                      tooltip: "Undo",
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo),
                      onPressed: draw.canRedo ? draw.redo : null,
                      tooltip: "Redo",
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(onPressed: draw.selectAll, child: const Text("Select All")),
                    TextButton(onPressed: draw.deselectAll, child: const Text("Deselect All")),
                    TextButton(onPressed: draw.removeSelected, child: const Text("Remove Selected")),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () async {
                        final path = await FilePicker.platform.saveFile(
                          dialogTitle: 'Save drawings',
                          fileName: 'drawings.json',
                          allowedExtensions: ['json'],
                          type: FileType.custom,
                        );
                        if (path == null) return;
                        await File(path).writeAsString(draw.toJsonString());
                      },
                      child: const Text("Save Drawings"),
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
                        draw.loadFromJsonString(content);
                      },
                      child: const Text("Load Drawings"),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: draw.clearDrawings,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                  child: const Text("Clear Drawings"),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _toolButton(DrawingProvider provider, DrawingTool tool, IconData icon) {
    final isSelected = provider.currentTool == tool;
    return IconButton(
      icon: Icon(icon, color: isSelected ? Colors.blue : Colors.black),
      onPressed: () => provider.setTool(tool),
      tooltip: tool.toString().split('.').last,
    );
  }

  Widget _colorDot(DrawingProvider provider, Color color) {
    return GestureDetector(
      onTap: () => provider.setColor(color),
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
