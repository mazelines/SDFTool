import json
import urllib.parse
import urllib.request


class Localization:
    def __init__(self):
        self._translation_cache = {}

    def translate(self, text, target_language):
        if target_language in ("", "zh-CN"):
            return text

        cache_key = (text, target_language)
        if cache_key in self._translation_cache:
            return self._translation_cache[cache_key]

        query = urllib.parse.urlencode({
            "client": "gtx",
            "sl": "zh-CN",
            "tl": target_language,
            "dt": "t",
            "q": text,
        })
        url = f"https://translate.googleapis.com/translate_a/single?{query}"

        try:
            with urllib.request.urlopen(url, timeout=5) as response:
                data = json.loads(response.read().decode("utf-8"))
            translated = "".join(part[0] for part in data[0] if part and part[0])
        except Exception as exc:
            print(f"Google Translate failed: {exc}")
            translated = text

        self._translation_cache[cache_key] = translated
        return translated
