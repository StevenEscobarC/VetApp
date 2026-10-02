import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps [TextFormField] with a visible label above the field —
/// per the design system's accessibility rule, labels are never
/// placeholder-only. Set [hideLabel] to skip the visible label (e.g. search
/// fields whose placeholder already states its purpose) while keeping the
/// [Semantics] label for screen readers.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.errorText,
    this.helperText,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.hideLabel = false,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLength,
  });

  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? errorText;
  final String? helperText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
        ],
        Semantics(
          label: label,
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            validator: validator,
            onChanged: onChanged,
            maxLines: obscureText ? 1 : maxLines,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            decoration: InputDecoration(
              prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
              counterText: maxLength == null ? null : '',
              hintText: hintText,
              errorText: errorText,
              helperText: helperText,
            ),
          ),
        ),
      ],
    );
  }
}
