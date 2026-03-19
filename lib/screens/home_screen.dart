import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vocab.dart';
import '../providers/vocab_provider.dart';
import '../widgets/vocab_tile.dart';
import 'game_selection_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _englishController = TextEditingController();
  final _uzbekController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _englishController.dispose();
    _uzbekController.dispose();
    super.dispose();
  }

  void _addWord() {
    if (_formKey.currentState!.validate()) {
      ref.read(vocabProvider.notifier).addVocab(
            _englishController.text,
            _uzbekController.text,
          );
      _englishController.clear();
      _uzbekController.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _showEditDialog(Vocab vocab) {
    final engCtrl = TextEditingController(text: vocab.english);
    final uzCtrl = TextEditingController(text: vocab.uzbek);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Word'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: engCtrl,
              decoration: const InputDecoration(labelText: 'English'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uzCtrl,
              decoration: const InputDecoration(labelText: 'Uzbek'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(vocabProvider.notifier).updateVocab(
                    vocab.id,
                    engCtrl.text,
                    uzCtrl.text,
                  );
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vocabList = ref.watch(vocabProvider);
    final theme = Theme.of(context);
    final canPlay = vocabList.length >= 4;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VocabGame Builder', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Add Word Form
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Form(
              key: _formKey,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _englishController,
                          decoration: InputDecoration(
                            hintText: 'English word',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _uzbekController,
                          decoration: InputDecoration(
                            hintText: 'Uzbek translation',
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          onFieldSubmitted: (_) => _addWord(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _addWord,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 104,
                      width: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.add,
                        color: theme.colorScheme.onPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // List Title
          Padding(
            padding: const EdgeInsets.all(16.0).copyWith(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Vocabulary',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${vocabList.length} words',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Vocab List
          Expanded(
            child: vocabList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_rounded,
                          size: 64,
                          color: theme.colorScheme.surfaceContainerHighest,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No vocabulary yet.',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Add words to start playing games!',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: vocabList.length,
                    itemBuilder: (context, index) {
                      final vocab = vocabList[index];
                      // Use a key to ensure proper animation when deleting
                      return VocabTile(
                        key: ValueKey(vocab.id),
                        vocab: vocab,
                        onDelete: () {
                          ref.read(vocabProvider.notifier).deleteVocab(vocab.id);
                        },
                        onEdit: () => _showEditDialog(vocab),
                      );
                    },
                  ),
          ),
          
          // Progress bar indicating how close to 4 words we are
          if (!canPlay)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: vocabList.length / 4,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add ${4 - vocabList.length} more words to play games',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: canPlay
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GameSelectionScreen()),
                );
              },
              icon: const Icon(Icons.gamepad),
              label: const Text('Start Games', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
