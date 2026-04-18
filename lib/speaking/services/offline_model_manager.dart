import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Progress callback for long-running downloads/extractions.
typedef ProgressCallback = void Function(double fraction, String phase);

/// Manifest describing a downloadable ASR model bundle.
///
/// Streaming Zipformer models ship as a `.tar.bz2` containing a folder with
/// encoder/decoder/joiner ONNX files plus `tokens.txt`. We point at the
/// folder once extraction finishes so the recognizer can load the files.
class OfflineModelSpec {
  final String id;
  final String displayName;
  final String description;
  final String downloadUrl;
  final int approxDownloadMB;
  final String encoderFileName;
  final String decoderFileName;
  final String joinerFileName;
  final String tokensFileName;

  const OfflineModelSpec({
    required this.id,
    required this.displayName,
    required this.description,
    required this.downloadUrl,
    required this.approxDownloadMB,
    required this.encoderFileName,
    required this.decoderFileName,
    required this.joinerFileName,
    required this.tokensFileName,
  });
}

/// Resolved on-disk paths for a downloaded model.
class OfflineModelPaths {
  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;

  const OfflineModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });
}

/// Handles first-run download, extraction, verification, and lookup of
/// Sherpa-ONNX ASR models.
///
/// Models are stored under `<app support>/sherpa_models/<spec.id>/...`.
class OfflineModelManager {
  static final OfflineModelManager _instance = OfflineModelManager._();
  factory OfflineModelManager() => _instance;
  OfflineModelManager._();

  /// Default English streaming Zipformer used for offline STT.
  ///
  /// Hosted by the k2-fsa team on GitHub releases. If the URL ever 404s,
  /// swap it for a mirror and bump the `id` so users re-download.
  static const defaultEnglishAsr = OfflineModelSpec(
    id: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
    displayName: 'English streaming Zipformer (2023-06-26)',
    description: 'On-device English ASR. ~30 MB download, ~94 MB on disk.',
    downloadUrl:
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-26.tar.bz2',
    approxDownloadMB: 30,
    encoderFileName: 'encoder-epoch-99-avg-1.int8.onnx',
    decoderFileName: 'decoder-epoch-99-avg-1.onnx',
    joinerFileName: 'joiner-epoch-99-avg-1.int8.onnx',
    tokensFileName: 'tokens.txt',
  );

  Future<Directory> _modelsRoot() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'sherpa_models'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _modelDir(OfflineModelSpec spec) async {
    final root = await _modelsRoot();
    return Directory(p.join(root.path, spec.id));
  }

  /// True if every required file for [spec] exists on disk.
  Future<bool> isInstalled(OfflineModelSpec spec) async {
    final paths = await _resolvePaths(spec);
    if (paths == null) return false;
    for (final path in [
      paths.encoder,
      paths.decoder,
      paths.joiner,
      paths.tokens,
    ]) {
      if (!await File(path).exists()) return false;
    }
    return true;
  }

  /// True when files exist on disk for [spec] but the install is incomplete
  /// (previous download/extract failed midway). UI can use this to offer a
  /// "clean up" button.
  Future<bool> hasPartialInstall(OfflineModelSpec spec) async {
    if (await isInstalled(spec)) return false;
    final dir = await _modelDir(spec);
    if (!await dir.exists()) {
      // Also check for leftover archive files.
      final root = await _modelsRoot();
      final archive = File(p.join(root.path, '${spec.id}.tar.bz2'));
      final part = File(p.join(root.path, '${spec.id}.tar.bz2.part'));
      return await archive.exists() || await part.exists();
    }
    return true;
  }

  /// Return concrete paths, or null if the model folder is missing.
  Future<OfflineModelPaths?> resolve(OfflineModelSpec spec) async {
    if (!await isInstalled(spec)) return null;
    return _resolvePaths(spec);
  }

  Future<OfflineModelPaths?> _resolvePaths(OfflineModelSpec spec) async {
    final dir = await _modelDir(spec);
    if (!await dir.exists()) return null;

    final encoder = await _findFile(dir, spec.encoderFileName);
    final decoder = await _findFile(dir, spec.decoderFileName);
    final joiner = await _findFile(dir, spec.joinerFileName);
    final tokens = await _findFile(dir, spec.tokensFileName);
    if (encoder == null || decoder == null || joiner == null || tokens == null) {
      return null;
    }
    return OfflineModelPaths(
      encoder: encoder,
      decoder: decoder,
      joiner: joiner,
      tokens: tokens,
    );
  }

  Future<String?> _findFile(Directory root, String name) async {
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && p.basename(entity.path) == name) {
        return entity.path;
      }
    }
    return null;
  }

  /// Download [spec] and extract it into the models directory.
  ///
  /// Resilient: retries the download up to 3× on network errors, runs the
  /// bz2+tar decode in a background isolate so the UI thread never stalls,
  /// and cleans up partial state on any failure so the user can just retry.
  ///
  /// Safe to call when already installed — short-circuits. Throws with a
  /// readable message on total failure.
  Future<OfflineModelPaths> install(
    OfflineModelSpec spec, {
    ProgressCallback? onProgress,
  }) async {
    if (await isInstalled(spec)) {
      final paths = await _resolvePaths(spec);
      if (paths != null) return paths;
    }

    final root = await _modelsRoot();
    final archivePath = p.join(root.path, '${spec.id}.tar.bz2');
    final partPath = '$archivePath.part';
    final targetDir = await _modelDir(spec);

    try {
      // Wipe any previous partial state before starting.
      await _safeDelete(File(partPath));
      await _safeDelete(File(archivePath));
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }

      await _downloadWithRetry(
        spec.downloadUrl,
        partPath,
        archivePath,
        (fraction) {
          onProgress?.call(fraction * 0.75, 'Downloading');
        },
      );

      onProgress?.call(0.78, 'Extracting');
      await targetDir.create(recursive: true);

      // Extraction used to run on the main isolate — decoding ~30 MB of
      // bz2 blocked the UI for ~5–10 s on mid-range Android and tripped
      // the ANR watchdog. Run it in a background isolate instead.
      final extracted = await compute(
        _extractTarBz2IsolateEntry,
        _ExtractJob(archivePath: archivePath, outDir: targetDir.path),
      );
      if (extracted.error != null) {
        throw StateError(extracted.error!);
      }

      onProgress?.call(0.95, 'Verifying');

      // Delete the archive either way — we don't need the source bytes any more.
      await _safeDelete(File(archivePath));

      final paths = await _resolvePaths(spec);
      if (paths == null) {
        throw StateError(
            'Extraction finished but the model files are missing — the download may have been cut off. Please try again on a stable connection.');
      }

      onProgress?.call(1.0, 'Ready');
      return paths;
    } catch (e) {
      // Any failure → wipe partial state so the user can cleanly retry.
      await _safeDelete(File(partPath));
      await _safeDelete(File(archivePath));
      if (await targetDir.exists()) {
        try {
          await targetDir.delete(recursive: true);
        } catch (err) {
          if (kDebugMode) debugPrint('install cleanup failed: $err');
        }
      }
      rethrow;
    }
  }

  /// Remove an installed (or partially-installed) model and any leftover
  /// archive files. Safe to call even if nothing is on disk.
  Future<void> uninstall(OfflineModelSpec spec) async {
    final dir = await _modelDir(spec);
    if (await dir.exists()) {
      try {
        await dir.delete(recursive: true);
      } catch (e) {
        if (kDebugMode) debugPrint('uninstall: modelDir delete failed: $e');
      }
    }
    final root = await _modelsRoot();
    await _safeDelete(File(p.join(root.path, '${spec.id}.tar.bz2')));
    await _safeDelete(File(p.join(root.path, '${spec.id}.tar.bz2.part')));
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (e) {
      if (kDebugMode) debugPrint('_safeDelete(${f.path}) failed: $e');
    }
  }

  /// Download with bounded retries. Each attempt writes to `.part` and
  /// renames on success; on failure the `.part` file is discarded so the
  /// next attempt starts clean.
  Future<void> _downloadWithRetry(
    String url,
    String partPath,
    String finalPath,
    void Function(double) onProgress,
  ) async {
    const maxAttempts = 3;
    Object? lastError;
    StackTrace? lastStack;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _safeDelete(File(partPath));
        await _download(url, partPath, onProgress);
        await File(partPath).rename(finalPath);
        return;
      } catch (e, s) {
        lastError = e;
        lastStack = s;
        if (kDebugMode) {
          debugPrint('download attempt $attempt/$maxAttempts failed: $e');
        }
        await _safeDelete(File(partPath));
        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: attempt * 2));
        }
      }
    }

    // Surface a friendly message — the UI can still tack on the cause.
    Error.throwWithStackTrace(
      StateError(
        'Download failed after $maxAttempts attempts. Check your connection and try again.\n(Last error: $lastError)',
      ),
      lastStack ?? StackTrace.current,
    );
  }

  Future<void> _download(
    String url,
    String destPath,
    void Function(double) onProgress,
  ) async {
    final uri = Uri.parse(url);
    final client = http.Client();
    try {
      final req = http.Request('GET', uri);
      final resp = await client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
            'Download failed: HTTP ${resp.statusCode}',
            uri: uri);
      }
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = File(destPath).openWrite();
      try {
        await for (final chunk in resp.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress(received / total);
        }
      } finally {
        await sink.close();
      }

      // Sanity check — GitHub's presigned URLs sometimes close the stream
      // early without throwing. A tiny file means silent truncation.
      final actual = await File(destPath).length();
      if (total > 0 && actual < total) {
        throw StateError(
            'Incomplete download: got $actual of $total bytes.');
      }
      if (actual < 1024) {
        throw StateError(
            'Suspiciously small download ($actual bytes) — likely interrupted.');
      }
    } finally {
      client.close();
    }
  }

  /// Bytes consumed on disk by [spec] (0 if not installed).
  Future<int> diskUsage(OfflineModelSpec spec) async {
    final dir = await _modelDir(spec);
    if (!await dir.exists()) return 0;
    var total = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += await entity.length();
        } catch (e) {
          if (kDebugMode) debugPrint('diskUsage: skipped ${entity.path}: $e');
        }
      }
    }
    return total;
  }
}

/// Payload for the extraction isolate. Must be simple enough for Flutter's
/// [compute] to serialize across isolate boundaries.
class _ExtractJob {
  final String archivePath;
  final String outDir;
  const _ExtractJob({required this.archivePath, required this.outDir});
}

class _ExtractResult {
  final int fileCount;
  final String? error;
  const _ExtractResult({required this.fileCount, this.error});
}

/// Top-level isolate entry point (required by [compute]).
///
/// Reads the `.tar.bz2`, decompresses, and writes every entry under
/// `outDir`. Returns an error message instead of throwing so the main
/// isolate can surface a user-friendly message.
Future<_ExtractResult> _extractTarBz2IsolateEntry(_ExtractJob job) async {
  try {
    final bytes = await File(job.archivePath).readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    var count = 0;
    for (final entry in archive) {
      final outPath = p.join(job.outDir, entry.name);
      if (entry.isFile) {
        final file = File(outPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content as List<int>);
        count++;
      } else {
        await Directory(outPath).create(recursive: true);
      }
    }
    return _ExtractResult(fileCount: count);
  } catch (e) {
    return _ExtractResult(fileCount: 0, error: 'Extraction failed: $e');
  }
}
