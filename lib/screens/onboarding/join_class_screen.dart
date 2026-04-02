import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/profile_provider.dart';
import '../../theme/app_theme.dart';

/// Optional class join screen during onboarding.
///
/// Student enters a 6-character code from their teacher.
/// Can be skipped — goes directly to the PIN setup screen.
/// After joining, shows a competitive rank reveal dialog.
class JoinClassScreen extends ConsumerStatefulWidget {
  const JoinClassScreen({super.key});

  @override
  ConsumerState<JoinClassScreen> createState() => _JoinClassScreenState();
}

class _JoinClassScreenState extends ConsumerState<JoinClassScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;
  String? _className;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _joinClass() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;

      // Verify the code exists
      final classData = await supabase
          .from('classes')
          .select()
          .eq('code', code)
          .maybeSingle();

      if (classData == null) {
        setState(() {
          _errorMessage = 'Invalid class code. Check with your teacher.';
          _submitting = false;
        });
        return;
      }

      // Update profile with class code
      final profile = ref.read(profileProvider);
      if (profile != null) {
        await supabase
            .from('profiles')
            .update({'class_code': code}).eq('id', profile.id);
        await ref.read(profileProvider.notifier).setClassCode(code);
      }

      setState(() {
        _className = classData['class_name'] as String;
      });

      // Show rank reveal before navigating
      if (mounted && profile != null) {
        await _showRankReveal(code, profile.username);
      }

      if (mounted) {
        context.go('/onboarding/pin');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error. Try again.';
          _submitting = false;
        });
      }
    }
  }

  /// Fetches the class leaderboard, finds the user's rank, and shows
  /// a competitive rank reveal dialog.
  Future<void> _showRankReveal(String classCode, String myUsername) async {
    try {
      final classmates = await Supabase.instance.client
          .from('profiles')
          .select('username, xp')
          .eq('class_code', classCode)
          .order('xp', ascending: false)
          .limit(50);

      final board = List<Map<String, dynamic>>.from(classmates);
      if (board.isEmpty) return;

      // Find my rank (1-indexed)
      int myRank = board.length;
      String? rivalName;
      for (int i = 0; i < board.length; i++) {
        if (board[i]['username'] == myUsername) {
          myRank = i + 1;
          if (i > 0) {
            rivalName = board[i - 1]['username'] as String?;
          }
          break;
        }
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _RankRevealDialog(
          rank: myRank,
          totalClassmates: board.length,
          rivalName: rivalName,
          className: _className ?? 'your class',
        ),
      );
    } catch (_) {
      // Silently skip rank reveal on error — not critical
    }
  }

  void _skip() {
    context.go('/onboarding/pin');
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: AppTheme.borderRadiusMd,
                  ),
                  child: const Icon(Icons.group_add_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 24),
                Text(
                  'Join a class',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Do you have a class code from your teacher?',
                  style: TextStyle(
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    fontSize: 15,
                  ),
                ),
              const SizedBox(height: 40),
              if (_className != null)
                // Success state
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: isDark ? 0.1 : 0.06),
                    borderRadius: AppTheme.borderRadiusMd,
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome to $_className!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You\'re in. Let\'s go! 🚀',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ENG7B',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.4),
                      letterSpacing: 8,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 24),
                    errorText: _errorMessage,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _submitting ? null : _joinClass,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Join'),
                  ),
                ),
              ],
              const Spacer(),
              if (_className == null)
                Center(
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip for now',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.colorScheme.onSurfaceVariant,
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

// ─── Rank Reveal Dialog ──────────────────────────────────────────────

/// Animated dialog shown after joining a class during onboarding.
/// Displays the user's rank and the name of the classmate just ahead.
class _RankRevealDialog extends StatefulWidget {
  final int rank;
  final int totalClassmates;
  final String? rivalName;
  final String className;

  const _RankRevealDialog({
    required this.rank,
    required this.totalClassmates,
    required this.rivalName,
    required this.className,
  });

  @override
  State<_RankRevealDialog> createState() => _RankRevealDialogState();
}

class _RankRevealDialogState extends State<_RankRevealDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirst = widget.rank == 1;

    final rankEmoji = switch (widget.rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '🏅',
    };

    String rivalLine = '';
    if (widget.rivalName != null && !isFirst) {
      rivalLine =
          '${widget.rivalName} is just ahead at #${widget.rank - 1}.\nCan you beat them? 💪';
    } else if (isFirst) {
      rivalLine = 'You\'re already at the top!\nKeep it up! 🔥';
    } else {
      rivalLine = 'Start playing to climb the ranks! 🚀';
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rankEmoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 16),
              Text(
                'You\'re #${widget.rank}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'in ${widget.className}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${widget.totalClassmates} classmates',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  rivalLine,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Let\'s Go! 🚀',
                    style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
