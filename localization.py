import json
import threading
from pathlib import Path


class Localization:
    """정적 캐시 기반 로컬라이제이션. 네트워크 번역 없이 번들 캐시만 사용.

    지원 언어: zh-CN(원문), ko, en — 번들 localization_cache.json에 내장.
    """

    def __init__(self, bundled_cache_path=None, app_name="SDFTool"):
        self._lock = threading.Lock()
        self._translation_cache = {}
        self._load_cache(bundled_cache_path)

    def translate_cached_or_source(self, text, target_language, on_ready=None):
        # 원문 언어(중국어)거나 미지정이면 원문 그대로.
        if target_language in ("", "zh-CN"):
            return text

        with self._lock:
            return self._translation_cache.get(self._cache_key(text, target_language), text)

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

    @staticmethod
    def _cache_key(text, target_language):
        return f"{target_language} {text}"
