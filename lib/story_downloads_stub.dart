import 'catalog.dart';

class StoryDownloads {
  StoryDownloads._();
  static final instance = StoryDownloads._();
  Future<void> initialize() async {}
  bool isDownloaded(StoryBook story) => true;
  String? cachedPath(String remotePath) => null;
  Future<void> cacheCover(StoryBook story) async {}
  Future<void> cacheCovers(Iterable<StoryBook> stories) async {}
  Future<StoryBook> localStory(StoryBook story) async => story;
  Future<StoryBook> download(
    StoryBook story,
    void Function(double progress) onProgress,
  ) async =>
      story;
}
