import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/apd_provider.dart';
import '../../providers/app_state.dart';
import '../../providers/telemetry_provider.dart';
import '../../models/telemetry_item.dart';

class ApdControl extends StatefulWidget {
  const ApdControl({super.key});

  @override
  State<ApdControl> createState() => _ApdControlState();
}

class _ApdControlState extends State<ApdControl> {
  final _sectionAController = TextEditingController();
  final _sectionASegmentController = TextEditingController();
  final _sectionBController = TextEditingController();
  final _sectionBSegmentController = TextEditingController();
  
  final _pinpointController = TextEditingController();
  final _pegpointController = TextEditingController();
  final _distanceController = TextEditingController();

  TelemetryItem? _findItem(String input, TelemetryProvider telemetry) {
    final needle = input.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final item in telemetry.items) {
      if (item.id.toLowerCase() == needle || item.title.toLowerCase() == needle) {
        return item;
      }
    }
    return null;
  }

  void _goToLocation(BuildContext context, Offset location) {
    context.read<AppState>().requestFocus(location, includeMimic: true);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Consumer2<APDProvider, TelemetryProvider>(
          builder: (context, apd, telemetry, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Advance Position Detector", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (!apd.isActive)
                  ElevatedButton(
                    onPressed: apd.activateAPD,
                    child: const Text("Activate Position Finder"),
                  )
                else ...[
                   _buildSectionA(context, apd, telemetry),
                   const Divider(),
                   _buildSectionB(context, apd, telemetry),
                   const Divider(),
                   _buildSectionC(context, apd),
                   const SizedBox(height: 10),
                   ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: apd.deactivateAPD,
                      child: const Text("Deactivate APD"),
                   ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionA(BuildContext context, APDProvider apd, TelemetryProvider telemetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Anchor Point (Section A)", style: TextStyle(fontWeight: FontWeight.w600)),
        Row(
          children: [
            Expanded(child: TextField(controller: _sectionAController, decoration: const InputDecoration(labelText: "Item ID"))),
            IconButton(
              icon: const Icon(Icons.check), 
              onPressed: () {
                 final item = _findItem(_sectionAController.text, telemetry);
                 if (item == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Item not found in telemetry list.")),
                   );
                   return;
                 }
                 apd.setSectionA(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
              },
            ),
          ],
        ),
         Row(
          children: [
            Expanded(child: TextField(controller: _sectionASegmentController, decoration: const InputDecoration(labelText: "Chainage"))),
            TextButton(
              onPressed: () {
                 final val = double.tryParse(_sectionASegmentController.text);
                 if (val != null) apd.setSectionASegment(val);
              },
              child: const Text("Assign"),
            ),
          ],
        ),
        if (apd.sectionAItem != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final item = apd.sectionAItem!;
                _goToLocation(context, Offset(item.x, item.y));
              },
              child: const Text("Go to Section A"),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionB(BuildContext context, APDProvider apd, TelemetryProvider telemetry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Alignment Point (Section B)", style: TextStyle(fontWeight: FontWeight.w600)),
         Row(
          children: [
            Expanded(child: TextField(controller: _sectionBController, decoration: const InputDecoration(labelText: "Item ID"))),
            IconButton(
              icon: const Icon(Icons.check), 
              onPressed: () {
                 final item = _findItem(_sectionBController.text, telemetry);
                 if (item == null) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Item not found in telemetry list.")),
                   );
                   return;
                 }
                 apd.setSectionB(APDItem(id: item.id, title: item.title, x: item.x, y: item.y));
              },
            ),
          ],
        ),
         Row(
          children: [
            Expanded(child: TextField(controller: _sectionBSegmentController, decoration: const InputDecoration(labelText: "Chainage"))),
            TextButton(
              onPressed: () {
                 final val = double.tryParse(_sectionBSegmentController.text);
                 if (val != null) apd.setSectionBSegment(val);
              },
              child: const Text("Assign"),
            ),
          ],
        ),
        if (apd.sectionBItem != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final item = apd.sectionBItem!;
                _goToLocation(context, Offset(item.x, item.y));
              },
              child: const Text("Go to Section B"),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionC(BuildContext context, APDProvider apd) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Chain Adjustment (Section C)", style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        // Pinpoint
        Row(
          children: [
            Expanded(child: TextField(controller: _pinpointController, decoration: const InputDecoration(labelText: "Pinpoint (+/-)"))),
             IconButton(
              icon: const Icon(Icons.add), 
              onPressed: () {
                 // Logic: Take current A segment + pinpoint
                  // Simplify: just pass pinpoint value
              },
            ),
          ],
        ),
        // Pegpoint
        Row(
          children: [
            Expanded(child: TextField(controller: _pegpointController, decoration: const InputDecoration(labelText: "Pegpoint"))),
            TextButton(
              onPressed: () {
                 final val = double.tryParse(_pegpointController.text);
                 if (val != null) apd.calculateSectionCFromChainage(val);
              },
              child: const Text("Calc"),
            ),
          ],
        ),
         Row(
          children: [
            Expanded(child: TextField(controller: _distanceController, decoration: const InputDecoration(labelText: "Distance (m)"))),
            TextButton(
              onPressed: () {
                 final val = double.tryParse(_distanceController.text);
                 if (val != null) apd.calculateSectionCFromDistance(val);
              },
              child: const Text("Plot"),
            ),
          ],
        ),
        if (apd.sectionCItem != null)
          Padding(
             padding: const EdgeInsets.only(top: 8.0),
             child: Text("Section C: (${apd.sectionCItem!.x.toStringAsFixed(1)}, ${apd.sectionCItem!.y.toStringAsFixed(1)})", style: const TextStyle(color: Colors.green)),
           ),
        if (apd.sectionCItem != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                final item = apd.sectionCItem!;
                _goToLocation(context, Offset(item.x, item.y));
              },
              child: const Text("Go to Section C"),
            ),
          ),
      ],
    );
  }
}
