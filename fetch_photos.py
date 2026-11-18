#!/usr/bin/env python3
"""
Downloads one photo per asset name from Wikimedia Commons into a folder called CaspianPhotos,
and writes credits.csv with the photographer and licence of each picture.

Run it on your Mac:
    cd ~/Desktop
    python3 fetch_photos.py

Then select everything inside CaspianPhotos and drag it into Assets in Xcode.
Xcode names each image set after the file name, which is exactly what the app expects.

To swap a photo you don't like: change its search words below, delete the old file
from CaspianPhotos, and run the script again. Only missing files are downloaded.
"""

import csv
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Asset name -> search words on Wikimedia Commons. Edit the words to get a different photo.
PHOTOS = {
    # Questions
    "q_persian_carpet": "persian carpet",
    "q_tar": "tar string instrument iran",
    "q_ghalamzani": "qalamzani",
    "q_kimono": "furisode kimono",
    "q_matcha": "matcha bowl chasen whisk",
    "q_turkish_tea": "turkish tea glass",
    "q_baklava": "pistachio baklava",
    "q_matryoshka": "matryoshka dolls",
    "q_balalaika": "balalaika",
    "q_butter_chicken": "butter chicken naan",
    "q_taj_mahal": "taj mahal front",
    "q_hanbok": "hanbok",
    "q_kimchi": "baechu kimchi",
    "q_pad_thai": "pad thai plate",
    "q_muay_thai": "muay thai fight",
    "q_kilt": "tartan kilt",
    "q_haggis": "haggis neeps tatties",
    "q_venetian_mask": "venetian carnival mask",
    "q_espresso": "espresso cup",
    "q_koshari": "koshari",
    "q_tutankhamun": "mask of tutankhamun",
    "q_sugar_skull": "sugar skull calavera",
    "q_mariachi": "mariachi charro",
    "q_tagine": "tagine pot",
    # Landmarks
    "l_iran_azadi": "azadi tower tehran",
    "l_iran_persepolis": "persepolis",
    "l_iran_isfahan": "naqsh-e jahan square isfahan",
    "l_japan_fuji": "mount fuji lake kawaguchi",
    "l_japan_inari": "fushimi inari torii",
    "l_turkey_hagia_sophia": "hagia sophia istanbul",
    "l_turkey_cappadocia": "cappadocia balloons",
    "l_russia_st_basils": "saint basil's cathedral moscow",
    "l_russia_baikal": "lake baikal",
    "l_india_hawa_mahal": "hawa mahal jaipur",
    "l_korea_gyeongbokgung": "gyeongbokgung palace",
    "l_korea_jeju": "seongsan ilchulbong jeju",
    "l_thailand_grand_palace": "grand palace bangkok",
    "l_thailand_wat_arun": "wat arun",
    "l_scotland_edinburgh_castle": "edinburgh castle from princes street",
    "l_scotland_loch_ness": "loch ness",
    "l_italy_colosseum": "colosseum rome",
    "l_italy_venice": "venice grand canal gondola",
    "l_egypt_pyramids": "pyramids of giza",
    "l_egypt_luxor": "luxor temple",
    "l_mexico_chichen": "chichen itza el castillo",
    "l_mexico_casa_azul": "museo frida kahlo coyoacan",
    "l_morocco_jemaa": "jemaa el-fnaa square",
    "l_morocco_chefchaouen": "chefchaouen blue street",
}

OUT_DIR = "CaspianPhotos"
API = "https://commons.wikimedia.org/w/api.php"
WIDTH = 1200  # pixels; plenty for an iPhone screen
HEADERS = {"User-Agent": "CaspianAppPhotoFetcher/1.0 (Apple Developer Academy student project)"}


def fetch(url, timeout=60):
    """GET with patience: Wikimedia answers 429 when we go too fast, so wait and retry."""
    req = urllib.request.Request(url, headers=HEADERS)
    for attempt in range(6):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 429 and attempt < 5:
                wait = 10 * (attempt + 1)
                print(f"      (rate limited, waiting {wait}s)")
                time.sleep(wait)
                continue
            raise
    raise RuntimeError("gave up after retries")


def api(params):
    params["format"] = "json"
    url = API + "?" + urllib.parse.urlencode(params)
    return json.loads(fetch(url, timeout=30))


def strip_html(text):
    return re.sub(r"<[^>]+>", "", text or "").strip()


def find_photo(term):
    """Returns (file_title, info) for the best search hit, or (None, None)."""
    data = api({
        "action": "query",
        "generator": "search",
        "gsrsearch": f"{term} filetype:bitmap",
        "gsrnamespace": 6,
        "gsrlimit": 10,
        "prop": "imageinfo",
        "iiprop": "url|mime|size|extmetadata",
        "iiurlwidth": WIDTH,
    })
    pages = data.get("query", {}).get("pages", {})
    candidates = []
    for page in pages.values():
        info = (page.get("imageinfo") or [{}])[0]
        if info.get("mime") not in ("image/jpeg", "image/png"):
            continue
        if info.get("width", 0) < 600 or info.get("height", 0) < 400:
            continue
        candidates.append((page.get("index", 99), page.get("title"), info))
    if not candidates:
        return None, None
    candidates.sort(key=lambda c: c[0])
    return candidates[0][1], candidates[0][2]


def download(url, path):
    data = fetch(url)
    with open(path, "wb") as f:
        f.write(data)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    credits_path = os.path.join(OUT_DIR, "credits.csv")
    existing = {}
    if os.path.exists(credits_path):
        with open(credits_path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                existing[row["asset"]] = row

    for asset, term in PHOTOS.items():
        already = [n for n in os.listdir(OUT_DIR) if n.startswith(asset + ".")]
        if already:
            print(f"skip  {asset} (already have {already[0]})")
            continue
        try:
            title, info = find_photo(term)
            if not info:
                print(f"MISS  {asset}: nothing found for '{term}', try other words")
                continue
            ext = ".png" if info["mime"] == "image/png" else ".jpg"
            path = os.path.join(OUT_DIR, asset + ext)
            download(info.get("thumburl") or info["url"], path)
            meta = info.get("extmetadata", {})
            existing[asset] = {
                "asset": asset,
                "file": title,
                "author": strip_html(meta.get("Artist", {}).get("value")),
                "license": strip_html(meta.get("LicenseShortName", {}).get("value")),
                "page": info.get("descriptionurl", ""),
            }
            print(f"ok    {asset} <- {title}")
        except Exception as e:  # keep going if one photo fails
            print(f"FAIL  {asset}: {e}")
        time.sleep(2.5)  # be polite to the Commons servers, they rate-limit fast scripts

    with open(credits_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["asset", "file", "author", "license", "page"])
        writer.writeheader()
        for row in existing.values():
            writer.writerow(row)

    print(f"\nDone. Photos are in ./{OUT_DIR}. Credits in {credits_path}.")
    print("Now select all the images in that folder and drag them into Assets in Xcode.")


if __name__ == "__main__":
    sys.exit(main())
