import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/vocab.dart';
import '../services/storage_service.dart';

class VocabNotifier extends StateNotifier<List<Vocab>> {
  VocabNotifier() : super([]) {
    _loadData();
  }

  final _uuid = const Uuid();

  Future<void> _loadData() async {
    // If it's the first time, load sample data
    await StorageService.addSampleData();
    state = StorageService.getAllVocab();
  }

  void addVocab(String english, String uzbek) {
    if (english.trim().isEmpty || uzbek.trim().isEmpty) return;
    
    final newVocab = Vocab(
      id: _uuid.v4(),
      english: english.trim(),
      uzbek: uzbek.trim(),
    );
    
    state = [...state, newVocab];
    _saveToStorage();
  }

  void updateVocab(String id, String english, String uzbek) {
    if (english.trim().isEmpty || uzbek.trim().isEmpty) return;

    state = [
      for (final vocab in state)
        if (vocab.id == id)
          vocab.copyWith(english: english.trim(), uzbek: uzbek.trim())
        else
          vocab
    ];
    _saveToStorage();
  }

  void deleteVocab(String id) {
    state = state.where((vocab) => vocab.id != id).toList();
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    await StorageService.saveAllVocab(state);
  }
}

final vocabProvider = StateNotifierProvider<VocabNotifier, List<Vocab>>((ref) {
  return VocabNotifier();
});
