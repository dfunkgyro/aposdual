import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';

class SectorControl extends StatefulWidget {
  const SectorControl({super.key});

  @override
  State<SectorControl> createState() => _SectorControlState();
}

class _SectorControlState extends State<SectorControl> {
  final _xController = TextEditingController();
  final _yController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text("Sector", style: TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(child: TextField(controller: _xController, decoration: const InputDecoration(labelText: "X"))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _yController, decoration: const InputDecoration(labelText: "Y"))),
              ],
            ),
            const SizedBox(height: 5),
            ElevatedButton(
              onPressed: () {
                final x = double.tryParse(_xController.text);
                final y = double.tryParse(_yController.text);
                if (x == null || y == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text("Enter valid coordinates.")));
                  return;
                }
                context.read<AppState>().requestFocus(Offset(x, y), includeMimic: true);
              },
              child: const Text("Go to Location"),
            ),
          ],
        ),
      ),
    );
  }
}
