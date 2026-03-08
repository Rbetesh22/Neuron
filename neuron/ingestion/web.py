import trafilatura
from .base import Document, _h


class WebIngester:
    def ingest(self, url: str) -> list[Document]:
        downloaded = trafilatura.fetch_url(url)
        if not downloaded:
            raise ValueError(f"Could not fetch: {url}")

        content = trafilatura.extract(
            downloaded,
            include_comments=False,
            include_tables=True,
            no_fallback=False,
        )
        if not content or len(content) < 100:
            raise ValueError(f"Could not extract readable content from: {url}")

        meta = trafilatura.extract_metadata(downloaded)
        title = (meta.title if meta and meta.title else None) or url
        author = meta.author if meta and meta.author else None
        date = meta.date if meta and meta.date else None

        return [Document(
            id=f"web_{_h(url)}",
            content=content,
            source="web",
            title=title,
            metadata={
                "type": "article",
                "url": url,
                "author": author or "",
                "date": date or "",
            },
        )]
