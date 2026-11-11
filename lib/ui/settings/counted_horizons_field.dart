/// Choosing which statistics cards steer today's target.
library;

import 'package:flutter/material.dart';
import 'package:punchme/models/horizon.dart';
import 'package:punchme/ui/glyphs.dart';

/// One switch per card; a card switched off is info only.
class CountedHorizonsField extends StatelessWidget {
  /// Creates the field over [counted].
  const CountedHorizonsField({
    required this.counted,
    required this.onChanged,
    super.key,
  });

  /// The cards that currently count.
  final Set<Horizon> counted;

  /// Called with the new set when a switch flips.
  final ValueChanged<Set<Horizon>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    // textgate: the explanation that switched-off cards turn info-only is
    // gone; Statistics marks such a card with the same info glyph.
    children: <Widget>[
      for (final horizon in Horizon.values)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Align(
            alignment: Alignment.centerLeft,
            child: HorizonGlyph(horizon),
          ),
          secondary: counted.contains(horizon)
              ? null
              : const Icon(Icons.info_outline, semanticLabel: 'Info only'),
          value: counted.contains(horizon),
          onChanged: (on) => onChanged(<Horizon>{
            for (final h in Horizon.values)
              if (h == horizon ? on : counted.contains(h)) h,
          }),
        ),
    ],
  );
}
