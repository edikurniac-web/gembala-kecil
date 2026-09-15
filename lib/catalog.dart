import 'dart:convert';

import 'package:flutter/services.dart';

import 'story.dart';

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

  factory StoryBook.fromMap(Map<String, dynamic> value) => StoryBook(
        id: value['id'] as String,
        title: value['title'] as String,
        reference: value['reference'] as String,
        summary: value['summary'] as String? ?? '',
        cover: value['cover'] as String,
        audio: value['audio'] as String?,
        timingAsset: value['timingAsset'] as String?,
        isFree: value['isFree'] as bool? ?? true,
        pages: (value['pages'] as List).map((raw) {
          final page = raw as Map<String, dynamic>;
          return StoryPage(page['text'] as String, page['image'] as String);
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
  factory VerseItem.fromMap(Map<String, dynamic> value) => VerseItem(
        id: value['id'] as String,
        title: value['title'] as String,
        reference: value['reference'] as String,
        text: value['text'] as String,
        image: value['image'] as String?,
        audio: value['audio'] as String?,
      );
}

class ContentCatalog {
  const ContentCatalog(this.stories, this.verses);
  final List<StoryBook> stories;
  final List<VerseItem> verses;
  static Future<ContentCatalog> load() async {
    final data =
        jsonDecode(await rootBundle.loadString('assets/content/catalog.json'))
            as Map<String, dynamic>;
    if (data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported content catalog');
    }
    return ContentCatalog(
      [
        StoryBook.builtIn,
        ...(data['stories'] as List)
            .map((x) => StoryBook.fromMap(x as Map<String, dynamic>))
      ],
      (data['verses'] as List)
          .map((x) => VerseItem.fromMap(x as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
