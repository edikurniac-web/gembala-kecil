import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'story.dart';

const contentApiBase = 'https://api-gembalakecil.duniapinta.my.id';

String resolveContentPath(String path, {required bool remote}) {
  if (!remote || !path.startsWith('assets/content/')) return path;
  final key = path.substring('assets/content/'.length);
  return '$contentApiBase/v1/assets/${Uri.encodeComponent(key)}';
}

class StoryBook {
  const StoryBook(
      {required this.id,
      required this.title,
      required this.reference,
      required this.summary,
      required this.cover,
      required this.pages,
      this.audio,
      this.timingAsset,
      this.isFree = true});
  final String id, title, reference, summary, cover;
  final String? audio, timingAsset;
  final bool isFree;
  final List<StoryPage> pages;

  static const builtIn = StoryBook(
    id: storyId,
    title: storyTitle,
    reference: storyReference,
    summary: 'Ketika kita merasa takut, kita dapat tetap percaya kepada Yesus.',
    cover: storyCover,
    audio: 'assets/$storyAudio',
    timingAsset: 'assets/story/timing.json',
    pages: storyPages,
  );

  factory StoryBook.fromMap(Map<String, dynamic> value,
          {bool remote = false}) =>
      StoryBook(
        id: value['id'] as String,
        title: value['title'] as String,
        reference: value['reference'] as String,
        summary: value['summary'] as String? ?? '',
        cover: resolveContentPath(value['cover'] as String, remote: remote),
        audio: value['audio'] == null
            ? null
            : resolveContentPath(value['audio'] as String, remote: remote),
        timingAsset: value['timingAsset'] == null
            ? null
            : resolveContentPath(
                value['timingAsset'] as String,
                remote: remote,
              ),
        isFree: value['isFree'] as bool? ?? true,
        pages: (value['pages'] as List).map((raw) {
          final page = raw as Map<String, dynamic>;
          return StoryPage(
            page['text'] as String,
            resolveContentPath(page['image'] as String, remote: remote),
          );
        }).toList(growable: false),
      );
}

class VerseItem {
  const VerseItem(
      {required this.id,
      required this.title,
      required this.reference,
      required this.text,
      this.image,
      this.audio});
  final String id, title, reference, text;
  final String? image, audio;
  factory VerseItem.fromMap(Map<String, dynamic> value,
          {bool remote = false}) =>
      VerseItem(
        id: value['id'] as String,
        title: value['title'] as String,
        reference: value['reference'] as String,
        text: value['text'] as String,
        image: value['image'] == null
            ? null
            : resolveContentPath(value['image'] as String, remote: remote),
        audio: value['audio'] == null
            ? null
            : resolveContentPath(value['audio'] as String, remote: remote),
      );
}

class ContentCatalog {
  const ContentCatalog(this.stories, this.verses);
  final List<StoryBook> stories;
  final List<VerseItem> verses;
  static Future<ContentCatalog> load() async {
    final bundledData = jsonDecode(
      await rootBundle.loadString('assets/content/catalog.json'),
    ) as Map<String, dynamic>;
    if (bundledData['schemaVersion'] != 1) {
      throw const FormatException('Unsupported bundled content catalog');
    }
    final bundledStories =
        (bundledData['stories'] as List).cast<Map<String, dynamic>>();
    final bundledVerses =
        (bundledData['verses'] as List).cast<Map<String, dynamic>>();
    final daud = StoryBook.fromMap(
      bundledStories.firstWhere((story) => story['id'] == 'daud-dan-goliat'),
    );
    final bundledVerse = VerseItem.fromMap(bundledVerses.first);

    List<StoryBook> remoteStories = const [];
    List<VerseItem> remoteVerses = const [];
    try {
      final response = await http
          .get(Uri.parse('$contentApiBase/v1/catalog'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw StateError('Cloud catalog returned ${response.statusCode}.');
      }
      final remoteData = jsonDecode(response.body) as Map<String, dynamic>;
      if (remoteData['schemaVersion'] != 1) {
        throw const FormatException('Unsupported cloud content catalog');
      }
      remoteStories = (remoteData['stories'] as List)
          .map((value) => StoryBook.fromMap(
                value as Map<String, dynamic>,
                remote: true,
              ))
          .toList(growable: false);
      remoteVerses = (remoteData['verses'] as List)
          .map((value) => VerseItem.fromMap(
                value as Map<String, dynamic>,
                remote: true,
              ))
          .toList(growable: false);
    } catch (_) {
      // Daud and the first memory verse deliberately remain available offline.
    }

    final byId = <String, StoryBook>{
      for (final story in remoteStories) story.id: story,
      daud.id: daud,
    };
    const releaseOrder = [
      'daud-dan-goliat',
      'tuhan-menciptakan-dunia',
      'bahtera-nuh-yang-besar',
      'yunus-dan-ikan-besar',
      'daniel-di-kandang-singa',
      'orang-samaria-yang-baik-hati',
      'lima-roti-dan-dua-ikan',
      'zakheus-bertemu-yesus',
      'yesus-menyembuhkan-orang-lumpuh',
      'yesus-berjalan-di-atas-air',
      'petrus-mendapat-banyak-ikan',
      'elia-diberi-makan-burung-gagak',
    ];
    final orderedStories = [
      for (final id in releaseOrder)
        if (byId[id] != null) byId[id]!,
      for (final story in remoteStories)
        if (!releaseOrder.contains(story.id)) story,
    ];
    final versesById = <String, VerseItem>{
      for (final verse in remoteVerses) verse.id: verse,
      bundledVerse.id: bundledVerse,
    };
    return ContentCatalog(
      orderedStories,
      versesById.values.toList(growable: false),
    );
  }
}

StoryBook storyOfTheDay(List<StoryBook> stories, DateTime now) {
  if (stories.isEmpty) return StoryBook.builtIn;
  final localDay = DateTime(now.year, now.month, now.day);
  final dayNumber =
      localDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  return stories[dayNumber % stories.length];
}
