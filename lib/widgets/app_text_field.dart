import 'package:flutter/material.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration? decoration;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final TextStyle? style;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;

  const AppTextField({
    super.key,
    this.controller,
    this.decoration,
    this.style,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final FocusNode _focusNode;
  bool _didJustFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _didJustFocus = true;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseDeco = widget.decoration ?? const InputDecoration();

    final fintechDecoration = baseDeco.copyWith(
      filled: baseDeco.filled ?? true,
      fillColor: baseDeco.fillColor ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
      contentPadding: baseDeco.contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: baseDeco.border ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
      enabledBorder: baseDeco.enabledBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
      focusedBorder: baseDeco.focusedBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.8,
            ),
          ),
      errorBorder: baseDeco.errorBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.error,
              width: 1.5,
            ),
          ),
      focusedErrorBorder: baseDeco.focusedErrorBorder ??
          OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: theme.colorScheme.error,
              width: 1.8,
            ),
          ),
      hintStyle: baseDeco.hintStyle ??
          TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
      labelStyle: baseDeco.labelStyle ??
          TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
    );

    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.maxLines,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      readOnly: widget.readOnly,
      enableSuggestions: false,
      autocorrect: false,
      style: widget.style ??
          const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }

        if (widget.controller != null && _focusNode.hasFocus && !widget.readOnly) {
          final text = widget.controller!.text;
          final selection = widget.controller!.selection;
          if (_didJustFocus && text.isNotEmpty && selection.baseOffset == 0 && selection.extentOffset == text.length) {
            // Unselect on initial click/focus
            widget.controller!.selection = TextSelection.collapsed(offset: text.length);
          }
        }
        _didJustFocus = false;
      },
      decoration: fintechDecoration,
    );
  }
}
