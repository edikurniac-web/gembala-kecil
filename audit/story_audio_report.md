# Audio narration audit

Source: supplied MP3; local faster-whisper-small word timestamps. Duration: 101.760 seconds.

## Findings

- The earlier highlight used a proportional word-length clock. It ignored sentence pauses, so highlighting drifted from the spoken narration.
- The reader now uses observed page and word start times from the MP3. No audio is sent to a remote service.
- The narration audibly includes *ya* after *Pesan hari ini* near 93.96s; the displayed final page now includes that word. The original supplied manuscript is preserved.
- ASR writes *Jesus* in two places; these were normalized to *Yesus* for text alignment.

| Page | Audio interval | Text words | ASR words | Strong matches |
|---:|---:|---:|---:|---:|
| 1 | 0.00–8.96s | 15 | 15 | 15 |
| 2 | 8.96–16.96s | 13 | 13 | 13 |
| 3 | 16.96–25.44s | 12 | 13 | 11 |
| 4 | 25.44–32.18s | 12 | 12 | 12 |
| 5 | 32.18–41.80s | 15 | 14 | 13 |
| 6 | 41.80–49.94s | 17 | 17 | 17 |
| 7 | 49.94–55.34s | 7 | 7 | 7 |
| 8 | 55.34–64.66s | 14 | 14 | 14 |
| 9 | 64.66–73.34s | 18 | 18 | 18 |
| 10 | 73.34–80.76s | 14 | 14 | 14 |
| 11 | 80.76–88.14s | 11 | 11 | 11 |
| 12 | 88.14–101.76s | 28 | 28 | 28 |

## Items requiring a human listen

- Page 3: ASR-only `ambing.` near 20.58s
- Page 5: interpolated `di` at 39.80s
