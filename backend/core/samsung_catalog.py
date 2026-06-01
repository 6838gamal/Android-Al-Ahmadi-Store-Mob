# Samsung screen catalog — defines the folder/subfolder structure
# series_key → { label_ar, label_en, models: [ {key, label_ar, label_en} ] }

SAMSUNG_CATALOG: dict = {
    "s_series": {
        "label_ar": "فئة اس (S Series)",
        "label_en": "S Series",
        "models": [
            {"key": "S10",       "label_ar": "اس 10 عادي",       "label_en": "Galaxy S10"},
            {"key": "S10+",      "label_ar": "اس 10 بلس",        "label_en": "Galaxy S10+"},
            {"key": "S10E",      "label_ar": "اس 10 إي",         "label_en": "Galaxy S10e"},
            {"key": "S20",       "label_ar": "اس 20 عادي",       "label_en": "Galaxy S20"},
            {"key": "S20+",      "label_ar": "اس 20 بلس",        "label_en": "Galaxy S20+"},
            {"key": "S20 Ultra", "label_ar": "اس 20 الترا",      "label_en": "Galaxy S20 Ultra"},
            {"key": "S20 FE",    "label_ar": "اس 20 اف اي",      "label_en": "Galaxy S20 FE"},
            {"key": "S20 5G",    "label_ar": "اس 20 فايف جي",    "label_en": "Galaxy S20 5G"},
            {"key": "S21",       "label_ar": "اس 21 عادي",       "label_en": "Galaxy S21"},
            {"key": "S21+",      "label_ar": "اس 21 بلس",        "label_en": "Galaxy S21+"},
            {"key": "S21 Ultra", "label_ar": "اس 21 الترا",      "label_en": "Galaxy S21 Ultra"},
            {"key": "S22",       "label_ar": "اس 22 عادي",       "label_en": "Galaxy S22"},
            {"key": "S22+",      "label_ar": "اس 22 بلس",        "label_en": "Galaxy S22+"},
            {"key": "S22 Ultra", "label_ar": "اس 22 الترا",      "label_en": "Galaxy S22 Ultra"},
            {"key": "S23",       "label_ar": "اس 23 عادي",       "label_en": "Galaxy S23"},
            {"key": "S23+",      "label_ar": "اس 23 بلس",        "label_en": "Galaxy S23+"},
            {"key": "S23 Ultra", "label_ar": "اس 23 الترا",      "label_en": "Galaxy S23 Ultra"},
        ],
    },
    "note_series": {
        "label_ar": "فئة نوت (Note Series)",
        "label_en": "Note Series",
        "models": [
            {"key": "Note 8",        "label_ar": "نوت 8",           "label_en": "Galaxy Note 8"},
            {"key": "Note 9",        "label_ar": "نوت 9",           "label_en": "Galaxy Note 9"},
            {"key": "Note 10",       "label_ar": "نوت 10 عادي",     "label_en": "Galaxy Note 10"},
            {"key": "Note 10+",      "label_ar": "نوت 10 بلس",      "label_en": "Galaxy Note 10+"},
            {"key": "Note 20",       "label_ar": "نوت 20 عادي",     "label_en": "Galaxy Note 20"},
            {"key": "Note 20 Ultra", "label_ar": "نوت 20 الترا",    "label_en": "Galaxy Note 20 Ultra"},
        ],
    },
}

# Flat set of all valid model keys for quick validation
ALL_MODEL_KEYS: set = {
    m["key"]
    for series in SAMSUNG_CATALOG.values()
    for m in series["models"]
}

# Flat map: model_key → series_key  (e.g. "S23 Ultra" → "s_series")
MODEL_TO_SERIES: dict = {
    m["key"]: series_key
    for series_key, series in SAMSUNG_CATALOG.items()
    for m in series["models"]
}


def get_catalog_tree() -> list:
    """Return the full catalog as a list suitable for JSON responses."""
    return [
        {
            "series_key": series_key,
            "label_ar": series["label_ar"],
            "label_en": series["label_en"],
            "models": series["models"],
        }
        for series_key, series in SAMSUNG_CATALOG.items()
    ]
