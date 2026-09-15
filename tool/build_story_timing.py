"""Align locally audited ASR words with the published 12-page text."""

from difflib import SequenceMatcher
import json
from pathlib import Path
import re
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "lib" / "story.dart"
ASR = ROOT / "audit" / "story_audio_asr.tsv"
OUTPUT = ROOT / "assets" / "story" / "timing.json"
REPORT = ROOT / "audit" / "story_audio_report.md"

# Page changes heard at the start of each first sentence in the ASR audit.
PAGE_STARTS = [0, 8960, 16960, 25440, 32180, 41800, 49940, 55340,
               64660, 73340, 80760, 88140, 101760]


def clean(word: str) -> str:
    word = unicodedata.normalize("NFKD", word.lower())
    word = "".join(c for c in word if c.isalnum())
    return word.replace("jesus", "yesus")


def align(expected: list[str], heard: list[tuple[int, str]]):
    n, m = len(expected), len(heard)
    dp = [[0.0] * (m + 1) for _ in range(n + 1)]
    move = [[""] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        dp[i][0], move[i][0] = i * .72, "skip-text"
    for j in range(1, m + 1):
        dp[0][j], move[0][j] = j * .72, "skip-audio"
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            similarity = SequenceMatcher(None, clean(expected[i - 1]), clean(heard[j - 1][1])).ratio()
            choices = [
                (dp[i - 1][j - 1] + (1 - similarity) * 1.5, "match"),
                (dp[i - 1][j] + .72, "skip-text"),
                (dp[i][j - 1] + .72, "skip-audio"),
            ]
            dp[i][j], move[i][j] = min(choices)
    i, j = n, m
    matches = []
    while i or j:
        step = move[i][j]
        if step == "match":
            matches.append((i - 1, j - 1))
            i -= 1
            j -= 1
        elif step == "skip-text":
            i -= 1
        else:
            j -= 1
    return list(reversed(matches))


def main():
    texts = re.findall(r"StoryPage\(\s*'([^']+)'", SOURCE.read_text(encoding="utf-8"))
    if len(texts) != 12:
        raise ValueError(f"Expected 12 pages, found {len(texts)}")
    heard = []
    for line in ASR.read_text(encoding="utf-8").splitlines():
        fields = line.split("\t")
        if fields[0] != "WORD":
            continue
        time, word = round(float(fields[1]) * 1000), fields[3]
        if word.startswith("-") and heard:
            old_time, old_word = heard.pop()
            heard.append((old_time, old_word + word))
        else:
            heard.append((time, word))

    pages, report = [], [
        "# Audio narration audit", "",
        "Source: supplied MP3; local faster-whisper-small word timestamps. Duration: 101.760 seconds.",
        "", "## Findings", "",
        "- The earlier highlight used a proportional word-length clock. It ignored sentence pauses, so highlighting drifted from the spoken narration.",
        "- The reader now uses observed page and word start times from the MP3. No audio is sent to a remote service.",
        "- The narration audibly includes *ya* after *Pesan hari ini* near 93.96s; the displayed final page now includes that word. The original supplied manuscript is preserved.",
        "- ASR writes *Jesus* in two places; these were normalized to *Yesus* for text alignment.",
        "", "| Page | Audio interval | Text words | ASR words | Strong matches |",
        "|---:|---:|---:|---:|---:|",
    ]
    issues = []
    for page in range(12):
        start, end = PAGE_STARTS[page:page + 2]
        expected = texts[page].split()
        page_heard = [(time, word) for time, word in heard if start <= time < end]
        pairs = align(expected, page_heard)
        starts = [None] * len(expected)
        strong = 0
        used = set()
        for text_index, audio_index in pairs:
            similarity = SequenceMatcher(None, clean(expected[text_index]), clean(page_heard[audio_index][1])).ratio()
            if similarity >= .58:
                starts[text_index] = page_heard[audio_index][0]
                used.add(audio_index)
                if similarity >= .85:
                    strong += 1
            else:
                issues.append(f"Page {page + 1}: text `{expected[text_index]}` vs ASR `{page_heard[audio_index][1]}` near {page_heard[audio_index][0] / 1000:.2f}s")
        for index, value in enumerate(starts):
            if value is not None:
                continue
            left = next((k for k in range(index - 1, -1, -1) if starts[k] is not None), None)
            right = next((k for k in range(index + 1, len(starts)) if starts[k] is not None), None)
            if left is None and right is None:
                value = start + (end - start) * index / max(1, len(starts))
            elif left is None:
                value = start + (starts[right] - start) * (index + 1) / (right + 1)
            elif right is None:
                value = starts[left] + (end - starts[left]) * (index - left) / (len(starts) - left)
            else:
                value = starts[left] + (starts[right] - starts[left]) * (index - left) / (right - left)
            starts[index] = round(value)
            issues.append(f"Page {page + 1}: interpolated `{expected[index]}` at {value / 1000:.2f}s")
        for index in range(1, len(starts)):
            starts[index] = max(starts[index], starts[index - 1])
        for index, (time, word) in enumerate(page_heard):
            if index not in used:
                issues.append(f"Page {page + 1}: ASR-only `{word}` near {time / 1000:.2f}s")
        pages.append({"startMs": start, "endMs": end, "wordStartsMs": starts})
        report.append(f"| {page + 1} | {start / 1000:.2f}–{end / 1000:.2f}s | {len(expected)} | {len(page_heard)} | {strong} |")

    report.extend(["", "## Items requiring a human listen", "", *[f"- {issue}" for issue in issues]])
    OUTPUT.write_text(json.dumps({"version": 1, "audioDurationMs": PAGE_STARTS[-1], "pages": pages}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    REPORT.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}; {len(issues)} audit notes in {REPORT}")


if __name__ == "__main__":
    main()
