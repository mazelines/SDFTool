import json
import os
import threading
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


class Localization:
    def __init__(self, bundled_cache_path=None, app_name="SDFTool"):
        self._lock = threading.Lock()
        self._pending = set()
        self._translation_cache = {}
        self._executor = ThreadPoolExecutor(max_workers=2)
        self._user_cache_path = self._default_user_cache_path(app_name)
        self._load_cache(bundled_cache_path)
        self._load_cache(self._user_cache_path)

    def translate_cached_or_source(self, text, target_language, on_ready=None):
        if target_language in ("", "zh-CN"):
            return text

        cache_key = self._cache_key(text, target_language)
        with self._lock:
            translated = self._translation_cache.get(cache_key)
            if translated:
                return translated

            if cache_key not in self._pending:
                self._pending.add(cache_key)
                self._executor.submit(self._translate_async, text, target_language, on_ready)

        return text

    def _translate_async(self, text, target_language, on_ready):
        cache_key = self._cache_key(text, target_language)
        translated = text

        try:
            translated = self._request_google_translate(text, target_language)
        except Exception as exc:
            print(f"Google Translate failed: {exc}")

        with self._lock:
            self._translation_cache[cache_key] = translated
            self._pending.discard(cache_key)
            self._save_user_cache()

        if on_ready:
            on_ready(text, target_language, translated)

    def _request_google_translate(self, text, target_language):
        query = urllib.parse.urlencode({
            "client": "gtx",
            "sl": "zh-CN",
            "tl": target_language,
            "dt": "t",
            "q": text,
        })
        url = f"https://translate.googleapis.com/translate_a/single?{query}"
        with urllib.request.urlopen(url, timeout=5) as response:
            data = json.loads(response.read().decode("utf-8"))
        return "".join(part[0] for part in data[0] if part and part[0])

    def _load_cache(self, cache_path):
        if not cache_path:
            return

        path = Path(cache_path)
        if not path.exists():
            return

        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"Localization cache load failed: {exc}")
            return

        with self._lock:
            for language, translations in data.items():
                if isinstance(translations, dict):
                    for source, translated in translations.items():
                        if isinstance(source, str) and isinstance(translated, str):
                            self._translation_cache[self._cache_key(source, language)] = translated

    def _save_user_cache(self):
        if not self._user_cache_path:
            return

        grouped = {}
        for cache_key, translated in self._translation_cache.items():
            language, source = cache_key.split("\u0000", 1)
            grouped.setdefault(language, {})[source] = translated

        try:
            self._user_cache_path.parent.mkdir(parents=True, exist_ok=True)
            self._user_cache_path.write_text(
                json.dumps(grouped, ensure_ascii=False, indent=2, sort_keys=True),
                encoding="utf-8",
            )
        except Exception as exc:
            print(f"Localization cache save failed: {exc}")

    @staticmethod
    def _cache_key(text, target_language):
        return f"{target_language}\u0000{text}"

    @staticmethod
    def _default_user_cache_path(app_name):
        local_app_data = os.environ.get("LOCALAPPDATA")
        if not local_app_data:
            return None
        return Path(local_app_data) / app_name / "localization_cache.json"
