"""Best-effort 'is there a newer build?' check against the web manifest.

The deploy step (scripts/deploy.py) uploads `latest.yml` next to the release
artifacts on the web host. On startup the app fetches that manifest in a daemon
thread, compares its `version:` to the running __version__, and — if newer —
emits a Qt signal so the GUI can offer a download link.

Dependency-free: the manifest is a flat `key: value` YAML we author ourselves,
so a tiny parser avoids bundling PyYAML. A failed check is swallowed — it must
never disrupt the main workflow.
"""

from __future__ import annotations

import re
import urllib.request

from PySide6.QtCore import QObject, Signal

MANIFEST_URL = "https://mazeline.tech/updates/SDFTools/latest.yml"
DOWNLOAD_URL = "https://mazeline.tech/updates/SDFTools/SDFTool.zip"


def parse_manifest(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        out[key.strip()] = value.strip().strip("'\"")
    return out


def version_tuple(s: str) -> tuple[int, ...]:
    parts = re.split(r"[.\-+]", s.strip())
    return tuple(int(p) if p.isdigit() else 0 for p in parts)


def is_newer(remote: str, local: str) -> bool:
    r, l = version_tuple(remote), version_tuple(local)
    n = max(len(r), len(l))
    r += (0,) * (n - len(r))
    l += (0,) * (n - len(l))
    return r > l


def fetch_manifest(url: str = MANIFEST_URL, timeout: float = 5.0) -> dict[str, str]:
    req = urllib.request.Request(url, headers={"User-Agent": "SDFTool-updater"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        text = resp.read().decode("utf-8", "replace")
    return parse_manifest(text)


class UpdateChecker(QObject):
    """Fires `updateAvailable(version, download_url)` if the host has a newer build.

    Runs the blocking fetch on a daemon thread so it neither blocks the GUI nor
    keeps the process alive on exit. `notify_up_to_date` controls whether
    `upToDate` fires on a clean check (useful for manual checks; suppress on startup).
    """

    updateAvailable = Signal(str, str)  # remote_version, download_url
    upToDate = Signal(str)             # current/remote version
    failed = Signal(str)               # error message

    def __init__(
        self,
        local_version: str,
        manifest_url: str = MANIFEST_URL,
        download_url: str = DOWNLOAD_URL,
        notify_up_to_date: bool = False,
    ) -> None:
        super().__init__()
        self._local = local_version
        self._manifest_url = manifest_url
        self._download_url = download_url
        self._notify_up_to_date = notify_up_to_date

    def start(self) -> None:
        import threading
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self) -> None:
        try:
            data = fetch_manifest(self._manifest_url)
            remote = data.get("version", "")
            if remote and is_newer(remote, self._local):
                self.updateAvailable.emit(remote, self._download_url)
            elif self._notify_up_to_date:
                self.upToDate.emit(remote or self._local)
        except Exception as e:  # noqa: BLE001 — best-effort, never disrupt the app
            if self._notify_up_to_date:
                self.failed.emit(str(e))
