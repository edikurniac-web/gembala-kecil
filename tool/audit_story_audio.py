"""Local word-timestamp audit of the supplied narration. No upload."""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SIBLING = Path(r"C:\Users\LOQ\Documents\app anak")
sys.path.insert(0, str(SIBLING / ".whisperdeps"))
sys.path.insert(0, str(SIBLING / ".tooldeps"))

from faster_whisper import WhisperModel

MODEL = Path(
    r"C:\Users\LOQ\.cache\huggingface\hub\models--Systran--faster-whisper-small"
    r"\snapshots\536b0662742c02347bc0e980a01041f333bce120"
)
SOURCE = ROOT / "assets" / "story" / "yesus-berjalan-di-atas-air.mp3"
OUTPUT = ROOT / "audit" / "story_audio_asr.tsv"


def main() -> None:
    model = WhisperModel(str(MODEL), device="cpu", compute_type="int8")
    segments, info = model.transcribe(
        str(SOURCE), language="id", beam_size=5, word_timestamps=True,
        vad_filter=False, condition_on_previous_text=False,
    )
    rows = [f"# language={info.language}\tduration={info.duration:.3f}"]
    for segment in segments:
        rows.append(f"SEG\t{segment.start:.3f}\t{segment.end:.3f}\t{segment.text.strip()}")
        for word in segment.words or ():
            rows.append(f"WORD\t{word.start:.3f}\t{word.end:.3f}\t{word.word.strip()}")
    OUTPUT.parent.mkdir(exist_ok=True)
    OUTPUT.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT} ({len(rows)} rows)")


if __name__ == "__main__":
    main()
