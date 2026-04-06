import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vocab_provider.dart';
import '../services/dictionary_service.dart';
import '../theme/app_theme.dart';

String transliterateCyrillicToLatin(String text) {
  const Map<String, String> map = {
    'А': 'A', 'а': 'a', 'Б': 'B', 'б': 'b', 'В': 'V', 'в': 'v', 'Г': 'G', 'г': 'g', 
    'Д': 'D', 'д': 'd', 'Е': 'E', 'е': 'e', 'Ё': 'Yo', 'ё': 'yo', 'Ж': 'J', 'ж': 'j', 
    'З': 'Z', 'з': 'z', 'И': 'I', 'и': 'i', 'Й': 'Y', 'й': 'y', 'К': 'K', 'к': 'k', 
    'Л': 'L', 'л': 'l', 'М': 'M', 'м': 'm', 'Н': 'N', 'н': 'n', 'О': 'O', 'о': 'o', 
    'П': 'P', 'п': 'p', 'Р': 'R', 'р': 'r', 'С': 'S', 'с': 's', 'Т': 'T', 'т': 't', 
    'У': 'U', 'у': 'u', 'Ф': 'F', 'ф': 'f', 'Х': 'X', 'х': 'x', 'Ц': 'Ts', 'ц': 'ts', 
    'Ч': 'Ch', 'ч': 'ch', 'Ш': 'Sh', 'ш': 'sh', 'Щ': 'Sh', 'щ': 'sh', 
    'Ъ': '\'', 'ъ': '\'', 'Ы': 'I', 'ы': 'i', 'Ь': '', 'ь': '', 'Э': 'E', 'э': 'e', 
    'Ю': 'Yu', 'ю': 'yu', 'Я': 'Ya', 'я': 'ya',
    'Ў': 'O\'', 'ў': 'o\'', 'Қ': 'Q', 'қ': 'q', 'Ғ': 'G\'', 'ғ': 'g\'', 'Ҳ': 'H', 'ҳ': 'h'
  };

  String result = text;
  map.forEach((c, l) {
    result = result.replaceAll(c, l);
  });
  return result;
}

/// Search Screen that allows users to lookup English words and receive
/// Uzbek translations from the MyMemory API, with options to add to their game.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  bool _isLoading = false;
  String? _errorMsg;
  String _currentQuery = '';
  String? _translatedText;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search bar when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery == _currentQuery) return;

    if (cleanQuery.length < 2) {
      if (mounted) {
        setState(() {
          _currentQuery = cleanQuery;
          _translatedText = null;
          _errorMsg = null;
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _currentQuery = cleanQuery;
      _isLoading = true;
      _errorMsg = null;
      _translatedText = null;
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(cleanQuery, isSubmit: false);
    });
  }

  Future<void> _performSearch(String query, {bool isSubmit = false}) async {
    if (!mounted) return;

    try {
      final entry = await DictionaryService().lookup(query, allowFallback: isSubmit);
      if (!mounted) return;

      if (entry != null && entry.uzbek.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _translatedText = transliterateCyrillicToLatin(entry.uzbek).toLowerCase();
          _errorMsg = null;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = isSubmit ? 'Word not found in dictionary' : 'Online search required';
          _translatedText = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Library error: $e';
          _translatedText = null;
        });
      }
    }
  }

  void _addWordToGame() {
    final vocabList = ref.read(vocabProvider);
    final exists = vocabList.any((v) => v.english.toLowerCase() == _currentQuery);

    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Already in your list',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.amber,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_translatedText != null && _currentQuery.isNotEmpty) {
      ref.read(vocabProvider.notifier).addVocab(
            _currentQuery,
            _translatedText!,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Word added! 🎉',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      _searchCtrl.clear();
      _onSearchChanged('');
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final vocabList = ref.watch(vocabProvider);
    final alreadyExists =
        vocabList.any((v) => v.english.toLowerCase() == _currentQuery);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Search Dictionary',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            )),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Search Input Field
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E2140)
                        : Colors.white,
                    borderRadius: AppTheme.borderRadiusLg,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: AppTheme.shadowMedium,
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _focusNode,
                    onChanged: _onSearchChanged,
                    onSubmitted: (val) {
                      final cleanQuery = val.trim().toLowerCase();
                      if (cleanQuery.length >= 2) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();
                        setState(() { _isLoading = true; _errorMsg = null; _translatedText = null; });
                        _performSearch(cleanQuery, isSubmit: true);
                      }
                    },
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Type an English word...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 28),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // States: Initial, Loading, Error, Data
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (_currentQuery.length < 2) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.travel_explore_rounded,
                                size: 64,
                                color: (isDark
                                        ? Colors.white
                                        : Colors.black)
                                    .withValues(alpha: 0.1),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Find words to add to your game',
                                style: TextStyle(
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      if (_isLoading) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (_errorMsg != null) {
                        final isOnlineReq = _errorMsg == 'Online search required';
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOnlineReq ? Icons.travel_explore_rounded : Icons.error_outline_rounded,
                                size: 48,
                                color: isOnlineReq 
                                    ? (isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.5))
                                    : AppTheme.error.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isOnlineReq ? 'Press search on keyboard or tap below' : _errorMsg!,
                                style: TextStyle(
                                  color: isOnlineReq 
                                      ? (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)
                                      : AppTheme.error,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isOnlineReq || _errorMsg == 'Word not found in dictionary') ...[
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() { _isLoading = true; _errorMsg = null; _translatedText = null; });
                                    _performSearch(_currentQuery, isSubmit: true);
                                  },
                                  icon: const Icon(Icons.public_rounded),
                                  label: const Text('Search Web'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.violet,
                                    side: BorderSide(color: AppTheme.violet.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      if (_translatedText != null) {
                        return ListView(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.glassCard(isDark: isDark).copyWith(
                                border: Border.all(
                                  color: AppTheme.violet.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'English',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _currentQuery,
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Uzbek',
                                    style: TextStyle(
                                      color: AppTheme.violet,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _translatedText!,
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.violet,
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton.icon(
                                      onPressed: alreadyExists ? null : _addWordToGame,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.violet,
                                        disabledBackgroundColor: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.1),
                                        disabledForegroundColor: isDark
                                            ? Colors.white.withValues(alpha: 0.3)
                                            : Colors.black.withValues(alpha: 0.3),
                                      ),
                                      icon: Icon(alreadyExists
                                          ? Icons.check_circle_rounded
                                          : Icons.add_rounded),
                                      label: Text(
                                        alreadyExists
                                            ? 'Already in your list'
                                            : 'Add to Game',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
