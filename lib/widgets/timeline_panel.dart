import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';

class TimelinePanel extends StatefulWidget {
  const TimelinePanel({super.key});

  @override
  State<TimelinePanel> createState() => _TimelinePanelState();
}

class _TimelinePanelState extends State<TimelinePanel> {
  double _currentVal = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        return Container(
          height: 180,
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("History Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.play_arrow), onPressed: () {}),
                  Expanded(
                    child: Slider(
                      value: _currentVal,
                      min: 0,
                      max: 100,
                      divisions: 100,
                      label: "T-${(100 - _currentVal).toInt()}m",
                      onChanged: (val) {
                        setState(() => _currentVal = val);
                      },
                    ),
                  ),
                  Text("T-${(100 - _currentVal).toInt()}m"),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: history.entries.length,
                  itemBuilder: (context, index) {
                    final entry = history.entries[index];
                    return Text("${entry.timestamp.toLocal()} - ${entry.action}");
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
