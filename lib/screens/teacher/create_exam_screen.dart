import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/exam_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/exam_service.dart';
import '../../theme/app_theme.dart';

class CreateExamScreen extends ConsumerStatefulWidget {
  const CreateExamScreen({super.key});

  @override
  ConsumerState<CreateExamScreen> createState() => _CreateExamScreenState();
}

class _CreateExamScreenState extends ConsumerState<CreateExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  int _questionCount = 20;
  int _perQuestionSeconds = 30;
  int _totalMinutes = 15;

  List<Map<String, dynamic>> _collections = <Map<String, dynamic>>[];
  String? _selectedCollectionId;
  List<Map<String, dynamic>> _units = <Map<String, dynamic>>[];
  final Set<String> _selectedUnitIds = <String>{};
  int _selectedWordCount = 0;

  bool _loadingCollections = true;
  bool _loadingUnits = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCollections() async {
    try {
      final rows = await Supabase.instance.client
          .from('collections')
          .select('id, title')
          .order('title');
      if (!mounted) return;
      setState(() {
        _collections = (rows as List).cast<Map<String, dynamic>>();
        _loadingCollections = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCollections = false);
      _snack('Could not load collections: $e', error: true);
    }
  }

  Future<void> _loadUnits(String collectionId) async {
    setState(() {
      _loadingUnits = true;
      _units = <Map<String, dynamic>>[];
      _selectedUnitIds.clear();
      _selectedWordCount = 0;
    });
    try {
      final rows = await Supabase.instance.client
          .from('units')
          .select('id, title, unit_number, word_count')
          .eq('collection_id', collectionId)
          .order('unit_number');
      if (!mounted) return;
      setState(() {
        _units = (rows as List).cast<Map<String, dynamic>>();
        _loadingUnits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingUnits = false);
      _snack('Could not load units: $e', error: true);
    }
  }

  void _toggleUnit(Map<String, dynamic> unit) {
    final id = unit['id'].toString();
    setState(() {
      if (_selectedUnitIds.contains(id)) {
        _selectedUnitIds.remove(id);
        _selectedWordCount -= (unit['word_count'] as num?)?.toInt() ?? 0;
      } else {
        _selectedUnitIds.add(id);
        _selectedWordCount += (unit['word_count'] as num?)?.toInt() ?? 0;
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedUnitIds.isEmpty) {
      _snack('Pick at least one unit', error: true);
      return;
    }
    if (_selectedWordCount < _questionCount) {
      _snack(
        'Selected units only contain $_selectedWordCount words — '
        'lower the question count or pick more units.',
        error: true,
      );
      return;
    }

    final profile = ref.read(profileProvider);
    if (profile == null || profile.classCode == null) {
      _snack('You must have a class to create an exam', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      final words = await ExamService.fetchWordsForUnits(
        _selectedUnitIds.toList(),
      );
      if (words.length < _questionCount) {
        throw Exception(
          'Only ${words.length} words have translations — lower the question count.',
        );
      }

      final sessionId = await ExamService.createExam(
        classCode: profile.classCode!,
        title: _titleCtrl.text.trim(),
        bookIds: <String>[if (_selectedCollectionId != null) _selectedCollectionId!],
        unitIds: _selectedUnitIds.toList(),
        questionCount: _questionCount,
        perQuestionSeconds: _perQuestionSeconds,
        totalSeconds: _totalMinutes * 60,
        words: words,
      );
      ref.invalidate(teacherExamSessionsProvider);
      if (!mounted) return;
      context.pushReplacement('/teacher/exams/$sessionId/lobby');
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _selectAllUnits() {
    setState(() {
      _selectedUnitIds.clear();
      var total = 0;
      for (final u in _units) {
        _selectedUnitIds.add(u['id'].toString());
        total += (u['word_count'] as num?)?.toInt() ?? 0;
      }
      _selectedWordCount = total;
    });
  }

  void _clearUnits() {
    setState(() {
      _selectedUnitIds.clear();
      _selectedWordCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New exam'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loadingCollections
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _buildTitleCard(isDark),
                  const SizedBox(height: 14),
                  _buildContentCard(isDark),
                  const SizedBox(height: 14),
                  _buildTimingCard(isDark),
                  const SizedBox(height: 14),
                  _buildStatusCard(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─── Cards ─────────────────────────────────────────────────────────

  Widget _buildTitleCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('EXAM TITLE'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              hintText: 'e.g. Unit 3–5 mid-term',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
            ),
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            textInputAction: TextInputAction.next,
            validator: (v) => (v == null || v.trim().length < 3)
                ? 'At least 3 characters'
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(bool isDark) {
    return Container(
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _sectionLabel('CONTENT'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCollectionDropdown(),
          ),
          if (_selectedCollectionId != null) ...[
            const SizedBox(height: 4),
            _buildUnitsSection(isDark),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildTimingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: _cardDecoration(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('TIMING'),
          const SizedBox(height: 10),
          _buildStepperRow(
            icon: Icons.help_outline_rounded,
            label: 'Questions',
            value: _questionCount,
            min: 1,
            max: 100,
            suffix: '',
            onChanged: (v) => setState(() => _questionCount = v),
          ),
          const Divider(height: 22),
          _buildStepperRow(
            icon: Icons.timer_outlined,
            label: 'Per question',
            value: _perQuestionSeconds,
            min: 5,
            max: 300,
            step: 5,
            suffix: 's',
            onChanged: (v) => setState(() => _perQuestionSeconds = v),
          ),
          const Divider(height: 22),
          _buildStepperRow(
            icon: Icons.hourglass_bottom_rounded,
            label: 'Total time',
            value: _totalMinutes,
            min: 1,
            max: 120,
            suffix: ' min',
            onChanged: (v) => setState(() => _totalMinutes = v),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final hasUnits = _selectedUnitIds.isNotEmpty;
    final enoughWords = _selectedWordCount >= _questionCount;

    if (!hasUnits) {
      return _statusTile(
        icon: Icons.info_outline_rounded,
        color: Colors.blueGrey,
        title: 'Pick some units',
        subtitle:
            'Choose at least one unit above so the exam has words to draw from.',
      );
    }
    if (!enoughWords) {
      return _statusTile(
        icon: Icons.warning_amber_rounded,
        color: AppTheme.amber,
        title: 'Not enough words',
        subtitle:
            'Selected units have $_selectedWordCount words, but the exam asks for $_questionCount questions. Lower the count or pick more units.',
      );
    }
    final unitsWord = _selectedUnitIds.length == 1 ? 'unit' : 'units';
    return _statusTile(
      icon: Icons.check_circle_rounded,
      color: AppTheme.success,
      title: 'Ready to create',
      subtitle:
          '$_questionCount questions drawn from $_selectedWordCount words · '
          '${_selectedUnitIds.length} $unitsWord · '
          '${_perQuestionSeconds}s each · $_totalMinutes min total.',
    );
  }

  Widget _buildBottomBar() {
    final enabled = !_submitting && _selectedUnitIds.isNotEmpty;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor:
                enabled ? AppTheme.violet : Colors.grey.withValues(alpha: 0.3),
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: enabled ? _submit : null,
          icon: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, color: Colors.white, size: 22),
          label: Text(
            _submitting ? 'Creating…' : 'Create exam',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Sub-widgets ───────────────────────────────────────────────────

  Widget _buildCollectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCollectionId,
      decoration: InputDecoration(
        labelText: 'Book / Collection',
        border: OutlineInputBorder(borderRadius: AppTheme.borderRadiusSm),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadiusSm,
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppTheme.borderRadiusSm,
          borderSide: const BorderSide(color: AppTheme.violet, width: 1.5),
        ),
      ),
      items: _collections
          .map((c) => DropdownMenuItem(
                value: c['id'].toString(),
                child: Text(c['title'].toString()),
              ))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        setState(() => _selectedCollectionId = v);
        _loadUnits(v);
      },
      validator: (v) => v == null ? 'Pick a collection' : null,
    );
  }

  Widget _buildUnitsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row: Units label + Select all / Clear
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              const Text('Units',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              if (_units.isNotEmpty) ...[
                TextButton(
                  onPressed:
                      _selectedUnitIds.length == _units.length ? null : _selectAllUnits,
                  child: const Text('Select all',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: _selectedUnitIds.isEmpty ? null : _clearUnits,
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Clear',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
        if (_loadingUnits)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_units.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text('No units in this collection yet.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ..._units.map((u) => _buildUnitTile(u, isDark)),
        // Running selection pill (only when something picked)
        if (_selectedUnitIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.violet.withValues(alpha: 0.12),
              borderRadius: AppTheme.borderRadiusSm,
            ),
            child: Row(
              children: [
                const Icon(Icons.library_books_rounded,
                    color: AppTheme.violet, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_selectedUnitIds.length} ${_selectedUnitIds.length == 1 ? 'unit' : 'units'} · '
                    '$_selectedWordCount words available',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.violet),
                  ),
                ),
              ],
            ),
          )
        else
          const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildUnitTile(Map<String, dynamic> u, bool isDark) {
    final id = u['id'].toString();
    final selected = _selectedUnitIds.contains(id);
    final unitNumber = u['unit_number']?.toString() ?? '';
    final rawTitle = (u['title'] ?? '').toString();
    // Drop the ugly "Unit 1: Unit 1" duplication. If the title is just
    // "Unit N" (or blank), show only the unit number; otherwise show both.
    final isRedundant = rawTitle.isEmpty ||
        rawTitle.toLowerCase() == 'unit $unitNumber'.toLowerCase();
    final display =
        isRedundant ? 'Unit $unitNumber' : 'Unit $unitNumber · $rawTitle';
    final wordCount = (u['word_count'] as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggleUnit(u),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleUnit(u),
                  activeColor: AppTheme.violet,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  display,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$wordCount words',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required String label,
    required int value,
    required int min,
    required int max,
    required String suffix,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.violet),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        _stepperButton(
          icon: Icons.remove_rounded,
          enabled: value > min,
          onTap: () => onChanged((value - step).clamp(min, max)),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '$value$suffix',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        _stepperButton(
          icon: Icons.add_rounded,
          enabled: value < max,
          onTap: () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.violet.withValues(alpha: 0.14)
              : Colors.grey.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.violet : Colors.grey,
        ),
      ),
    );
  }

  // ─── Shared styling ────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Colors.grey.shade500,
        ),
      );

  BoxDecoration _cardDecoration(bool isDark) => BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      );

  Widget _statusTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppTheme.borderRadiusMd,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 14)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 12, color: color.withValues(alpha: 0.9))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
