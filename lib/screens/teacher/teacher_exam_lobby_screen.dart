import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/exam_participant.dart';
import '../../providers/exam_provider.dart';
import '../../theme/app_theme.dart';

class TeacherExamLobbyScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const TeacherExamLobbyScreen({super.key, required this.sessionId});

  @override
  ConsumerState<TeacherExamLobbyScreen> createState() =>
      _TeacherExamLobbyScreenState();
}

class _TeacherExamLobbyScreenState
    extends ConsumerState<TeacherExamLobbyScreen> {
  // Session countdown
  Timer? _sessionTimer;
  int _sessionSecondsLeft = 0;

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _syncSessionTimer(ExamLobbyState lobby) {
    final session = lobby.session;
    if (session == null || !session.isInProgress || session.startedAt == null) {
      _sessionTimer?.cancel();
      return;
    }
    final elapsed =
        DateTime.now().toUtc().difference(session.startedAt!).inSeconds;
    final left = session.totalSeconds - elapsed;
    if (left != _sessionSecondsLeft) {
      _sessionSecondsLeft = left > 0 ? left : 0;
    }
    if (_sessionTimer == null || !_sessionTimer!.isActive) {
      _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _sessionSecondsLeft--;
          if (_sessionSecondsLeft <= 0) {
            _sessionSecondsLeft = 0;
            _sessionTimer?.cancel();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lobby = ref.watch(examLobbyProvider(widget.sessionId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Keep session timer in sync.
    if (lobby.session?.isInProgress == true) {
      _syncSessionTimer(lobby);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lobby.session?.title ?? 'Exam lobby'),
        actions: [
          if (lobby.session?.isInProgress == true) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _sessionSecondsLeft <= 60
                        ? Colors.redAccent.withValues(alpha: 0.15)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _formatTime(_sessionSecondsLeft),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color:
                          _sessionSecondsLeft <= 60 ? Colors.redAccent : null,
                    ),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => _endNow(context, ref),
              child: const Text('End now',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
          if (lobby.session?.isLobby == true)
            TextButton(
              onPressed: () => _cancel(context, ref),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      body: lobby.loading
          ? const Center(child: CircularProgressIndicator())
          : lobby.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Error: ${lobby.error}',
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : _body(context, ref, lobby, isDark),
      bottomNavigationBar: _bottomBar(context, ref, lobby),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    ExamLobbyState lobby,
    bool isDark,
  ) {
    final session = lobby.session;
    if (session == null) {
      return const Center(child: Text('Session not found.'));
    }

    return Column(
      children: [
        _statusBanner(session, lobby, isDark),

        // Summary stats row for in_progress / completed
        if (session.isInProgress || session.isFinished)
          _statsRow(lobby, isDark),

        Expanded(
          child: lobby.participants.isEmpty
              ? const Center(child: Text('No students invited yet.'))
              : (session.isInProgress || session.isFinished)
                  ? _progressGrid(lobby, isDark)
                  : _lobbyList(lobby, isDark),
        ),
      ],
    );
  }

  Widget _statusBanner(
    dynamic session,
    ExamLobbyState lobby,
    bool isDark,
  ) {
    final status = session.status as String;
    final Color bg;
    final String text;
    final IconData icon;

    switch (status) {
      case 'lobby':
        bg = Colors.amber;
        icon = Icons.hourglass_top_rounded;
        text =
            'Waiting for students  •  ${lobby.joinedCount} / ${lobby.totalInvited} joined';
      case 'in_progress':
        bg = Colors.green;
        icon = Icons.play_circle_rounded;
        text =
            'Exam is live  •  ${lobby.completedCount} / ${lobby.joinedCount} finished';
      case 'completed':
        bg = Colors.blueGrey;
        icon = Icons.check_circle_rounded;
        text = 'Completed  •  ${lobby.completedCount} students';
      case 'cancelled':
        bg = Colors.redAccent;
        icon = Icons.cancel_rounded;
        text = 'Cancelled';
      default:
        bg = Colors.grey;
        icon = Icons.info;
        text = status;
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Row(
        children: [
          Icon(icon, color: bg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13, color: bg)),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(ExamLobbyState lobby, bool isDark) {
    final session = lobby.session!;
    final totalQ = session.questionCount;

    // Calculate class averages from progress data.
    final active = lobby.progress.where((p) =>
        p.status == 'in_progress' || p.status == 'completed');
    final avgCorrect = active.isEmpty
        ? 0.0
        : active.map((p) => p.correct).reduce((a, b) => a + b) /
            active.length;
    final avgAnswered = active.isEmpty
        ? 0.0
        : active.map((p) => p.answered).reduce((a, b) => a + b) /
            active.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _stat('Avg progress',
              '${avgAnswered.toStringAsFixed(1)} / $totalQ'),
          _stat('Avg score', avgCorrect.toStringAsFixed(1)),
          _stat('Finished',
              '${lobby.completedCount} / ${lobby.joinedCount}'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      );

  /// Lobby phase — simple join-status list.
  Widget _lobbyList(ExamLobbyState lobby, bool isDark) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: lobby.participants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) =>
          _ParticipantTile(p: lobby.participants[i], isDark: isDark),
    );
  }

  /// In-progress / completed — live progress grid.
  Widget _progressGrid(ExamLobbyState lobby, bool isDark) {
    final totalQ = lobby.session?.questionCount ?? 1;

    // Sort: in_progress first (by answered desc), then completed, then absent.
    final sorted = List<StudentProgress>.from(lobby.progress)
      ..sort((a, b) {
        final order = {'in_progress': 0, 'completed': 1, 'joined': 0};
        final aO = order[a.status] ?? 2;
        final bO = order[b.status] ?? 2;
        if (aO != bO) return aO.compareTo(bO);
        return b.answered.compareTo(a.answered);
      });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) =>
          _ProgressTile(p: sorted[i], totalQ: totalQ, isDark: isDark),
    );
  }

  Widget? _bottomBar(
      BuildContext context, WidgetRef ref, ExamLobbyState lobby) {
    final session = lobby.session;
    if (session == null) return null;

    if (session.isLobby) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _start(context, ref),
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            label: const Text('Start exam',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
        ),
      );
    }

    if (session.isFinished) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.violet,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () =>
                context.push('/teacher/exams/${widget.sessionId}/results'),
            child: const Text('View results',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    return null;
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start exam?'),
        content: const Text(
            'All joined students will begin immediately. '
            'Late-joiners can still enter while the timer runs.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(examLobbyProvider(widget.sessionId).notifier)
          .startExam();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to start: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel exam?'),
        content: const Text('This will discard the exam.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cancel exam')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(examLobbyProvider(widget.sessionId).notifier)
          .cancelExam();
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _endNow(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('End exam now?'),
        content: const Text(
            'Students who haven\'t finished will be marked as timed out.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep going')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End now')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(examLobbyProvider(widget.sessionId).notifier)
          .endExam();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ─── Tiles ───────────────────────────────────────────────────────────────────

/// Simple tile for lobby phase — shows join status.
class _ParticipantTile extends StatelessWidget {
  final ExamParticipant p;
  final bool isDark;
  const _ParticipantTile({required this.p, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final Color chipColor;
    final String chipLabel;
    switch (p.status) {
      case 'invited':
        chipColor = Colors.grey;
        chipLabel = 'Invited';
      case 'joined':
        chipColor = Colors.amber;
        chipLabel = 'Joined';
      default:
        chipColor = Colors.grey;
        chipLabel = p.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Row(
        children: [
          _avatar(p.username ?? '?'),
          const SizedBox(width: 10),
          Expanded(
            child: Text(p.username ?? p.studentId,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          _chip(chipLabel, chipColor),
        ],
      ),
    );
  }
}

/// Rich tile for in-progress / completed — shows progress bar + score.
class _ProgressTile extends StatelessWidget {
  final StudentProgress p;
  final int totalQ;
  final bool isDark;
  const _ProgressTile(
      {required this.p, required this.totalQ, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final fraction = totalQ > 0 ? (p.answered / totalQ) : 0.0;
    final pct = (fraction * 100).round();

    final Color statusColor;
    final String statusLabel;
    switch (p.status) {
      case 'in_progress':
        statusColor = Colors.blue;
        statusLabel = '$pct%';
      case 'completed':
        statusColor = Colors.green;
        statusLabel = '${p.correct}/$totalQ';
      case 'absent':
        statusColor = Colors.redAccent;
        statusLabel = 'Absent';
      case 'timed_out':
        statusColor = Colors.orange;
        statusLabel = 'Timed out';
      default:
        statusColor = Colors.grey;
        statusLabel = p.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(p.username),
              const SizedBox(width: 10),
              Expanded(
                child: Text(p.username,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              if (p.status == 'in_progress' || p.status == 'completed')
                Text(
                  '${p.correct} / ${p.answered}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              const SizedBox(width: 8),
              _chip(statusLabel, statusColor),
            ],
          ),
          if (p.status == 'in_progress') ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppTheme.violet.withValues(alpha: 0.1),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.violet),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Shared helpers ──────────────────────────────────────────────────────────

Widget _avatar(String name) => CircleAvatar(
      radius: 18,
      backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontWeight: FontWeight.w700, color: AppTheme.violet),
      ),
    );

Widget _chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
