/// Word-free building blocks: an icon beside a value, an icon alone.
///
/// textgate: kuhy sees no words Claude wrote. The old sentence survives as
/// the spoken label (screen reader, `android_ui` taps, test finders), never
/// painted.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/models/horizon.dart';

/// An icon followed by a value (a time, a duration, a count, user data).
class IconValue extends StatelessWidget {
  /// Creates `[icon] value`, read aloud as [spoken].
  const IconValue({
    required this.icon,
    required this.value,
    required this.spoken,
    this.style,
    this.color,
    super.key,
  });

  /// What the value is.
  final IconData icon;

  /// The value itself: numbers or user content only.
  final String value;

  /// The full sentence for assistive technology.
  final String spoken;

  /// Style of [value]; inherits the ambient style when null.
  final TextStyle? style;

  /// Tint of [icon]; defaults to [style]'s colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final size = (style?.fontSize ?? AppTextSize.body) * 1.1;
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: size, color: color ?? style?.color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(child: Text(value, style: style)),
        ],
      ),
    );
  }
}

/// Roughly how many days a [Horizon] spans: the number on its calendar.
String horizonDays(Horizon horizon) => switch (horizon) {
  Horizon.week => '7',
  Horizon.month => '30',
  Horizon.year => '365',
};

/// A statistics card's name as a calendar plus its length in days.
class HorizonGlyph extends StatelessWidget {
  /// Creates the glyph for [horizon].
  const HorizonGlyph(this.horizon, {this.style, super.key});

  /// Which card.
  final Horizon horizon;

  /// Style of the day count.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => IconValue(
    icon: Icons.calendar_today,
    value: horizonDays(horizon),
    spoken: horizon.title,
    style: style,
  );
}

/// A row of icons standing in for a status sentence.
class Cue extends StatelessWidget {
  /// Creates the cue [icons], read aloud as [spoken].
  const Cue({
    required this.icons,
    required this.spoken,
    this.color,
    this.size,
    super.key,
  });

  /// The pictograms, left to right.
  final List<IconData> icons;

  /// The sentence they replace.
  final String spoken;

  /// Tint; ambient icon colour when null.
  final Color? color;

  /// Icon size; ambient when null.
  final double? size;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: spoken,
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final icon in icons)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Icon(icon, color: color, size: size),
          ),
      ],
    ),
  );
}

/// A section divider in a long settings list: an icon over a hairline.
class IconSection extends StatelessWidget {
  /// Creates the header [icon], read aloud as [spoken].
  const IconSection(this.icon, {required this.spoken, super.key});

  /// What the section is about.
  final IconData icon;

  /// The old heading, for assistive technology and `android_ui` taps.
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      header: true,
      label: spoken,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: <Widget>[
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
          ],
        ),
      ),
    );
  }
}
