/// Editing one day's check-in and check-out times.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/day_entry.dart';
import 'package:punchme/models/local_date.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// The outcome of editing a day.
class DayEdit {
  /// Creates an edit result.
  const DayEdit({required this.entry, this.delete = false});

  /// The edited entry.
  final DayEntry entry;

  /// Whether the user asked to delete the day instead of saving it.
  final bool delete;
}

/// A dialog for correcting one day's times.
///
/// Manual editing exists because a forgotten check-out would otherwise
/// corrupt the statistics permanently.
class DayEditor extends StatefulWidget {
  /// Creates an editor over [entry].
  const DayEditor({required this.entry, super.key});

  /// The day being edited.
  final DayEntry entry;

  @override
  State<DayEditor> createState() => _DayEditorState();
}

class _DayEditorState extends State<DayEditor> {
  late DateTime _checkIn = widget.entry.checkIn;
  late DateTime? _checkOut = widget.entry.checkOut;

  Future<void> _pick({required bool isCheckIn}) async {
    final base = isCheckIn ? _checkIn : _checkOut ?? _checkIn;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) {
      return;
    }
    final updated = DateTime(
      base.year,
      base.month,
      base.day,
      picked.hour,
      picked.minute,
    );
    setState(() {
      if (isCheckIn) {
        _checkIn = updated;
      } else {
        _checkOut = updated;
      }
    });
  }

  /// The edited entry, with an overnight check-out pushed to the next day.
  DayEntry get _result {
    var checkOut = _checkOut;
    // A check-out earlier than the check-in means the session crossed
    // midnight; keep it on the following day rather than storing a negative.
    if (checkOut != null && checkOut.isBefore(_checkIn)) {
      checkOut = checkOut.add(const Duration(days: 1));
    }
    return DayEntry(
      dateKey: localDateKey(_checkIn),
      checkIn: _checkIn,
      checkOut: checkOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final worked = _result.worked;
    return AlertDialog(
      title: Text(widget.entry.dateKey),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            title: const Text('Check in'),
            trailing: Text(clockLabel(_checkIn)),
            onTap: () => _pick(isCheckIn: true),
          ),
          ListTile(
            title: const Text('Check out'),
            trailing: Text(
              _checkOut == null ? 'not set' : clockLabel(_checkOut!),
            ),
            onTap: () => _pick(isCheckIn: false),
          ),
          if (_checkOut != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Total ${durationLabel(worked ?? Duration.zero)}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(DayEdit(entry: widget.entry, delete: true)),
          child: const Text('Delete'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(DayEdit(entry: _result)),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
