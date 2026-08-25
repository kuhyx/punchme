/// One period's worked-vs-expected summary.
library;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:punchme/logic/balance.dart';
import 'package:punchme/ui/home/today_summary.dart';

/// Formats [duration] with an explicit sign, e.g. `+2h 30m` or `-45m`.
String signedDurationLabel(Duration duration) {
  final sign = duration.isNegative ? '-' : '+';
  final magnitude = duration.abs();
  return '$sign${durationLabel(magnitude)}';
}

/// A card showing one period's balance.
class BalanceCard extends StatelessWidget {
  /// Creates a card labelled [title] for [balance].
  const BalanceCard({
    required this.title,
    required this.balance,
    super.key,
  });

  /// The period's name, e.g. `This week`.
  final String title;

  /// The computed balance for the period.
  final Balance balance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Status hues are fills with onStatus on top, never text on the page
    // background -- that is the contract the shared palette documents.
    final status =
        theme.extension<AppStatusColors>() ?? const AppStatusColors.standard();
    final difference = balance.difference;
    final settled = difference == Duration.zero;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppTextSize.label,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (settled)
              Text(
                'On track',
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: AppTextSize.display,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: _BalanceChip(
                  label: signedDurationLabel(difference),
                  fill: balance.isPositive ? status.success : status.danger,
                  foreground: status.onStatus,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Worked ${durationLabel(balance.worked)} of '
              '${durationLabel(balance.quota)}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: AppTextSize.label,
              ),
            ),
            if (balance.todaySoFar > Duration.zero) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Today so far ${durationLabel(balance.todaySoFar)}',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: AppTextSize.label,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The signed balance, drawn as a status fill with text on top.
class _BalanceChip extends StatelessWidget {
  const _BalanceChip({
    required this.label,
    required this.fill,
    required this.foreground,
  });

  final String label;
  final Color fill;
  final Color foreground;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: fill,
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: AppTextSize.title,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
