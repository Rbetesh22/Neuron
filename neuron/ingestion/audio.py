"""Audio ingester — transcribes voice memos and audio files using faster-whisper."""
from datetime import datetime
from pathlib import Path

from .base import Document, _h

AUDIO_EXTS = {".m4a", ".mp3", ".wav", ".aiff", ".aif", ".caf"}


class AudioIngester:
    def ingest(self, directory: str | Path, source: str = "voice_memo") -> list[Document]:
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            raise ImportError("Install faster-whisper: pip install faster-whisper")

        directory = Path(directory).expanduser()
        if not directory.exists():
            raise FileNotFoundError(f"Directory not found: {directory}")

        model = WhisperModel("base", device="cpu")
        docs: list[Document] = []

        audio_files = sorted(
            (p for p in directory.rglob("*") if p.suffix.lower() in AUDIO_EXTS),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )

        for file in audio_files:
            print(f"  {file.name}...")
            try:
                segments, _ = model.transcribe(str(file))
                text = " ".join(seg.text for seg in segments).strip()
            except Exception:
                continue

            if len(text) < 20:
                continue  # silence or noise

            date_str = datetime.fromtimestamp(file.stat().st_mtime).date().isoformat()
            doc_id = f"audio_{_h(str(file.resolve()))}"

            docs.append(Document(
                id=doc_id,
                content=text,
                source=source,
                title=file.stem,
                metadata={"date": date_str, "filename": file.name},
            ))

        return docs
