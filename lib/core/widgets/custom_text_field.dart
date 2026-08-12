import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final Widget? suffixWidget;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.enabled = true,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.suffixWidget,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  void didUpdateWidget(covariant CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPassword != widget.isPassword) {
      _obscureText = widget.isPassword;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 7),
        ],
        Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            enabled: widget.enabled,
            validator: widget.validator,
            onChanged: widget.onChanged,
            maxLines: widget.maxLines,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                fontSize: 14,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      size: 19,
                      color: _isFocused
                          ? (isDark ? AppColors.primaryLight : AppColors.primary)
                          : (isDark ? AppColors.textTertiaryDark : AppColors.textSecondaryLight),
                    )
                  : null,
              suffixIcon: widget.suffixWidget ??
                  (widget.isPassword
                      ? IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 19,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                          tooltip:
                              _obscureText ? 'Show password' : 'Hide password',
                        )
                      : null),
              filled: true,
              fillColor: isDark
                  ? (_isFocused ? const Color(0xFF161E30) : const Color(0xFF111726))
                  : (_isFocused ? Colors.white : const Color(0xFFF8FAFC)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                  width: 0.8,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight,
                  width: 0.8,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(
                  color: AppColors.error,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
