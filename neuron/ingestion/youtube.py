import re
import httpx
from .base import Document


def _extract_video_id(url: str) -> str | None:
    patterns = [
        r"youtube\.com/watch\?v=([^&]+)",
        r"youtu\.be/([^?]+)",
        r"youtube\.com/embed/([^?]+)",
    ]
    for pattern in patterns:
        m = re.search(pattern, url)
        if m:
            return m.group(1)
    return None


def _get_title(video_id: str) -> str:
    try:
        r = httpx.get(
            f"https://www.youtube.com/watch?v={video_id}",
            timeout=10,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        m = re.search(r"<title>(.*?) - YouTube</title>", r.text)
        return m.group(1) if m else video_id
    except Exception:
        return video_id


class YouTubeIngester:
    def ingest(self, url: str) -> list[Document]:
        from youtube_transcript_api import YouTubeTranscriptApi

        video_id = _extract_video_id(url)
        if not video_id:
            raise ValueError(f"Could not extract video ID from: {url}")

        api = YouTubeTranscriptApi()
        transcript_list = api.fetch(video_id)
        transcript = list(transcript_list)
        text = " ".join(entry.text for entry in transcript)
        title = _get_title(video_id)

        return [Document(
            id=f"youtube_{video_id}",
            content=text,
            source="youtube",
            title=f"YouTube: {title}",
            metadata={"type": "video_transcript", "url": url, "video_id": video_id},
        )]
