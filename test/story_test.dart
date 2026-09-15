import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gembala_kecil/catalog.dart';
import 'package:gembala_kecil/story.dart';

void main() {
  test('all 12 pages have a square illustration and text', () {
    expect(storyPages, hasLength(12));
    for (var i = 0; i < storyPages.length; i++) {
      expect(storyPages[i].image, contains('halaman_${i + 1}.png'));
      expect(storyPages[i].words, isNotEmpty);
    }
  });

  test('timeline reaches every page and highlights every word', () {
    final timeline = StoryTimeline(120000);
    expect(timeline.starts, hasLength(13));
    for (var page = 0; page < storyPages.length; page++) {
      expect(timeline.pageAt(timeline.starts[page]), page);
      expect(timeline.wordAt(page, timeline.starts[page]), 0);
      expect(timeline.wordAt(page, timeline.starts[page + 1] - 1),
          storyPages[page].words.length - 1);
    }
  });

  test('audited MP3 timestamps cover the published text', () {
    final data = jsonDecode(File('assets/story/timing.json').readAsStringSync())
        as Map<String, dynamic>;
    final timeline = StoryTimeline.fromMap(data);
    expect(timeline.durationMs, 101760);
    expect(timeline.wordStarts, hasLength(storyPages.length));
    for (var page = 0; page < storyPages.length; page++) {
      expect(
          timeline.wordStarts[page], hasLength(storyPages[page].words.length));
      expect(timeline.pageAt(timeline.starts[page]), page);
      expect(timeline.wordAt(page, timeline.wordStarts[page].first), 0);
      expect(timeline.wordAt(page, timeline.wordStarts[page].last),
          storyPages[page].words.length - 1);
    }
  });

  test('catalog accepts uploaded stories and verses', () {
    final uploaded = StoryBook.fromMap({
      'id': 'contoh',
      'title': 'Contoh',
      'reference': 'Mazmur 1:1',
      'summary': 'Pesan',
      'cover': 'assets/content/contoh-cover.png',
      'audio': null,
      'timingAsset': null,
      'isFree': true,
      'pages': [
        {'text': 'Satu halaman.', 'image': 'assets/content/contoh-page-1.png'}
      ],
    });
    final verse = VerseItem.fromMap({
      'id': 'ayat-contoh',
      'title': 'Ayat Contoh',
      'reference': 'Mazmur 1:1',
      'text': 'Kasih Tuhan.',
      'image': null,
      'audio': null,
    });
    expect(uploaded.pages.single.words, ['Satu', 'halaman.']);
    expect(verse.text, 'Kasih Tuhan.');
  });

  test('cloud catalog paths resolve through the content worker', () {
    expect(
      resolveContentPath(
        'assets/content/contoh-cover.png',
        remote: true,
      ),
      '$contentApiBase/v1/assets/contoh-cover.png',
    );
    expect(
      resolveContentPath('assets/story/COVER.png', remote: true),
      'assets/story/COVER.png',
    );
  });
}
