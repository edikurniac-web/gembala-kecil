class StoryPage {
  const StoryPage(this.text, this.image);
  final String text;
  final String image;
  List<String> get words => text.split(RegExp(r'\s+'));
}

const storyTitle = 'Yesus Berjalan di Atas Air';
const storyReference = 'Matius 14:22–33';
const storyCover = 'assets/story/COVER.png';
const storyAudio = 'story/yesus-berjalan-di-atas-air.mp3';
const storyId = 'yesus-berjalan-di-atas-air';

const storyPages = <StoryPage>[
  StoryPage(
    'Suatu sore, Yesus meminta murid-murid-Nya naik ke perahu. Mereka berlayar lebih dulu ke seberang danau.',
    'assets/story/gembala_kecil_yesus_air_halaman_1.png',
  ),
  StoryPage(
    'Yesus tinggal sendirian untuk berdoa. Hari mulai gelap, dan angin bertiup semakin kencang.',
    'assets/story/gembala_kecil_yesus_air_halaman_2.png',
  ),
  StoryPage(
    'Di tengah danau, perahu murid-murid mulai terombang-ambing. Ombak besar menghantam perahu mereka.',
    'assets/story/gembala_kecil_yesus_air_halaman_3.png',
  ),
  StoryPage(
    'Murid-murid merasa takut. Mereka berusaha mengendalikan perahu di tengah angin yang kuat.',
    'assets/story/gembala_kecil_yesus_air_halaman_4.png',
  ),
  StoryPage(
    'Tiba-tiba, mereka melihat seseorang berjalan di atas air. “Lihat! Ada seseorang di sana!” seru mereka.',
    'assets/story/gembala_kecil_yesus_air_halaman_5.png',
  ),
  StoryPage(
    'Mereka semakin takut karena tidak tahu siapa yang datang. Namun kemudian mereka mendengar suara yang mereka kenal.',
    'assets/story/gembala_kecil_yesus_air_halaman_6.png',
  ),
  StoryPage(
    '“Tenanglah. Ini Aku,” kata Yesus. “Jangan takut.”',
    'assets/story/gembala_kecil_yesus_air_halaman_7.png',
  ),
  StoryPage(
    'Petrus berkata, “Tuhan, kalau itu benar Engkau, suruhlah aku datang kepada-Mu.” Yesus menjawab, “Datanglah.”',
    'assets/story/gembala_kecil_yesus_air_halaman_8.png',
  ),
  StoryPage(
    'Petrus turun dari perahu dan mulai berjalan di atas air. Selama ia melihat kepada Yesus, ia terus melangkah.',
    'assets/story/gembala_kecil_yesus_air_halaman_9.png',
  ),
  StoryPage(
    'Tetapi Petrus melihat angin dan ombak yang besar. Ia menjadi takut dan mulai tenggelam.',
    'assets/story/gembala_kecil_yesus_air_halaman_10.png',
  ),
  StoryPage(
    '“Tuhan, tolong aku!” teriak Petrus. Yesus segera mengulurkan tangan dan memegangnya.',
    'assets/story/gembala_kecil_yesus_air_halaman_11.png',
  ),
  StoryPage(
    'Saat Yesus dan Petrus naik ke perahu, angin pun berhenti. Pesan hari ini, ya: Ketika kita merasa takut, kita dapat selalu percaya bahwa Yesus ada untuk menolong kita.',
    'assets/story/gembala_kecil_yesus_air_halaman_12.png',
  ),
];

// Uses audited audio timestamps when present. The proportional constructor is
// retained only as a fallback for new content awaiting an alignment audit.
class StoryTimeline {
  StoryTimeline(this.durationMs, {this.pages = storyPages}) {
    final weights = pages
        .map(
          (page) =>
              page.words.fold<double>(0, (sum, word) => sum + _weight(word)),
        )
        .toList();
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    var elapsed = 0.0;
    for (final weight in weights) {
      starts.add((durationMs * elapsed / total).round());
      elapsed += weight;
    }
    starts.add(durationMs);
  }
  StoryTimeline.fromMap(Map<String, dynamic> data, {this.pages = storyPages})
      : durationMs = data['audioDurationMs'] as int {
    final timedPages = (data['pages'] as List).cast<Map<String, dynamic>>();
    if (timedPages.length != pages.length) {
      throw const FormatException('Timing page count does not match story');
    }
    for (var index = 0; index < timedPages.length; index++) {
      final page = timedPages[index];
      starts.add(page['startMs'] as int);
      final words = (page['wordStartsMs'] as List).cast<int>();
      if (words.length != pages[index].words.length) {
        throw FormatException(
            'Timing word count mismatch on page ${index + 1}');
      }
      wordStarts.add(words);
    }
    starts.add(timedPages.last['endMs'] as int);
  }
  final int durationMs;
  final List<StoryPage> pages;
  final List<int> starts = [];
  final List<List<int>> wordStarts = [];
  static double _weight(String word) =>
      (word.length.clamp(2, 11) * 0.25) +
      (RegExp(r'[.!?]').hasMatch(word) ? 1.6 : 1);
  int pageAt(int ms) {
    for (var i = starts.length - 2; i >= 0; i--) {
      if (ms >= starts[i]) return i;
    }
    return 0;
  }

  int wordAt(int page, int ms) {
    if (ms < starts[page] || ms >= starts[page + 1]) return -1;
    if (wordStarts.isNotEmpty) {
      final words = wordStarts[page];
      for (var index = words.length - 1; index >= 0; index--) {
        if (ms >= words[index]) return index;
      }
      return -1;
    }
    final words = pages[page].words;
    final total = words.fold<double>(0, (sum, word) => sum + _weight(word));
    final target =
        ((ms - starts[page]) / (starts[page + 1] - starts[page])) * total;
    var elapsed = 0.0;
    for (var i = 0; i < words.length; i++) {
      elapsed += _weight(words[i]);
      if (target < elapsed) return i;
    }
    return words.length - 1;
  }
}
