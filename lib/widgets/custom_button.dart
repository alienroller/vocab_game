import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Premium button with gradient background, press animation, and variants.
///
/// Variants: `primary` (gradient), `secondary` (outlined), `danger` (red).
class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final bool isFullWidth;
  final String variant; // 'primary', 'secondary', 'danger'

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.color,
    this.isFullWidth = false,
    this.variant = 'primary',
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null;

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => _scaleCtrl.forward(),
        onTapUp: isDisabled ? null : (_) => _scaleCtrl.reverse(),
        onTapCancel: isDisabled ? null : () => _scaleCtrl.reverse(),
        child: Container(
          width: widget.isFullWidth ? double.infinity : null,
          decoration: _buildDecoration(isDark, isDisabled),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: AppTheme.borderRadiusMd,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: _foregroundColor, size: 20),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _foregroundColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color get _foregroundColor {
    switch (widget.variant) {
      case 'secondary':
        return AppTheme.violet;
      case 'danger':
        return Colors.white;
      default:
        return Colors.white;
    }
  }

  BoxDecoration _buildDecoration(bool isDark, bool isDisabled) {
    if (isDisabled) {
      return BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: AppTheme.borderRadiusMd,
      );
    }

    switch (widget.variant) {
      case 'secondary':
        return BoxDecoration(
          borderRadius: AppTheme.borderRadiusMd,
          border: Border.all(
            color: isDark
                ? AppTheme.violet.withValues(alpha: 0.4)
                : AppTheme.violet.withValues(alpha: 0.3),
          ),
          color: isDark
              ? AppTheme.violet.withValues(alpha: 0.08)
              : AppTheme.violet.withValues(alpha: 0.05),
        );
      case 'danger':
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.error, AppTheme.errorDark],
          ),
          borderRadius: AppTheme.borderRadiusMd,
          boxShadow: AppTheme.shadowGlow(AppTheme.error),
        );
      default: // primary
        return BoxDecoration(
          gradient: widget.color != null
              ? LinearGradient(colors: [
                  widget.color!,
                  widget.color!.withValues(alpha: 0.8)
                ])
              : AppTheme.primaryGradient,
          borderRadius: AppTheme.borderRadiusMd,
          boxShadow: AppTheme.shadowGlow(widget.color ?? AppTheme.violet),
        );
    }
  }
}
