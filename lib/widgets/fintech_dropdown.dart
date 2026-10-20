// lib/widgets/fintech_dropdown.dart
import 'package:flutter/material.dart';

/// A modern, fintech-styled rounded dropdown field designed for IT Box forms and filter bars.
/// Features 16px curved floating popup menus, smooth rounded border styling, and chevron indicator.
class FintechDropdown<T> extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final bool isExpanded;
  final EdgeInsetsGeometry? contentPadding;

  const FintechDropdown({
    super.key,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    required this.value,
    required this.items,
    required this.onChanged,
    this.validator,
    this.isExpanded = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // AMOLED and dark-surface elevation aware background for popup menu
    final dropdownSurface = isDark
        ? (theme.scaffoldBackgroundColor == Colors.black ? const Color(0xFF1B1B22) : const Color(0xFF22222E))
        : cs.surfaceContainerHighest;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        contentPadding: contentPadding,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          isDense: true,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          dropdownColor: dropdownSurface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: cs.primary,
            size: 22,
          ),
          hint: hintText != null
              ? Text(
                  hintText!,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.45),
                    fontWeight: FontWeight.normal,
                  ),
                )
              : null,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
