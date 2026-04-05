import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/vocab_provider.dart';
import '../theme/app_theme.dart';

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
      _performSearch(cleanQuery);
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    try {
      // 1. Verify word existence using Free Dictionary API
      // We check each word in the query (in case they type short phrases)
      final words = query.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final dictFutures = words.map((w) => http
          .get(Uri.parse('https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(w)}'))
          .timeout(const Duration(seconds: 5)));

      // 2. Prepare Translation fetch
      final memUri = Uri.parse(
          'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(query)}&langpair=en|uz');
      final memFuture = http.get(memUri).timeout(const Duration(seconds: 10));

      final results = await Future.wait([
        Future.wait(dictFutures),
        memFuture,
      ]);

      if (!mounted) return;

      final dictResponses = results[0] as List<http.Response>;
      final memResponse = results[1] as http.Response;

      // Check for dictionary 404s (typos)
      bool hasTypo = false;
      for (final resp in dictResponses) {
        if (resp.statusCode == 404) {
          hasTypo = true;
          break;
        }
      }

      if (hasTypo) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Word not recognized. Did you spell it correctly?';
          _translatedText = null;
        });
        return;
      }

      if (memResponse.statusCode == 200) {
        final data = jsonDecode(memResponse.body);
        final translatedText = data['responseData']?['translatedText']
            ?.toString()
            .replaceAll('&#39;', "'")
            .replaceAll('&quot;', '"')
            .replaceAll('&amp;', '&');

        if (translatedText != null && translatedText.isNotEmpty) {
          // Check if MyMemory just returned the english phrase unchanged
          if (translatedText.toLowerCase() == query.toLowerCase()) {
            setState(() {
              _isLoading = false;
              _errorMsg = 'Translation unavailable';
              _translatedText = null;
            });
          } else {
            setState(() {
              _isLoading = false;
              _translatedText = translatedText.toLowerCase();
              _errorMsg = null;
            });
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMsg = 'No translation found';
            _translatedText = null;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Error fetching translation';
          _translatedText = null;
        });
      }
    } on SocketException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Check your connection';
          _translatedText = null;
        });
      }
    } on TimeoutException catch (_) {
      if (mounted) {
        // If dictionary timeouts, it might be safer to let it pass or say timed out.
        setState(() {
          _isLoading = false;
          _errorMsg = 'Request timed out';
          _translatedText = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Something went wrong';
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
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppTheme.error.withValues(alpha: 0.7),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _errorMsg!,
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
