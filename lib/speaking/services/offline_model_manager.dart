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
  /// Safe to call when already installed — it short-circuits. Throws on
  /// network or extraction failure; callers should show a retry UI.
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
    final targetDir = await _modelDir(spec);

    await _download(spec.downloadUrl, archivePath, (fraction) {
      onProgress?.call(fraction * 0.8, 'Downloading');
    });

    onProgress?.call(0.82, 'Extracting');
    if (await targetDir.exists()) await targetDir.delete(recursive: true);
    await targetDir.create(recursive: true);
    await _extractTarBz2(archivePath, targetDir.path);
    onProgress?.call(0.98, 'Verifying');

    try {
      await File(archivePath).delete();
    } catch (_) {}

    final paths = await _resolvePaths(spec);
    if (paths == null) {
      throw StateError(
          'Model extracted but required files were not found: ${spec.id}');
    }
    onProgress?.call(1.0, 'Ready');
    return paths;
  }

  /// Remove an installed model.
  Future<void> uninstall(OfflineModelSpec spec) async {
    final dir = await _modelDir(spec);
    if (await dir.exists()) await dir.delete(recursive: true);
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
      if (resp.statusCode != 200) {
        throw HttpException('Download failed: HTTP ${resp.statusCode}', uri: uri);
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
    } finally {
      client.close();
    }
  }

  Future<void> _extractTarBz2(String archivePath, String outDir) async {
    final bytes = await File(archivePath).readAsBytes();
    final tarBytes = BZip2Decoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);
    for (final entry in archive) {
      final outPath = p.join(outDir, entry.name);
      if (entry.isFile) {
        final file = File(outPath);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.content as List<int>);
      } else {
        await Directory(outPath).create(recursive: true);
      }
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
