// lib/widgets/selection_bottom_bar.dart
import 'package:flutter/material.dart';

/// Reusable multi-select bottom action bar used across list screens.
class SelectionBottomBar extends StatelessWidget {
  final int selectedCount;
  final int? totalCount;
  final VoidCallback onDelete;
  final VoidCallback onClose;
  final VoidCallback? onSelectAll;
  final VoidCallback? onDeselectAll;
  final String? actionLabel;
  final List<Widget>? leadingActions;
  final List<Widget>? trailingActions;

  const SelectionBottomBar({
    super.key,
    required this.selectedCount,
    this.totalCount,
    required this.onDelete,
    required this.onClose,
    this.onSelectAll,
    this.onDeselectAll,
    this.actionLabel,
    this.leadingActions,
    this.trailingActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131318) : theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
              tooltip: 'Clear selection',
            ),
            const SizedBox(width: 8),
            Text(
              '$selectedCount selected',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            if (onSelectAll != null && onDeselectAll != null && totalCount != null) ...[
              const SizedBox(width: 4),
              TextButton(
                onPressed: selectedCount >= totalCount! ? onDeselectAll : onSelectAll,
                child: Text(
                  selectedCount >= totalCount! ? 'Deselect All' : 'Select All',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            if (leadingActions != null) ...leadingActions!,
            const Spacer(),
            if (trailingActions != null) ...trailingActions!,
            FilledButton.icon(
              onPressed: selectedCount > 0 ? onDelete : null,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: Text(
                actionLabel ?? 'Delete ($selectedCount)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
