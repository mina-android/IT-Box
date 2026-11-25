// lib/widgets/fintech_components.dart
import 'package:flutter/material.dart';
import '../models/employee.dart';
import '../theme/app_theme.dart';
import 'app_text_field.dart';
import 'common_widgets.dart' show IconBox, showFintechBottomSheet;

/// Modern edge-to-edge transparent top header that respects system status bar padding.
class FintechHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry? padding;

  const FintechHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.actions,
    this.leading,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Padding(
      padding: padding ??
          EdgeInsets.only(
            top: topPadding + 14,
            left: 20,
            right: 16,
            bottom: 10,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget ??
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                    ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// A standard AppBar built with the Fintech Neo-Banking typography and aesthetics.
/// Provides unified title, micro-caption subtitle, and aligned circle action buttons.
class FintechAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final double? titleSpacing;

  const FintechAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.titleSpacing,
  });

  @override
  Size get preferredSize => Size.fromHeight(
      kToolbarHeight +
      (bottom?.preferredSize.height ?? 0.0) +
      (subtitle != null && subtitle!.isNotEmpty ? 6.0 : 0.0));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final defaultSpacing = (leading == null && !automaticallyImplyLeading)
        ? 20.0
        : NavigationToolbar.kMiddleSpacing;

    return AppBar(
      automaticallyImplyLeading: automaticallyImplyLeading,
      titleSpacing: titleSpacing ?? defaultSpacing,
      leading: leading,
      title: titleWidget ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 18.5,
                      letterSpacing: -0.4,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.6),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
      actions: actions != null
          ? [
              for (int i = 0; i < actions!.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions![i],
              ],
              const SizedBox(width: 12),
            ]
          : null,
      bottom: bottom,
    );
  }
}

/// Circular frosted tactile button used in Fintech headers for actions.
class FintechCircleButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;
  final Color? iconColor;
  final double size;

  const FintechCircleButton({
    super.key,
    this.icon,
    this.child,
    this.onPressed,
    this.onTap,
    this.tooltip,
    this.color,
    this.iconColor,
    this.size = 40,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final action = onPressed ?? onTap;

    final defaultBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);

    Widget btn = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color ?? defaultBg,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: child ??
              Icon(
                icon,
                size: size * 0.5,
                color: iconColor ?? cs.onSurface.withValues(alpha: 0.85),
              ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Modern pill-shaped segmented control replacing old underlined TabBars.
class FintechSegmentedControl<T> extends StatelessWidget {
  final List<FintechSegmentItem<T>> items;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final Color? activeColor;
  final Color? activeTextColor;

  const FintechSegmentedControl({
    super.key,
    required this.items,
    required this.selectedValue,
    required this.onValueChanged,
    this.activeColor,
    this.activeTextColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: items.map((item) {
          final isSelected = item.value == selectedValue;
          final itemColor = activeColor ?? cs.primary;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  onValueChanged(item.value);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? itemColor.withValues(alpha: 0.25) : itemColor)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? itemColor.withValues(alpha: 0.4)
                              : Colors.transparent,
                        )
                      : null,
                  boxShadow: isSelected && !isDark
                      ? [
                          BoxShadow(
                            color: itemColor.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.icon != null) ...[
                      Icon(
                        item.icon,
                        size: 16,
                        color: isSelected
                            ? (isDark
                                ? itemColor
                                : (activeTextColor ?? Colors.white))
                            : cs.onSurface.withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? (isDark
                                  ? itemColor
                                  : (activeTextColor ?? Colors.white))
                              : cs.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    if (item.badge != null && item.badge!.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? itemColor.withValues(alpha: 0.3)
                                  : Colors.white.withValues(alpha: 0.25))
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (isDark
                                    ? itemColor
                                    : (activeTextColor ?? Colors.white))
                                : cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FintechSegmentItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? badge;

  const FintechSegmentItem({
    required this.value,
    required this.label,
    this.icon,
    this.badge,
  });
}

/// Contained grouped ledger container.
class FintechContainedLedger extends StatelessWidget {
  final Widget? header;
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool showDividers;
  final double dividerIndent;

  const FintechContainedLedger({
    super.key,
    this.header,
    required this.children,
    this.margin,
    this.padding,
    this.showDividers = true,
    this.dividerIndent = 68,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer.withValues(alpha: isDark ? 0.45 : 0.65),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          if (children.isNotEmpty)
            ListView.separated(
              padding: padding ??
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: children.length,
              separatorBuilder: (_, __) => showDividers
                  ? Divider(
                      height: 1,
                      indent: dividerIndent,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    )
                  : const SizedBox.shrink(),
              itemBuilder: (_, index) => children[index],
            ),
        ],
      ),
    );
  }
}

/// Modern elevated hero card with multi-stop gradients and glassmorphism.
class FintechHeroCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const FintechHeroCard({
    super.key,
    required this.child,
    this.accentColor,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    final color = accentColor ?? cs.primary;

    Widget content = child;
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(20),
            child: child,
          ),
        ),
      );
    }

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: onTap != null ? EdgeInsets.zero : (padding ?? const EdgeInsets.all(20)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withValues(alpha: 0.22),
                  cs.surfaceContainerHigh.withValues(alpha: 0.8),
                  cs.surfaceContainer.withValues(alpha: 0.6),
                ]
              : [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.03),
                  cs.surface,
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : color.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: content,
    );
  }
}

/// Modern squircle Fintech FAB for secondary screens and sub-pages.
class FintechFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color? color;
  final Color? foregroundColor;
  final String? tooltip;
  final double size;

  const FintechFab({
    super.key,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.color,
    this.foregroundColor,
    this.tooltip,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? cs.primary;
    final fg = foregroundColor ?? Colors.white;

    Widget btn = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bg,
                Color.lerp(bg, Colors.black, isDark ? 0.25 : 0.15)!,
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: isDark ? 0.45 : 0.35),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: fg, size: 26),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Modern extended pill Fintech FAB with an icon and label.
class FintechExtendedFab extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color? color;
  final Color? foregroundColor;

  const FintechExtendedFab({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? cs.primary;
    final fg = foregroundColor ?? Colors.white;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bg,
                Color.lerp(bg, Colors.black, isDark ? 0.25 : 0.15)!,
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: bg.withValues(alpha: isDark ? 0.45 : 0.35),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded action button for in-body toolbars (filter, sort, export).
/// 48×48 container with accent coloring when [isActive].
class FintechActionButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback onTap;
  final bool isActive;
  final Color? activeColor;
  final double size;

  const FintechActionButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.isActive = false,
    this.activeColor,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = activeColor ?? theme.colorScheme.primary;

    Widget btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF2B2930) : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? color
                : (isDark ? const Color(0xFF36343B) : const Color(0xFFE2E8F0)),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: isActive
              ? color
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Fintech squircle filter pill matching the Subscriptions/Bills pill standard.
class FintechFilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onDeleted;

  const FintechFilterPill({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.color,
    this.icon,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : AppColors.cardSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? accent
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected
                    ? accent
                    : theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: selected
                      ? accent
                      : theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal scrollable bar of [FintechFilterPill] items.
class FintechFilterBar extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const FintechFilterBar({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: children[i]),
      ),
    );
  }
}

/// Result returned from [showFintechEmployeePicker].
class FintechEmployeeSelection {
  final Employee? employee;
  final bool cleared;
  const FintechEmployeeSelection({this.employee, this.cleared = false});
}

/// Reusable searchable employee picker modal built on [showFintechBottomSheet].
/// Returns `null` if dismissed, `FintechEmployeeSelection(cleared: true)` if
/// "None (Unlinked)" was tapped, or `FintechEmployeeSelection(employee: emp)`.
Future<FintechEmployeeSelection?> showFintechEmployeePicker({
  required BuildContext context,
  required List<Employee> employees,
  int? selectedEmployeeId,
  String? selectedEmployeeName,
  String title = 'Select Employee',
  String? subtitle,
  bool allowNone = false,
  Color? accentColor,
}) async {
  final searchCtrl = TextEditingController();
  final accent = accentColor ?? Theme.of(context).colorScheme.primary;
  List<Employee> filtered = List.from(employees);

  final result = await showFintechBottomSheet<FintechEmployeeSelection>(
    context: context,
    title: title,
    subtitle: subtitle,
    child: StatefulBuilder(
      builder: (ctx, setModalState) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Search employee name or phone...',
                  prefixIcon: Icon(Icons.search_rounded),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (q) {
                  final query = q.toLowerCase().trim();
                  setModalState(() {
                    filtered = employees.where((e) {
                      return e.name.toLowerCase().contains(query) ||
                          e.phoneNumber.toLowerCase().contains(query);
                    }).toList();
                  });
                },
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.45,
                ),
                child: (filtered.isEmpty && !allowNone)
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No matching employees found.',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length + (allowNone ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (allowNone && i == 0) {
                            final isNoneSel = selectedEmployeeId == null &&
                                (selectedEmployeeName == null ||
                                    selectedEmployeeName.isEmpty);
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              leading: IconBox(
                                icon: Icons.person_off_outlined,
                                color: isNoneSel ? accent : Colors.grey,
                                size: 36,
                              ),
                              title: Text(
                                'None (Unlinked)',
                                style: TextStyle(
                                  fontWeight: isNoneSel
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              trailing: isNoneSel
                                  ? Icon(Icons.check_circle_rounded,
                                      color: accent)
                                  : null,
                              onTap: () => Navigator.pop(
                                  ctx,
                                  const FintechEmployeeSelection(
                                      cleared: true)),
                            );
                          }
                          final emp = filtered[allowNone ? i - 1 : i];
                          final isSel = (selectedEmployeeId != null &&
                                  emp.id == selectedEmployeeId) ||
                              (selectedEmployeeId == null &&
                                  selectedEmployeeName != null &&
                                  selectedEmployeeName.isNotEmpty &&
                                  emp.name == selectedEmployeeName);
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            leading: IconBox(
                              icon: Icons.badge_outlined,
                              color: isSel ? accent : AppColors.employeeColor,
                              size: 36,
                            ),
                            title: Text(
                              emp.name,
                              style: TextStyle(
                                fontWeight:
                                    isSel ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14.5,
                              ),
                            ),
                            subtitle: emp.phoneNumber.isNotEmpty
                                ? Text(emp.phoneNumber,
                                    style: const TextStyle(fontSize: 12))
                                : null,
                            trailing: isSel
                                ? Icon(Icons.check_circle_rounded,
                                    color: accent)
                                : null,
                            onTap: () => Navigator.pop(
                                ctx, FintechEmployeeSelection(employee: emp)),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ),
  );

  Future.delayed(const Duration(milliseconds: 350), searchCtrl.dispose);
  return result;
}

