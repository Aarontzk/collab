"""Generate Collab report header/footer SVGs (variant 5: Garis Cahaya)."""
import base64
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])  # collab repo root
OUT = ROOT / "docs" / "kop-laporan"
OUT.mkdir(parents=True, exist_ok=True)

FONTS = ROOT / "assets" / "fonts"


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode()


LOGO = b64(ROOT / "assets" / "images" / "logo_mark.png")
FONT_CSS = f"""
@font-face{{font-family:PJS;font-weight:800;src:url(data:font/ttf;base64,{b64(FONTS/'PlusJakartaSans-ExtraBold.ttf')})}}
@font-face{{font-family:PJS;font-weight:600;src:url(data:font/ttf;base64,{b64(FONTS/'PlusJakartaSans-SemiBold.ttf')})}}
@font-face{{font-family:Pop;font-weight:400;src:url(data:font/ttf;base64,{b64(FONTS/'Poppins-Regular.ttf')})}}
@font-face{{font-family:Pop;font-weight:500;src:url(data:font/ttf;base64,{b64(FONTS/'Poppins-Medium.ttf')})}}
.brand{{font-family:PJS;font-weight:800;fill:#243F81}}
.eyebrow{{font-family:PJS;font-weight:600;fill:#127BBE;letter-spacing:4px}}
.meta{{font-family:Pop;font-weight:400;fill:#44474F}}
"""

# Shared defs: grain texture, glow, soft shadow, brand gradients.
DEFS = """
<filter id="grain" x="0" y="0" width="100%" height="100%">
  <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="3" seed="7" stitchTiles="stitch"/>
  <feColorMatrix values="0 0 0 0 0.14  0 0 0 0 0.25  0 0 0 0 0.5  0 0 0 0.9 0"/>
</filter>
<filter id="glow" x="-20%" y="-400%" width="140%" height="900%">
  <feGaussianBlur stdDeviation="7"/>
</filter>
<filter id="dotglow" x="-300%" y="-300%" width="700%" height="700%">
  <feGaussianBlur stdDeviation="9"/>
</filter>
<filter id="shadow" x="-10%" y="-300%" width="120%" height="800%">
  <feDropShadow dx="0" dy="5" stdDeviation="6" flood-color="#127BBE" flood-opacity="0.22"/>
</filter>
<filter id="pillshadow" x="-40%" y="-80%" width="180%" height="300%">
  <feDropShadow dx="0" dy="6" stdDeviation="9" flood-color="#243F81" flood-opacity="0.18"/>
</filter>
<linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
  <stop offset="0" stop-color="#fff" stop-opacity=".55"/>
  <stop offset=".5" stop-color="#fff" stop-opacity="0"/>
</linearGradient>
<radialGradient id="glowBlue"><stop offset="0" stop-color="#75BDE0" stop-opacity=".55"/><stop offset="1" stop-color="#75BDE0" stop-opacity="0"/></radialGradient>
<radialGradient id="glowYellow"><stop offset="0" stop-color="#FDBB16" stop-opacity=".42"/><stop offset="1" stop-color="#FDBB16" stop-opacity="0"/></radialGradient>
<radialGradient id="glowNavy"><stop offset="0" stop-color="#127BBE" stop-opacity=".22"/><stop offset="1" stop-color="#127BBE" stop-opacity="0"/></radialGradient>
"""


def bar(x1, x2, y, grad_id, stops):
    """Glossy gradient bar with glow underlay and soft shadow."""
    w = x2 - x1
    stop_xml = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f"""
<linearGradient id="{grad_id}" x1="{x1}" y1="0" x2="{x2}" y2="0" gradientUnits="userSpaceOnUse">{stop_xml}</linearGradient>
<rect x="{x1}" y="{y-2}" width="{w}" height="12" rx="6" fill="url(#{grad_id})" opacity=".3" filter="url(#glow)"/>
<rect x="{x1}" y="{y}" width="{w}" height="8" rx="4" fill="url(#{grad_id})" filter="url(#shadow)"/>
<rect x="{x1}" y="{y}" width="{w}" height="8" rx="4" fill="url(#gloss)"/>
"""


def dot(cx, cy, color, glow=True):
    halo = f'<circle cx="{cx}" cy="{cy}" r="11" fill="{color}" opacity=".7" filter="url(#dotglow)"/>' if glow else ""
    return f"""{halo}
<circle cx="{cx}" cy="{cy}" r="9" fill="{color}"/>
<circle cx="{cx-2.5}" cy="{cy-3}" r="3.2" fill="#fff" opacity=".45"/>"""


def wash(h, top: bool, glows: str):
    """Pale brand wash + grain, faded toward the page so it melts into white."""
    y1, y2 = ("0", "1") if top else ("1", "0")
    return f"""
<linearGradient id="fade" x1="0" y1="{y1}" x2="0" y2="{y2}">
  <stop offset="0" stop-color="#fff"/><stop offset=".4" stop-color="#fff" stop-opacity=".5"/><stop offset=".78" stop-color="#fff" stop-opacity=".1"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
</linearGradient>
<mask id="fadeMask"><rect width="1900" height="{h}" fill="url(#fade)"/></mask>
<g mask="url(#fadeMask)">
  <rect width="1900" height="{h}" fill="#EEF3FB"/>
  {glows}
  <rect width="1900" height="{h}" filter="url(#grain)" opacity=".07"/>
</g>"""


def svg(h, body):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1900" height="{h}" viewBox="0 0 1900 {h}">
<defs><style>{FONT_CSS}</style>{DEFS}</defs>
{body}
</svg>
"""


HEADER = svg(320, f"""
{wash(320, True, '''
  <ellipse cx="1560" cy="-20" rx="620" ry="260" fill="url(#glowBlue)"/>
  <ellipse cx="300" cy="40" rx="520" ry="200" fill="url(#glowNavy)"/>
  <ellipse cx="1730" cy="226" rx="260" ry="120" fill="url(#glowYellow)"/>''')}
<image x="150" y="84" width="88" height="88" href="data:image/png;base64,{LOGO}"/>
<text class="brand" x="258" y="151" font-size="64">Collab</text>
<text class="eyebrow" x="1750" y="114" font-size="24" text-anchor="end">TEKNOLOGI BERKEMBANG – C</text>
<text class="meta" x="1750" y="154" font-size="27" text-anchor="end">Kelompok 2 · Laporan Final Project</text>
{bar(150, 1686, 228, "barH", [(0, "#243F81"), (.55, "#127BBE"), (1, "#75BDE0")])}
{dot(1712, 232, "#243F81")}
{dot(1741, 232, "#FDBB16")}
""")

FOOTER = svg(300, f"""
{wash(300, False, '''
  <ellipse cx="260" cy="320" rx="560" ry="220" fill="url(#glowYellow)"/>
  <ellipse cx="1620" cy="330" rx="620" ry="240" fill="url(#glowBlue)"/>''')}
{dot(159, 112, "#FDBB16")}
{dot(188, 112, "#243F81")}
{bar(214, 1750, 108, "barF", [(0, "#75BDE0"), (.45, "#127BBE"), (1, "#243F81")])}
<image x="150" y="178" width="40" height="40" href="data:image/png;base64,{LOGO}"/>
<text class="brand" x="202" y="209" font-size="27">Collab</text>
<text class="meta" x="298" y="209" font-size="22">·  Kerja bareng, nilai adil</text>
<g filter="url(#pillshadow)">
  <rect x="1630" y="172" width="120" height="52" rx="26" fill="#fff"/>
</g>
<linearGradient id="pillStroke" x1="1630" y1="0" x2="1750" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#75BDE0"/><stop offset="1" stop-color="#243F81"/>
</linearGradient>
<rect x="1631" y="173" width="118" height="50" rx="25" fill="none" stroke="url(#pillStroke)" stroke-width="2"/>
""")

(OUT / "header.svg").write_text(HEADER, encoding="utf-8")
(OUT / "footer.svg").write_text(FOOTER, encoding="utf-8")
print("written", OUT)
