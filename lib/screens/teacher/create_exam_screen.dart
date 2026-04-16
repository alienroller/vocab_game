import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('New exam')),
      body: _loadingCollections
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Exam title',
                      hintText: 'e.g. Unit 3–5 mid-term',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'At least 3 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader('Content'),
                  _buildCollectionDropdown(),
                  const SizedBox(height: 8),
                  _buildUnitPicker(isDark),
                  const SizedBox(height: 20),
                  _sectionHeader('Timing'),
                  _buildNumericField(
                    label: 'Questions',
                    value: _questionCount,
                    min: 1,
                    max: 100,
                    onChanged: (v) => setState(() => _questionCount = v),
                  ),
                  _buildNumericField(
                    label: 'Seconds per question',
                    value: _perQuestionSeconds,
                    min: 5,
                    max: 300,
                    onChanged: (v) => setState(() => _perQuestionSeconds = v),
                  ),
                  _buildNumericField(
                    label: 'Total time (minutes)',
                    value: _totalMinutes,
                    min: 1,
                    max: 120,
                    onChanged: (v) => setState(() => _totalMinutes = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Create exam',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionHeader(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 10),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _buildCollectionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCollectionId,
      decoration: const InputDecoration(
        labelText: 'Book / Collection',
        border: OutlineInputBorder(),
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

  Widget _buildUnitPicker(bool isDark) {
    if (_selectedCollectionId == null) {
      return const SizedBox.shrink();
    }
    if (_loadingUnits) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_units.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('No units in this collection yet.',
            style: TextStyle(color: Colors.grey)),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1)),
        borderRadius: AppTheme.borderRadiusSm,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                const Text('Units',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const Spacer(),
                Text(
                  '${_selectedUnitIds.length} selected  •  $_selectedWordCount words',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._units.map((u) => CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  'Unit ${u['unit_number'] ?? ''}: ${u['title']}',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: Text('${u['word_count'] ?? 0} words',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                value: _selectedUnitIds.contains(u['id'].toString()),
                onChanged: (_) => _toggleUnit(u),
                activeColor: AppTheme.violet,
              )),
        ],
      ),
    );
  }

  Widget _buildNumericField({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Min $min, max $max',
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) {
          final n = int.tryParse(v ?? '');
          if (n == null) return 'Enter a number';
          if (n < min || n > max) return 'Between $min and $max';
          return null;
        },
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n >= min && n <= max) onChanged(n);
        },
      ),
    );
  }
}
