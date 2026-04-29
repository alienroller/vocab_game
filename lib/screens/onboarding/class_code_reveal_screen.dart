import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_theme.dart';

class ClassCodeRevealScreen extends StatefulWidget {
  final String classCode;
  final String className;

  const ClassCodeRevealScreen({
    super.key,
    required this.classCode,
    required this.className,
  });

  @override
  State<ClassCodeRevealScreen> createState() => _ClassCodeRevealScreenState();
}

class _ClassCodeRevealScreenState extends State<ClassCodeRevealScreen> {
  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.classCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard ✅')),
    );
  }

  void _shareCode() async {
    final text = 'Join my class on VocabGame! Code: ${widget.classCode}';
    await Share.share(text);
  }

  void _onContinue() {
    // BUG O4 — old code blocked Continue until the teacher tapped Share or
    // Copy. That meant a teacher who just wanted to explore got
    // dark-pattern-gated. Codes are visible on every dashboard screen
    // and from Profile; nudging once is enough.
    context.go('/teacher/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(
                  child: Text('🎉', style: TextStyle(fontSize: 80)),
                ),
                const SizedBox(height: 24),
                Text(
                  'Your class is ready!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Share this code with your students',
                  style: TextStyle(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Large code display
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: AppTheme.glassCard(isDark: isDark),
                  child: Column(
                    children: [
                      Text(
                        widget.classCode,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                          color: isDark ? Colors.white : AppTheme.violet,
                          fontFamily: 'monospace', // Monospace helps with code legibility
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Class: ${widget.className}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),

                // Two action buttons
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        label: const Text('Copy Code'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white24 : Colors.black12,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusSm,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _shareCode,
                        icon: const Icon(Icons.ios_share_rounded, size: 20),
                        label: const Text('Share Code'),
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white24 : Colors.black12,
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusSm,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),
                
                // Continue Button — always enabled now that the share gate
                // is removed (BUG O4).
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: AppTheme.borderRadiusMd,
                      boxShadow: AppTheme.shadowGlow(AppTheme.violet),
                    ),
                    child: FilledButton(
                      onPressed: _onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppTheme.borderRadiusMd,
                        ),
                      ),
                      child: const Text(
                        'Continue to Dashboard →',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
