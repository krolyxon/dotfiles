#!/usr/bin/env python3
# Builds chars.json for CharPicker/Chars.qml: emoji, nerd font glyphs, unicode symbols, kaomoji.
# Run by hand to update (sources are pinned below), commit the result:
#   python3 chars-gen.py            -> writes chars.json next to this script
# Downloads are cached in ~/.cache/aurora/chars-src. Emoji newer than the installed
# Noto Color Emoji (checked with fc-query) are dropped so nothing shows as tofu.
import hashlib, json, os, re, subprocess, sys, urllib.request

EMOJI_VER = "17.0.0"
CLDR_VER = "48.0.0"
NERD_VER = "3.5.1"   # match ttf-jetbrains-mono-nerd
UCD_VER = "17.0.0"
CLDR = "https://raw.githubusercontent.com/unicode-org/cldr-json/%s/cldr-json/" % CLDR_VER
SRC = {
    "emoji-test.txt": "https://unicode.org/Public/%s/emoji/emoji-test.txt" % EMOJI_VER,
    "annotations.json": CLDR + "cldr-annotations-full/annotations/en/annotations.json",
    "annotationsDerived.json": CLDR + "cldr-annotations-derived-full/annotationsDerived/en/annotations.json",
    "glyphnames.json": "https://raw.githubusercontent.com/ryanoasis/nerd-fonts/v%s/glyphnames.json" % NERD_VER,
    "UnicodeData.txt": "https://unicode.org/Public/%s/ucd/UnicodeData.txt" % UCD_VER,
    "Blocks.txt": "https://unicode.org/Public/%s/ucd/Blocks.txt" % UCD_VER,
}
CACHE = os.path.expanduser("~/.cache/aurora/chars-src")
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chars.json")


def fetch(name):
    p = os.path.join(CACHE, hashlib.sha1(SRC[name].encode()).hexdigest()[:8] + "-" + name)
    if not os.path.exists(p):
        os.makedirs(CACHE, exist_ok=True)
        print("fetch", SRC[name], file=sys.stderr)
        with urllib.request.urlopen(SRC[name]) as r, open(p, "wb") as f:
            f.write(r.read())
    with open(p, encoding="utf-8") as f:
        return f.read()


def font_charset(family):
    try:
        out = subprocess.run(["fc-query", "-f", "%{charset}",
                              subprocess.run(["fc-match", "-f", "%{file}", family], capture_output=True, text=True).stdout],
                             capture_output=True, text=True).stdout
    except OSError:
        return None
    s = []
    for r in out.split():
        a, _, b = r.partition("-")
        s.append((int(a, 16), int(b or a, 16)))
    return s or None


def covered(cs, cp):
    return any(a <= cp <= b for a, b in cs)


sets = []        # [{id, label, groups: [label]}]
items = []       # [char, name, keywords, set, group, tones?]


def add_set(sid, label):
    sets.append({"id": sid, "label": label, "groups": []})
    return len(sets) - 1


def group(si, label):
    g = sets[si]["groups"]
    if label not in g:
        g.append(label)
    return g.index(label)


# ---------------- emoji ----------------
TONES = ["light skin tone", "medium-light skin tone", "medium skin tone", "medium-dark skin tone", "dark skin tone"]
GROUPS = {"Smileys & Emotion": "Smileys", "People & Body": "People", "Animals & Nature": "Nature",
          "Food & Drink": "Food", "Travel & Places": "Travel", "Activities": "Activities",
          "Objects": "Objects", "Symbols": "Symbols", "Flags": "Flags"}


def emoji():
    si = add_set("emoji", "Emoji")
    ann = json.loads(fetch("annotations.json"))["annotations"]["annotations"]
    ann.update(json.loads(fetch("annotationsDerived.json"))["annotationsDerived"]["annotations"])
    cs = font_charset("Noto Color Emoji")
    rows, maxver = [], 0.0
    grp = None
    for line in fetch("emoji-test.txt").splitlines():
        if line.startswith("# group:"):
            grp = GROUPS.get(line.split(":", 1)[1].strip())
            continue
        m = re.match(r"^([0-9A-F ]+);\s*fully-qualified\s*#\s*\S+\s+E(\d+\.\d+)\s+(.+)$", line)
        if not m or grp is None:
            continue
        cps = [int(c, 16) for c in m.group(1).split()]
        ver = float(m.group(2))
        if cs and len(cps) == 1 and covered(cs, cps[0]):
            maxver = max(maxver, ver)
        rows.append(("".join(map(chr, cps)), ver, m.group(3), grp))
    if cs:
        print("noto color emoji covers up to E%.1f" % maxver, file=sys.stderr)
    else:
        maxver = 99
    base, out = {}, []
    for ch, ver, name, grp in rows:
        if ver > maxver:
            continue
        head, _, quals = name.partition(": ")
        q = [x.strip() for x in quals.split(",")] if quals else []
        tones = [x for x in q if x in TONES]
        if tones:   # fold single-tone variants into the base emoji, drop mixed-tone couples
            rest = [x for x in q if x not in TONES]
            key = head + (": " + ", ".join(rest) if rest else "")
            if len(tones) == 1 and key in base:
                base[key][5][TONES.index(tones[0])] = ch
            continue
        a = ann.get(ch) or ann.get(ch.replace("\ufe0f", "")) or {}
        kw = [k for k in a.get("default", []) if k not in name]
        it = [ch, name, " ".join(kw), si, group(si, grp), [None] * 5]
        base[name] = it
        out.append(it)
    for it in out:
        if None in it[5]:
            it.pop()
        items.append(it)


# ---------------- nerd fonts ----------------
NERD = [("md", "Material"), ("fa", "Font Awesome"), ("fae", "Font Awesome"), ("cod", "Codicons"),
        ("dev", "Devicons"), ("oct", "Octicons"), ("seti", "Seti"), ("linux", "Logos"),
        ("weather", "Weather"), ("pl", "Powerline"), ("ple", "Powerline")]


def nerd():
    si = add_set("nerd", "Nerd")
    d = json.loads(fetch("glyphnames.json"))
    labels = dict(NERD)
    for _, l in NERD:
        group(si, l)
    rows = []
    for k, v in d.items():
        if k == "METADATA" or k.startswith("nfold"):
            continue
        pre, _, rest = k.partition("-")
        name = rest.replace("_", " ").replace("-", " ")
        rows.append((group(si, labels.get(pre, "Other")), name, k, v["char"]))
    rows.sort(key=lambda r: r[0])   # stable: keeps glyphnames order inside a set
    for g, name, k, ch in rows:
        items.append([ch, name, "nf-" + k, si, g])


# ---------------- unicode symbols ----------------
BLOCKS = [("Arrows", "Arrows"), ("Supplemental Arrows-A", "Arrows"), ("Supplemental Arrows-B", "Arrows"),
          ("Miscellaneous Symbols and Arrows", "Arrows"),
          ("Mathematical Operators", "Math"), ("Supplemental Mathematical Operators", "Math"),
          ("Miscellaneous Mathematical Symbols-A", "Math"), ("Miscellaneous Mathematical Symbols-B", "Math"),
          ("Letterlike Symbols", "Letterlike"), ("Number Forms", "Letterlike"),
          ("Superscripts and Subscripts", "Super/sub"), ("Greek and Coptic", "Greek"),
          ("Currency Symbols", "Currency"), ("General Punctuation", "Punctuation"),
          ("Miscellaneous Technical", "Technical"), ("Control Pictures", "Technical"),
          ("Box Drawing", "Box drawing"), ("Block Elements", "Blocks"),
          ("Geometric Shapes", "Shapes"), ("Geometric Shapes Extended", "Shapes"),
          ("Miscellaneous Symbols", "Dingbats"), ("Dingbats", "Dingbats"),
          ("Enclosed Alphanumerics", "Enclosed"), ("Braille Patterns", "Braille")]
LATIN1 = {0x24: "Currency", 0xA2: "Currency", 0xA3: "Currency", 0xA4: "Currency", 0xA5: "Currency",
          0xA7: "Punctuation", 0xB6: "Punctuation", 0xB7: "Punctuation", 0xA9: "Letterlike", 0xAE: "Letterlike",
          0xB0: "Math", 0xB1: "Math", 0xD7: "Math", 0xF7: "Math", 0xAC: "Math", 0xB5: "Greek",
          0xB2: "Super/sub", 0xB3: "Super/sub", 0xB9: "Super/sub", 0xBC: "Letterlike", 0xBD: "Letterlike", 0xBE: "Letterlike"}


# official names are often unguessable ("place of interest sign"): extra search words
SYM_KW = {0x2318: "command cmd mac key", 0x2325: "option alt mac key", 0x21E7: "shift key", 0x2303: "control ctrl key",
          0x23CE: "return enter key", 0x21B5: "return enter", 0x232B: "backspace delete key", 0x2326: "delete key",
          0x238B: "escape esc key", 0x21E5: "tab key", 0x21EA: "caps lock key", 0x2423: "space key",
          0x2713: "check tick yes done", 0x2714: "check tick yes done", 0x2717: "cross no x", 0x2718: "cross no x",
          0x2022: "bullet dot", 0x2026: "ellipsis dots", 0x2014: "em dash", 0x2013: "en dash", 0x00B7: "middle dot",
          0x00B0: "degree", 0x2122: "trademark tm", 0x00A9: "copyright", 0x00AE: "registered",
          0x221E: "infinity", 0x2248: "approx about", 0x2260: "not equal", 0x2264: "less equal", 0x2265: "greater equal",
          0x2192: "right", 0x2190: "left", 0x2191: "up", 0x2193: "down", 0x21D2: "implies then", 0x03BB: "lambda",
          0x2605: "star", 0x2606: "star", 0x2665: "heart", 0x2661: "heart", 0x266A: "music note", 0x2600: "sun",
          0x2601: "cloud", 0x2602: "umbrella rain", 0x260E: "phone", 0x2620: "skull poison", 0x262F: "yin yang",
          0x2622: "radioactive", 0x20AC: "euro", 0x20B9: "rupee inr", 0x00A3: "pound gbp",
          0x0024: "dollar usd", 0x00A5: "yen", 0x20BF: "bitcoin btc"}


def symbols():
    si = add_set("sym", "Symbols")
    for _, l in BLOCKS:
        group(si, l)
    names = {}
    for line in fetch("UnicodeData.txt").splitlines():
        f = line.split(";")
        if f[1].startswith("<") or f[2][0] in "CZM":   # controls, ranges, spaces, combining marks
            continue
        names[int(f[0], 16)] = f[1].lower()
    blocks = {}
    for line in fetch("Blocks.txt").splitlines():
        m = re.match(r"^([0-9A-F]+)\.\.([0-9A-F]+); (.+)$", line)
        if m:
            blocks[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    seen = set()
    for cp, g in sorted(LATIN1.items()):
        items.append([chr(cp), names[cp], SYM_KW.get(cp, ""), si, group(si, g)])
        seen.add(cp)
    for b, g in BLOCKS:
        a, z = blocks[b]
        for cp in range(a, z + 1):
            if cp in names and cp not in seen:
                items.append([chr(cp), names[cp], (SYM_KW.get(cp, "") + " " + b.lower()).strip(), si, group(si, g)])


# ---------------- kaomoji ----------------
KAOMOJI = {
    "Happy": [("(◕‿◕)", "smile"), ("(｡◕‿◕｡)", "smile cute"), ("(✿◠‿◠)", "flower smile"), ("ヽ(•‿•)ノ", "yay"),
              ("(＾▽＾)", "happy"), ("(◠‿◠)", "smile"), ("٩(◕‿◕)۶", "yay cheer"), ("(⌒‿⌒)", "content"),
              ("(*^▽^*)", "happy"), ("(≧▽≦)", "excited"), ("(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧", "sparkle magic excited"),
              ("✧*｡٩(ˊᗜˋ*)و✧*｡", "excited cheer"), ("(•̀ᴗ•́)و", "determined"), ("(ᵔᴥᵔ)", "happy bear"),
              ("ʘ‿ʘ", "wide eyes"), ("(´｡• ω •｡`)", "cute"), ("( ˘▽˘)っ♨", "tea relax"), ("(ﾟヮﾟ)", "happy"),
              ("\\(^o^)/", "yay cheer"), ("ヾ(⌐■_■)ノ♪", "cool dance music"), ("(☞ﾟヮﾟ)☞", "point you"),
              ("☜(ﾟヮﾟ☜)", "point you"), ("(•‿•)", "smile"), ("(⌐■_■)", "cool sunglasses deal with it"),
              ("ᕕ( ᐛ )ᕗ", "walk away happy"), ("♪~ ᕕ(ᐛ)ᕗ", "walk music"), ("(ﾉ´ヮ`)ﾉ*: ･ﾟ", "sparkle"),
              ("(^_^)", "smile"), ("(^_^)v", "peace"), ("(¬‿¬)", "smirk"), ("( ͡° ͜ʖ ͡°)", "lenny face"),
              ("( ͡~ ͜ʖ ͡°)", "lenny wink"), ("( ͡ᵔ ͜ʖ ͡ᵔ )", "lenny happy")],
    "Love": [("(♥‿♥)", "love heart eyes"), ("(´∀｀)♡", "love"), ("(づ｡◕‿‿◕｡)づ", "hug"), ("(っ˘з(˘⌣˘ )", "kiss"),
             ("(*˘︶˘*).｡.:*♡", "love dream"), ("♡(˘▽˘>ԅ( ˘⌣˘)", "hug"), ("(灬º‿º灬)♡", "blush love"),
             ("(◍•ᴗ•◍)❤", "love"), ("(´ε｀ )♡", "kiss"), ("( ˘ ³˘)♥", "kiss"), ("(ღ˘⌣˘ღ)", "love"),
             ("(づ￣ ³￣)づ", "kiss hug"), ("ʕっ•ᴥ•ʔっ", "bear hug"), ("(⊃｡•́‿•̀｡)⊃", "hug"),
             ("(*♡∀♡)", "love"), ("♥(ˆ⌣ˆԅ)", "love")],
    "Sad": [("(╥﹏╥)", "cry sad"), ("(ಥ﹏ಥ)", "cry tears"), ("(ಥ_ಥ)", "cry"), ("(T_T)", "cry"),
            ("(；﹏；)", "sad"), ("(´；ω；`)", "sad cry"), ("( ´•︵•` )", "sad"), ("(︶︹︶)", "sad pout"),
            ("(っ˘̩╭╮˘̩)っ", "sad"), ("(｡•́︿•̀｡)", "sad pout"), ("(ノ_<。)", "cry"), ("(個_個)", "cry"),
            ("(-_-)", "meh"), ("(._.)", "sad shy"), ("( ˘︹˘ )", "sad"), ("(×_×)", "dead ko"),
            ("(✖╭╮✖)", "dead"), ("(°ロ°) !", "shock")],
    "Angry": [("(╯°□°)╯︵ ┻━┻", "table flip rage"), ("┻━┻ ︵ヽ(`Д´)ﾉ︵ ┻━┻", "double table flip"),
              ("┬─┬ノ( º _ ºノ)", "table put back calm"), ("(ノಠ益ಠ)ノ彡┻━┻", "table flip rage"),
              ("ಠ_ಠ", "disapproval look"), ("ಠ益ಠ", "angry rage"), ("(ง'̀-'́)ง", "fight"),
              ("(ง •̀_•́)ง", "fight"), ("ヽ(`Д´)ﾉ", "angry"), ("(＃`Д´)", "angry"), ("(¬_¬)", "side eye"),
              ("(눈_눈)", "glare"), ("(╬ Ò﹏Ó)", "angry"), ("凸(¬‿¬)凸", "middle finger"), ("( ︶︿︶)_╭∩╮", "middle finger"),
              ("(ー_ー)!!", "annoyed"), ("(ᗒᗣᗕ)՞", "frustrated")],
    "Confused": [("¯\\_(ツ)_/¯", "shrug"), ("┐(´ー｀)┌", "shrug whatever"), ("╮(╯_╰)╭", "shrug"),
                 ("(⊙_☉)", "confused"), ("(・_・ヾ", "confused"), ("(・・ ) ?", "confused question"),
                 ("(°ー°〃)", "hmm"), ("( ˘･з･)", "hmm"), ("(￣～￣;)", "hmm"), ("¿ⓧ_ⓧﮌ", "what"),
                 ("(⊙.☉)7", "what"), ("(o_O)", "surprised what"), ("(O_O)", "shock"), ("(°o°)", "surprised"),
                 ("(ﾟДﾟ;)", "shock"), ("Σ(°△°|||)", "shock"), ("(・`ω´・)", "serious"), ("(￣ヘ￣)", "hmph")],
    "Embarrassed": [("(⁄ ⁄•⁄ω⁄•⁄ ⁄)", "blush shy"), ("(//▽//)", "blush"), ("(*/ω＼)", "hide shy"),
                    ("(〃▽〃)", "blush"), ("(⌒_⌒;)", "awkward"), ("(^_^;)", "nervous sweat"),
                    ("(￣▽￣;)", "awkward"), ("(・_・;)", "nervous"), ("(；一_一)", "awkward"),
                    ("(〃＾▽＾〃)", "blush happy"), ("(⁄ ⁄>⁄ ▽ ⁄<⁄ ⁄)", "blush"), ("(*ﾉωﾉ)", "hide shy")],
    "Animals": [("ʕ•ᴥ•ʔ", "bear"), ("ʕ·͡ᴥ·ʔ", "bear"), ("ʕ ᵔᴥᵔ ʔ", "bear happy"), ("(=^･ω･^=)", "cat"),
                ("(=^‥^=)", "cat"), ("(=ↀωↀ=)", "cat"), ("ฅ^•ﻌ•^ฅ", "cat paws"), ("/ᐠ｡ꞈ｡ᐟ\\", "cat"),
                ("/ᐠ - ˕ -マ", "cat sleep"), ("U・ᴥ・U", "dog"), ("V●ᴥ●V", "dog"), ("(V) (°,,,,°) (V)", "crab"),
                ("<コ:彡", "squid"), ("~>°)～～～", "snake"), ("<・ )))><<", "fish"), ("(•ө•)♡", "bird love"),
                ("( ˘▽˘)~ʊ", "pig"), ("ᘛ⁐̤ᕐᐷ", "mouse"), ("(\\_/)\n(•_•)\n/ >🍪", "bunny cookie"),
                ("(\\(\\ („• ֊ •„)", "bunny")],
    "Actions": [("(っ•﹏•)っ ✴==≡눈", "throw"), ("(ﾉ≧∀≦)ﾉ ‥…━━━★", "magic spell"), ("(∩ᄑ_ᄑ)⊃━☆ﾟ*･｡*･:≡( ε:)", "magic attack"),
                ("( ・_・)ノ⌒●~*", "throw bomb"), ("(-_-) zzZ", "sleep"), ("(￣o￣) zzZZzzZZ", "sleep"),
                ("( ˘ω˘ )ｽﾔｧ…", "sleep"), ("(ﾟ▽ﾟ)/", "wave hi"), ("(^-^*)/", "wave hi"), ("(*・ω・)ﾉ", "wave hi"),
                ("ヾ(・ω・*)", "wave bye"), ("(￣^￣)ゞ", "salute"), ("(｀・ω・´)ゞ", "salute"),
                ("ᕦ(ò_óˇ)ᕤ", "flex strong"), ("ᕙ(⇀‸↼‶)ᕗ", "flex strong"), ("(☞ﾟ∀ﾟ)☞", "point"),
                ("┗(＾0＾)┓", "dance"), ("└(^o^)┐", "dance"), ("♪┏(・o･)┛♪", "dance music"),
                ("( ˘▽˘)っ♨", "coffee tea"), ("(　-_･) ︻デ═一", "gun sniper"), ("▬▬ι═══════ﺤ", "sword"),
                ("(っ▀¯▀)つ", "cool"), ("( •_•)>⌐■-■", "sunglasses put on"), ("(ﾉ´з｀)ノ", "wave"),
                ("(｡･ω･)ﾉﾞ", "wave hi"), ("ε=ε=ε=┌(;*´Д`)ﾉ", "run away"), ("ε=ε=┌( >_<)┘", "run"),
                ("(っ´ω`)ﾉ(╥ω╥)", "comfort pat"), ("(*´∀`)_旦", "tea offer")],
    "Faces": [("(✧ω✧)", "sparkle eyes"), ("(◉_◉)", "stare"), ("(◔_◔)", "eye roll"), ("(⚆ _ ⚆)", "creepy"),
              ("(☉_☉)", "stare"), ("(ʘᗩʘ')", "shock"), ("(ᵕ—ᴗ—)", "calm"), ("(￣ω￣)", "smug"),
              ("(￣ー￣)", "smug"), ("( ¬‿¬)", "smug"), ("(￢‿￢ )", "smirk"), ("(ↀДↀ)", "scared"),
              ("(ꈍᴗꈍ)", "content"), ("(•ˋ _ ˊ•)", "unamused"), ("(ㆆ _ ㆆ)", "unamused"), ("( ⚆ _ ⚆ )", "weird"),
              ("(◣_◢)", "evil"), ("(｀∀´)Ψ", "devil evil"), ("(⊙ω⊙)", "surprised"), ("(⌐⊙_⊙)", "glasses"),
              ("ԅ(≖‿≖ԅ)", "scheming evil"), ("(¬‿¬ )", "smirk"), ("(￣﹃￣)", "drool hungry"), ("(っ˘ڡ˘ς)", "yummy")],
    "Things": [("┬┴┬┴┤(･_├┬┴┬┴", "peek wall"), ("|ω・)", "peek"), ("|_・)", "peek"),
               ("¯\\_( ͡° ͜ʖ ͡°)_/¯", "lenny shrug"), ("ᕙ(`▿´)ᕗ", "strong"), ("(ಠ‿ಠ)", "evil smile"),
               ("( ´_ゝ`)", "unimpressed"), ("¬_¬", "side eye"), ("(￣︶￣)↗", "point up"), ("☆*:.｡.o(≧▽≦)o.｡.:*☆", "celebrate"),
               ("°˖✧◝(⁰▿⁰)◜✧˖°", "excited sparkle"), ("✿", "flower"), ("❀", "flower"), ("✧･ﾟ: *✧･ﾟ:*", "sparkles"),
               ("( ･ิω･ิ)", "huh"), ("(⌐▀͡ ̯ʖ▀)", "cool lenny")],
}


def kaomoji():
    si = add_set("kao", "Kaomoji")
    for g, l in KAOMOJI.items():
        gi = group(si, g)
        for ch, tags in l:
            items.append([ch, tags.split()[0], tags, si, gi])


emoji()
nerd()
symbols()
kaomoji()
for s in sets:
    print("%-8s %6d" % (s["id"], sum(1 for i in items if sets[i[3]] is s)), file=sys.stderr)
with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"version": {"emoji": EMOJI_VER, "cldr": CLDR_VER, "nerd": NERD_VER, "ucd": UCD_VER},
               "sets": sets, "items": items}, f, ensure_ascii=False, separators=(",", ":"))
    f.write("\n")
print("wrote %s (%d items, %d KiB)" % (OUT, len(items), os.path.getsize(OUT) // 1024), file=sys.stderr)
