import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ICONS = ROOT / "ios/Icons"
ASSETS = ROOT / "ios/RuleTheWorld/Resource/Assets.xcassets"

CROWN = '<path d="M78 110l8 47h84l8-47-27 21-23-38-23 38z"/><path d="M88 169h80"/>'
STAR = '<path d="M128 78l14 31 34 4-25 23 7 34-30-17-30 17 7-34-25-23 34-4z"/>'
SHAPES = {
    # Arched imperial crown with cross, above a plinth
    "Lord Paramount": CROWN + '<path d="M84 110c0-26 20-42 44-42s44 16 44 42M128 50v14M121 57h14"/><path d="M98 192h60"/>',
    # Crown over a battlemented keep
    "High Lord": CROWN + '<path d="M100 194v-16h12v8h14v-8h14v8h14v-8h12v16z"/>',
    # Castle keep with a banner flying above
    "Lord": '<path d="M86 190V100h14v-12h16v12h16v-12h16v12h16v-12h16v12h14v90z"/><path d="M116 190v-24a12 12 0 0 1 24 0v24"/><path d="M128 84V62M128 62h26l-7 8 7 8h-26"/>',
    # Earl's coronet over a sword
    "Earl": '<path d="M94 112l6 36h56l6-36-19 15-15-26-15 26z"/><path d="M100 158h56"/><path d="M128 168v22M115 175h26"/><circle cx="128" cy="197" r="5"/>',
    # Round shield with a crossed axe
    "Thane": '<path d="M128 74l43 17v39c0 28-23 45-43 55-20-10-43-27-43-55V91z"/><path d="M112 162l34-68M138 94a17 17 0 0 1 9 25l-10-1a13 13 0 0 0-5-22z"/>',
    # Portcullis gate with a key
    "Castellan": '<path d="M86 190v-70a42 42 0 0 1 84 0v70"/><path d="M86 150h84M104 190v-62M128 190v-66M152 190v-62"/><circle cx="170" cy="176" r="9"/><path d="M166 183l-10 15M160 196h9"/>',
    # Watchtower with a beacon flame
    "Warden": '<path d="M102 190V110h52v80"/><path d="M96 110V92h12v8h14v-8h14v8h14v-8h12v18z"/><path d="M120 134h16v-18h-16z"/><path d="M128 84c-9-9 3-15 0-25 14 8 15 18 0 25"/>',
    # Sheriff's star badge
    "Sheriff": STAR + '<circle cx="128" cy="128" r="10"/>',
    # House on a plot of land
    "Freeholder": '<path d="M84 140l44-36 44 36"/><path d="M96 134v52h64v-52"/><path d="M118 186v-26h20v26"/><path d="M74 194h108"/>',
    # Small cottage with a chimney
    "Tenant": '<path d="M94 152l34-28 34 28"/><path d="M102 146v40h52v-40"/><path d="M120 186v-20h16v20"/><path d="M150 136v-18h10v26"/><path d="M88 194h80"/>',
}
PALETTES = {
    "mythic": ("#FFE9A8", "#F5B93E", "#B97718"),
    "legendary": ("#FFE3AF", "#ED963C", "#AD571F"),
    "epic": ("#E7D5FF", "#A475DC", "#633D9B"),
    "rare": ("#C7EEFF", "#56B3E5", "#286CA8"),
    "common": ("#D9EEE5", "#80B7A0", "#477A69"),
}


def main():
    ranks_path = ROOT / "data/ranks.json"
    text = ranks_path.read_text()
    ranks = json.loads(text)["state"]
    for rank in ranks:
        name = "Rank" + rank["name"].replace(" ", "")
        slug = "rank-" + rank["name"].lower().replace(" ", "-")
        light, mid, dark = PALETTES[rank["rarity"]]
        svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <defs>
    <linearGradient id="tile" x2="0" y2="1"><stop stop-color="{light}"/><stop offset=".55" stop-color="{mid}"/><stop offset="1" stop-color="{dark}"/></linearGradient>
    <linearGradient id="edge" x2="0" y2="1"><stop stop-color="{light}"/><stop offset="1" stop-color="{dark}"/></linearGradient>
    <radialGradient id="gloss" cx="50%" cy="30%" r="75%"><stop stop-color="#FFF" stop-opacity=".45"/><stop offset=".6" stop-color="#FFF" stop-opacity="0"/></radialGradient>
    <filter id="drop" x="-40%" y="-40%" width="180%" height="180%"><feDropShadow dx="0" dy="4" stdDeviation="4" flood-color="#101820" flood-opacity=".5"/></filter>
  </defs>
  <g filter="url(#drop)"><rect x="24" y="24" width="208" height="208" rx="52" fill="url(#edge)"/><rect x="34" y="34" width="188" height="188" rx="44" fill="url(#tile)"/></g>
  <rect x="48" y="48" width="160" height="160" rx="36" fill="none" stroke="{dark}" stroke-opacity=".55" stroke-width="3"/>
  <path d="M34 120V78a44 44 0 0 1 44-44h100a44 44 0 0 1 44 44v42z" fill="url(#gloss)"/>
  <g fill="none" stroke="#FFF" stroke-width="7" stroke-linecap="round" stroke-linejoin="round" filter="url(#drop)">{SHAPES[rank['name']]}</g>
</svg>
'''
        source = ICONS / f"{slug}.svg"
        source.write_text(svg)
        imageset = ASSETS / f"{name}.imageset"
        imageset.mkdir(exist_ok=True)
        (imageset / "Contents.json").write_text(json.dumps({
            "images": [{"filename": f"{name}.png", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
        }, indent=2) + "\n")
        subprocess.run(["rsvg-convert", "-w", "256", "-h", "256", str(source), "-o", str(imageset / f"{name}.png")], check=True)
        if "icon" not in rank:
            needle = f'      "description": {json.dumps(rank["description"])},'
            text = text.replace(needle, needle + f'\n      "icon": "{name}",', 1)
        print(f"Generated {name}")
    ranks_path.write_text(text)


if __name__ == "__main__":
    main()
