import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'story.dart';

class StoryDownloads {
  StoryDownloads._();
  static final instance = StoryDownloads._();
  late Directory root;
  late Directory covers;

  Future<void> initialize() async {
    root =
        Directory('${(await getApplicationSupportDirectory()).path}/stories');
    covers = Directory('${root.path}/covers');
    await covers.create(recursive: true);
  }

  bool _remote(String path) => path.startsWith('http');
  String _name(String url) =>
      Uri.decodeComponent(Uri.parse(url).pathSegments.last);
  List<String> _urls(StoryBook story) => <String>{
        story.cover,
        if (story.audio != null) story.audio!,
        if (story.timingAsset != null) story.timingAsset!,
        for (final page in story.pages) page.image,
      }.where(_remote).toList(growable: false);

  String? cachedPath(String path) {
    if (!_remote(path)) return null;
    final file = File('${covers.path}/${_name(path)}');
    return file.existsSync() ? file.path : null;
  }

  bool isDownloaded(StoryBook story) {
    if (!_remote(story.cover)) return true;
    final marker = File('${root.path}/${story.id}/complete.json');
    if (!marker.existsSync()) return false;
    try {
      final data =
          jsonDecode(marker.readAsStringSync()) as Map<String, dynamic>;
      return jsonEncode((data['urls'] as List).cast<String>()) ==
          jsonEncode(_urls(story));
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetch(
    String url,
    File destination, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    final response = await http.get(Uri.parse(url)).timeout(timeout);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('Download gagal (${response.statusCode})',
          uri: Uri.parse(url));
    }
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(response.bodyBytes, flush: true);
  }

  Future<void> cacheCover(StoryBook story) async {
    if (!_remote(story.cover) || cachedPath(story.cover) != null) return;
    final target = File('${covers.path}/${_name(story.cover)}');
    final temporary = File('${target.path}.part');
    try {
      await _fetch(story.cover, temporary, timeout: const Duration(seconds: 6));
      await temporary.rename(target.path);
    } catch (_) {
      if (temporary.existsSync()) await temporary.delete();
    }
  }

  Future<void> cacheCovers(Iterable<StoryBook> stories) async {
    for (final story in stories) {
      await cacheCover(story);
    }
  }

  StoryBook _localized(StoryBook story, Directory directory) {
    String local(String path) =>
        _remote(path) ? '${directory.path}/${_name(path)}' : path;
    return StoryBook(
      id: story.id,
      title: story.title,
      reference: story.reference,
      summary: story.summary,
      cover: local(story.cover),
      audio: story.audio == null ? null : local(story.audio!),
      timingAsset: story.timingAsset == null ? null : local(story.timingAsset!),
      isFree: story.isFree,
      pages: [
        for (final page in story.pages) StoryPage(page.text, local(page.image))
      ],
    );
  }

  Future<StoryBook> localStory(StoryBook story) async {
    if (!_remote(story.cover)) return story;
    final directory = Directory('${root.path}/${story.id}');
    if (!File('${directory.path}/complete.json').existsSync()) {
      throw StateError('Cerita belum selesai diunduh.');
    }
    return _localized(story, directory);
  }

  Future<StoryBook> download(
    StoryBook story,
    void Function(double progress) onProgress,
  ) async {
    if (isDownloaded(story)) return localStory(story);
    final target = Directory('${root.path}/${story.id}');
    final temporary = Directory('${root.path}/${story.id}.part');
    if (temporary.existsSync()) await temporary.delete(recursive: true);
    await temporary.create(recursive: true);
    final urls = _urls(story);
    try {
      for (var index = 0; index < urls.length; index++) {
        await _fetch(
            urls[index], File('${temporary.path}/${_name(urls[index])}'));
        onProgress((index + 1) / urls.length);
      }
      await File('${temporary.path}/complete.json').writeAsString(jsonEncode({
        'id': story.id,
        'assets': urls.length,
        'urls': urls,
        'completedAt': DateTime.now().toIso8601String(),
      }));
      if (target.existsSync()) await target.delete(recursive: true);
      await temporary.rename(target.path);
      return _localized(story, target);
    } catch (_) {
      if (temporary.existsSync()) await temporary.delete(recursive: true);
      rethrow;
    }
  }
}
