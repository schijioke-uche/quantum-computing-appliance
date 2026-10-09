#!/usr/bin/env python3
"""BQCA quantum knowledgebase index reader and recursive research tool.

The canonical index is maintained at:
  .bob/quantum-tools/knowlegebase/bqca_quantum_kb_index.txt

The tool reads operator-approved seed URLs, ranks them against a user topic,
accesses selected sources, and drills into relevant sublinks from every seed it
successfully accesses. It emits a concise, auditable research trace rather than
copying full source pages.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import ipaddress
import json
import pathlib
import re
import socket
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from html.parser import HTMLParser
from typing import Iterable

TOOL_VERSION = "BQCA.v47-update-5"
URL_RE = re.compile(r"https?://[^\s<>\"'`]+", re.IGNORECASE)
WORD_RE = re.compile(r"[a-z0-9][a-z0-9_+.-]*", re.IGNORECASE)
STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "by", "code", "create",
    "design", "develop", "for", "from", "generate", "how", "implement",
    "in", "is", "it", "of", "on", "or", "please", "quantum", "qiskit",
    "the", "to", "use", "using", "with", "write",
}
SKIP_LINK_WORDS = {
    "about", "account", "advert", "blog", "careers", "community", "contact",
    "cookie", "facebook", "github", "instagram", "legal", "linkedin", "login",
    "logout", "news", "privacy", "register", "rss", "signin", "signup",
    "support", "terms", "twitter", "youtube",
}
PREFERRED_LINK_WORDS = {
    "algorithm", "api", "circuit", "example", "guide", "learn", "manual",
    "overview", "reference", "runtime", "stable", "tutorial",
}
SYNONYMS = {
    "vqe": {"variational", "eigensolver", "energy", "hamiltonian", "chemistry"},
    "vqc": {"variational", "classifier", "classification", "machine", "learning"},
    "qaoa": {"optimization", "maxcut", "qubo", "variational"},
    "qpe": {"phase", "estimation"},
    "qft": {"fourier", "transform"},
    "qml": {"machine", "learning", "classifier", "kernel"},
    "chemistry": {"molecule", "molecular", "hamiltonian", "energy", "electronic"},
    "physics": {"hamiltonian", "observable", "energy", "simulation"},
    "optimization": {"qaoa", "qubo", "maxcut", "optimizer"},
    "qubit": {"qubits", "circuit", "register"},
    "circuit": {"circuits", "gate", "gates", "qubit"},
}


@dataclass(frozen=True)
class IndexEntry:
    line_number: int
    context: str
    url: str


@dataclass
class Page:
    url: str
    final_url: str
    title: str
    content_type: str
    text: str
    links: list[tuple[str, str]]
    accessed_utc: str
    error: str | None = None


class HTMLExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.title_parts: list[str] = []
        self.text_parts: list[str] = []
        self.links: list[tuple[str, str]] = []
        self._skip_depth = 0
        self._in_title = False
        self._href: str | None = None
        self._anchor_parts: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        lower = tag.lower()
        if lower in {"script", "style", "noscript", "svg", "canvas"}:
            self._skip_depth += 1
            return
        if self._skip_depth:
            return
        if lower == "title":
            self._in_title = True
        if lower == "a":
            values = {key.lower(): value for key, value in attrs}
            self._href = values.get("href")
            self._anchor_parts = []
        if lower in {"p", "div", "li", "br", "h1", "h2", "h3", "h4", "tr"}:
            self.text_parts.append("\n")

    def handle_endtag(self, tag: str) -> None:
        lower = tag.lower()
        if lower in {"script", "style", "noscript", "svg", "canvas"}:
            if self._skip_depth:
                self._skip_depth -= 1
            return
        if self._skip_depth:
            return
        if lower == "title":
            self._in_title = False
        if lower == "a" and self._href:
            anchor = normalize_space(" ".join(self._anchor_parts))
            self.links.append((self._href, anchor))
            self._href = None
            self._anchor_parts = []
        if lower in {"p", "div", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.text_parts.append("\n")

    def handle_data(self, data: str) -> None:
        if self._skip_depth:
            return
        value = html.unescape(data)
        if self._in_title:
            self.title_parts.append(value)
        self.text_parts.append(value)
        if self._href is not None:
            self._anchor_parts.append(value)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_space(value: str) -> str:
    return re.sub(r"[ \t\r\f\v]+", " ", value).strip()


def normalize_page_text(value: str) -> str:
    lines = [normalize_space(line) for line in value.splitlines()]
    return "\n".join(line for line in lines if line)


def clean_url(value: str) -> str:
    return value.rstrip(".,;:!?)]}>")


def load_entries(index: pathlib.Path) -> list[IndexEntry]:
    if not index.is_file():
        raise FileNotFoundError(f"knowledgebase index not found: {index}")
    entries: list[IndexEntry] = []
    seen: set[str] = set()
    for number, raw in enumerate(index.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        for match in URL_RE.finditer(raw):
            url = clean_url(match.group(0))
            parsed = urllib.parse.urlsplit(url)
            if parsed.scheme.lower() not in {"http", "https"} or not parsed.netloc:
                continue
            if url in seen:
                continue
            seen.add(url)
            entries.append(IndexEntry(number, normalize_space(raw), url))
    return entries


def terms_for(query: str) -> set[str]:
    terms = {word.lower() for word in WORD_RE.findall(query) if word.lower() not in STOPWORDS and len(word) > 1}
    expanded = set(terms)
    for term in list(terms):
        expanded.update(SYNONYMS.get(term, set()))
    return expanded


def score(value: str, terms: set[str]) -> int:
    lower = value.lower()
    total = 0
    for term in terms:
        if term in lower:
            total += 4 if re.search(rf"\b{re.escape(term)}\b", lower) else 1
    return total


def ranked_entries(entries: list[IndexEntry], query: str, limit: int) -> list[IndexEntry]:
    terms = terms_for(query)
    ranked = sorted(entries, key=lambda item: (score(f"{item.context} {item.url}", terms), -item.line_number), reverse=True)
    positive = [entry for entry in ranked if score(f"{entry.context} {entry.url}", terms) > 0]
    return (positive or ranked)[:limit]


def ensure_url_allowed(url: str, allow_private: bool) -> None:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() not in {"http", "https"}:
        raise ValueError(f"unsupported URL scheme: {parsed.scheme}")
    host = (parsed.hostname or "").lower()
    if not host:
        raise ValueError("URL has no hostname")
    if allow_private:
        return
    if host in {"localhost", "localhost.localdomain"}:
        raise ValueError("localhost URLs require --allow-private")
    try:
        ip = ipaddress.ip_address(host)
    except ValueError:
        return
    if ip.is_private or ip.is_loopback or ip.is_link_local or ip.is_reserved:
        raise ValueError("private or local URL requires --allow-private")


def decode_body(payload: bytes, content_type: str, headers) -> str:
    charset = headers.get_content_charset() if hasattr(headers, "get_content_charset") else None
    encodings = [charset, "utf-8", "latin-1"]
    for encoding in encodings:
        if not encoding:
            continue
        try:
            return payload.decode(encoding)
        except (LookupError, UnicodeDecodeError):
            continue
    return payload.decode("utf-8", errors="replace")


def fetch_page(url: str, timeout: float, max_bytes: int, allow_private: bool) -> Page:
    ensure_url_allowed(url, allow_private)
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "BQCA-Quantum-Knowledgebase/47-update-5",
            "Accept": "text/html,text/plain,application/json,application/xml;q=0.9,*/*;q=0.2",
            "Accept-Encoding": "identity",
        },
    )
    accessed = utc_now()
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            final_url = response.geturl()
            ensure_url_allowed(final_url, allow_private)
            content_type = response.headers.get_content_type() or "application/octet-stream"
            payload = response.read(max_bytes + 1)
            if len(payload) > max_bytes:
                payload = payload[:max_bytes]
            if content_type == "application/pdf":
                return Page(url, final_url, "PDF source", content_type, "Binary PDF source; use an approved PDF reader for full analysis.", [], accessed)
            body = decode_body(payload, content_type, response.headers)
            if "html" in content_type or "xhtml" in content_type:
                parser = HTMLExtractor()
                parser.feed(body)
                title = normalize_space(" ".join(parser.title_parts)) or final_url
                text = normalize_page_text(" ".join(parser.text_parts))
                links = parser.links
            else:
                title = final_url
                text = normalize_page_text(body)
                links = []
            return Page(url, final_url, title, content_type, text, links, accessed)
    except Exception as exc:
        return Page(url, url, url, "unavailable", "", [], accessed, str(exc))


def canonical_link(base_url: str, href: str) -> str | None:
    href = html.unescape(href.strip())
    if not href or href.startswith(("#", "mailto:", "javascript:", "tel:")):
        return None
    url = urllib.parse.urljoin(base_url, href)
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme.lower() not in {"http", "https"} or not parsed.netloc:
        return None
    parsed = parsed._replace(fragment="")
    return urllib.parse.urlunsplit(parsed)


def ranked_sublinks(page: Page, query: str, limit: int, cross_domain: bool) -> list[str]:
    terms = terms_for(query)
    seed_host = (urllib.parse.urlsplit(page.final_url).hostname or "").lower()
    candidates: list[tuple[int, str]] = []
    seen: set[str] = {page.final_url.rstrip("/")}
    for href, anchor in page.links:
        url = canonical_link(page.final_url, href)
        if not url:
            continue
        normalized = url.rstrip("/")
        if normalized in seen:
            continue
        seen.add(normalized)
        parsed = urllib.parse.urlsplit(url)
        host = (parsed.hostname or "").lower()
        if not cross_domain and host != seed_host:
            continue
        combined = f"{anchor} {parsed.path} {parsed.query}".lower()
        if any(word in combined for word in SKIP_LINK_WORDS):
            continue
        value = score(combined, terms)
        value += sum(2 for word in PREFERRED_LINK_WORDS if word in combined)
        if parsed.path.lower().endswith((".png", ".jpg", ".jpeg", ".gif", ".svg", ".css", ".js", ".zip", ".tar", ".gz")):
            continue
        candidates.append((value, url))
    candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
    positive = [url for value, url in candidates if value > 0]
    ordered = positive or [url for _value, url in candidates]
    return ordered[:limit]


def excerpt(text: str, query: str, limit: int = 900) -> str:
    if not text:
        return "No extractable text was returned."
    terms = terms_for(query)
    paragraphs = [normalize_space(part) for part in re.split(r"\n+", text) if normalize_space(part)]
    ranked = sorted(paragraphs, key=lambda part: score(part, terms), reverse=True)
    selected = [part for part in ranked if score(part, terms) > 0][:3]
    if not selected:
        selected = paragraphs[:2]
    result = " ".join(selected)
    if len(result) > limit:
        result = result[: limit - 1].rstrip() + "…"
    return result or "No relevant text excerpt was available."


def write_atomic(path: pathlib.Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False, dir=path.parent, prefix=path.name + ".", suffix=".tmp") as stream:
        stream.write(text)
        temporary = pathlib.Path(stream.name)
    temporary.replace(path)


def render_trace(query: str, index: pathlib.Path, seeds: list[tuple[IndexEntry, Page, list[Page]]], errors: list[str], status: str) -> str:
    lines = [
        "# BQCA Quantum Knowledgebase Research Trace",
        "",
        f"- **Policy/tool version:** `{TOOL_VERSION}`",
        f"- **Research status:** **{status}**",
        f"- **Generated:** `{utc_now()}`",
        f"- **User topic/query:** {query}",
        f"- **Knowledgebase index:** `{index}`",
        f"- **Index SHA-256:** `{sha256(index)}`",
        f"- **Requirement:** Each accessed seed URL must be followed into at least one relevant sublink.",
        "",
        "The knowledgebase supplements IBM Bob intelligence and other approved sources. It does not override the active BQCA central policy, Qiskit version requirements, or human scientific review.",
        "",
    ]
    if errors:
        lines.extend(["## Research Gate Findings", ""])
        lines.extend(f"- {item}" for item in errors)
        lines.append("")
    for position, (entry, seed, subpages) in enumerate(seeds, 1):
        lines.extend([
            f"## Seed {position}: {seed.title}",
            "",
            f"- **Index line:** {entry.line_number}",
            f"- **Index entry:** {entry.context}",
            f"- **Seed URL:** {seed.final_url}",
            f"- **Accessed:** `{seed.accessed_utc}`",
            f"- **Content type:** `{seed.content_type}`",
        ])
        if seed.error:
            lines.append(f"- **Seed access error:** {seed.error}")
        else:
            lines.extend(["", "### Concise source evidence", "", excerpt(seed.text, query), ""])
        lines.extend(["### Drilled sublinks", ""])
        if not subpages:
            lines.append("- No relevant sublink was successfully accessed.")
        for sub_position, sub in enumerate(subpages, 1):
            lines.extend([
                f"#### Sublink {position}.{sub_position}: {sub.title}",
                "",
                f"- **URL:** {sub.final_url}",
                f"- **Accessed:** `{sub.accessed_utc}`",
                f"- **Content type:** `{sub.content_type}`",
            ])
            if sub.error:
                lines.append(f"- **Access error:** {sub.error}")
            else:
                lines.extend(["", excerpt(sub.text, query), ""])
        lines.append("")
    lines.extend([
        "## Use in BQCA Design or Code",
        "",
        "Use the traced sources to inform algorithm choice, API compatibility, circuit assumptions, Qiskit patterns, validation criteria, and implementation decisions. Verify all generated design/code against the active central policy and the installed Qiskit version. Do not present this trace as scientific proof or copy long source passages.",
        "",
    ])
    return "\n".join(lines)


def command_validate(index: pathlib.Path, as_json: bool) -> int:
    try:
        entries = load_entries(index)
    except Exception as exc:
        payload = {"status": "FAIL", "index": str(index), "error": str(exc), "url_count": 0}
        print(json.dumps(payload, indent=2) if as_json else f"BQCA_QUANTUM_KB=FAIL index={index} error={exc}", file=sys.stderr)
        return 2
    status = "PASS" if entries else "NOT_READY"
    payload = {
        "status": status,
        "index": str(index.resolve()),
        "sha256": sha256(index),
        "url_count": len(entries),
        "tool_version": TOOL_VERSION,
    }
    print(json.dumps(payload, indent=2) if as_json else f"BQCA_QUANTUM_KB={status} index={payload['index']} urls={len(entries)} sha256={payload['sha256']}")
    return 0 if entries else 3


def command_list(index: pathlib.Path, limit: int, as_json: bool) -> int:
    entries = load_entries(index)
    selected = entries[:limit]
    if as_json:
        print(json.dumps([entry.__dict__ for entry in selected], indent=2))
    else:
        for position, entry in enumerate(selected, 1):
            print(f"{position}\tline={entry.line_number}\t{entry.url}\t{entry.context}")
    return 0 if entries else 3


def command_search(index: pathlib.Path, query: str, limit: int, as_json: bool) -> int:
    entries = ranked_entries(load_entries(index), query, limit)
    if as_json:
        print(json.dumps([entry.__dict__ for entry in entries], indent=2))
    else:
        for position, entry in enumerate(entries, 1):
            print(f"{position}\tline={entry.line_number}\t{entry.url}\t{entry.context}")
    return 0 if entries else 3


def command_research(args) -> int:
    index = args.index.resolve()
    try:
        entries = load_entries(index)
    except Exception as exc:
        print(f"BQCA_QUANTUM_KB=FAIL error={exc}", file=sys.stderr)
        return 2
    if not entries:
        print(f"BQCA_QUANTUM_KB=FAIL index has no HTTP(S) URLs: {index}", file=sys.stderr)
        return 3
    selected = ranked_entries(entries, args.query, args.max_seeds)
    completed: list[tuple[IndexEntry, Page, list[Page]]] = []
    errors: list[str] = []
    successful_seeds = 0
    successful_sublinks = 0
    for entry in selected:
        seed = fetch_page(entry.url, args.timeout, args.max_bytes, args.allow_private)
        subpages: list[Page] = []
        if seed.error:
            errors.append(f"Seed URL could not be accessed: {entry.url} ({seed.error})")
        else:
            successful_seeds += 1
            candidates = ranked_sublinks(seed, args.query, args.sublinks_per_seed * 3, args.cross_domain_sublinks)
            for sublink in candidates:
                if len([page for page in subpages if not page.error]) >= args.sublinks_per_seed:
                    break
                sub = fetch_page(sublink, args.timeout, args.max_bytes, args.allow_private)
                subpages.append(sub)
                if not sub.error:
                    successful_sublinks += 1
            if not any(not page.error for page in subpages):
                errors.append(f"No relevant sublink was successfully drilled from seed: {seed.final_url}")
        completed.append((entry, seed, subpages))
    strict_ok = successful_seeds > 0 and not errors and successful_sublinks >= successful_seeds
    status = "PASS" if strict_ok or args.allow_incomplete else "FAIL"
    trace = render_trace(args.query, index, completed, errors, status)
    if args.output:
        output = args.output.resolve()
        write_atomic(output, trace)
        print(f"BQCA_QUANTUM_KB={status}")
        print(f"INDEX={index}")
        print(f"TRACE={output}")
        print(f"SEEDS_ACCESSED={successful_seeds}")
        print(f"SUBLINKS_ACCESSED={successful_sublinks}")
    else:
        print(trace)
        print(f"BQCA_QUANTUM_KB={status}", file=sys.stderr if status != "PASS" else sys.stdout)
    return 0 if status == "PASS" else 5


def build_parser() -> argparse.ArgumentParser:
    default_index = pathlib.Path(__file__).resolve().parent / "bqca_quantum_kb_index.txt"
    parser = argparse.ArgumentParser(description="BQCA quantum knowledgebase research tool")
    parser.add_argument("--index", type=pathlib.Path, default=default_index, help="Knowledgebase index path")
    sub = parser.add_subparsers(dest="command", required=True)

    validate = sub.add_parser("validate", help="Validate index presence and URL inventory")
    validate.add_argument("--json", action="store_true")

    status = sub.add_parser("status", help="Alias for validate")
    status.add_argument("--json", action="store_true")

    listing = sub.add_parser("list", help="List URL entries")
    listing.add_argument("--limit", type=int, default=100)
    listing.add_argument("--json", action="store_true")

    search = sub.add_parser("search", help="Search and rank index entries")
    search.add_argument("--query", required=True)
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--json", action="store_true")

    research = sub.add_parser("research", help="Access relevant seed URLs and drill into sublinks")
    research.add_argument("--query", required=True)
    research.add_argument("--output", type=pathlib.Path)
    research.add_argument("--max-seeds", type=int, default=3)
    research.add_argument("--sublinks-per-seed", type=int, default=1)
    research.add_argument("--timeout", type=float, default=15.0)
    research.add_argument("--max-bytes", type=int, default=2_000_000)
    research.add_argument("--allow-private", action="store_true")
    research.add_argument("--cross-domain-sublinks", action="store_true")
    research.add_argument("--allow-incomplete", action="store_true", help="Diagnostic only; not policy-compliant")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    index = args.index.resolve()
    try:
        if args.command in {"validate", "status"}:
            return command_validate(index, args.json)
        if args.command == "list":
            return command_list(index, args.limit, args.json)
        if args.command == "search":
            return command_search(index, args.query, args.limit, args.json)
        if args.command == "research":
            return command_research(args)
    except (OSError, ValueError, urllib.error.URLError, socket.error) as exc:
        print(f"BQCA_QUANTUM_KB=FAIL error={exc}", file=sys.stderr)
        return 2
    parser.error("unsupported command")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
