import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ICONS = ROOT / "ios/Icons"
ASSETS = ROOT / "ios/RuleTheWorld/Resource/Assets.xcassets"

GLOBE = '<circle cx="128" cy="132" r="43"/><ellipse cx="128" cy="132" rx="19" ry="43"/><path d="M85 132h86M91 111h74M91 153h74"/>'
CROWN = '<path d="M78 110l8 47h84l8-47-27 21-23-38-23 38z"/><path d="M88 169h80"/>'
STAR = '<path d="M128 78l14 31 34 4-25 23 7 34-30-17-30 17 7-34-25-23 34-4z"/>'
SCROLL = '<path d="M89 86h69a14 14 0 0 1 14 14v65a13 13 0 0 0 13 13H99a14 14 0 0 1-14-14V99a13 13 0 0 0-26 0h26M106 108h43M106 126h35M106 144h23"/>'
COMPASS = '<circle cx="128" cy="128" r="49"/><path d="M148 91l-9 48-31 26 9-48zM128 69v10M128 177v10M69 128h10M177 128h10"/>'
SHAPES = {
    "Emperor": '<g transform="translate(0 28) scale(1 .8)">' + GLOBE + '</g><path d="M89 92l-5-29 25 15 19-28 19 28 25-15-5 29z"/><path d="M106 194h44"/>',
    "High Regent": CROWN + '<path d="M128 60v24M116 72h24M99 187h58"/>',
    "Overlord": '<path d="M128 69l49 19v44c0 31-26 48-49 60-23-12-49-29-49-60V88z"/>' + '<g transform="translate(45 43) scale(.65)">' + STAR + '</g>',
    "Viceroy": CROWN + '<path d="M63 170l-8-75M193 170l8-75M56 99l16-8M200 99l-16-8"/>',
    "High Chancellor": SCROLL + '<circle cx="159" cy="158" r="19"/><path d="M150 175l-4 19 13-6 13 6-4-19"/>',
    "Chancellor": SCROLL + '<circle cx="159" cy="158" r="16"/>',
    "Proconsul": '<path d="M74 100l54-28 54 28zM80 176h96M89 112v50M113 112v50M143 112v50M167 112v50M71 188h114"/>',
    "Consul": '<path d="M83 98h90M83 170h90M97 98v72M159 98v72M76 184h104M103 84h50"/><circle cx="128" cy="134" r="15"/>',
    "Prefect": '<path d="M128 74l43 17v39c0 28-23 45-43 55-20-10-43-27-43-55V91zM106 129l15 16 29-33"/>',
    "Legate": '<path d="M97 189V72M99 78h69l-15 26 15 26H99"/><circle cx="97" cy="67" r="5"/>',
    "Ambassador": GLOBE + '<path d="M72 104l-9 25 9 26M184 104l9 25-9 26"/>',
    "Emissary": '<rect x="73" y="92" width="110" height="76" rx="9"/><path d="M76 98l52 39 52-39M77 161l34-31M179 161l-34-31"/><circle cx="128" cy="137" r="10"/>',
    "Envoy": '<path d="M89 186V72M91 77h76l-18 25 18 25H91M74 186h32"/>',
    "Pioneer": '<path d="M69 170l59-84 59 84zM128 86v84M107 170l21-33 21 33M67 184h122"/>',
    "Pathfinder": COMPASS,
    "Trailblazer": '<path d="M107 185c-42-33 35-52 7-76M139 185c-42-33 35-52 7-76M89 94h83l-20-18M172 94l-20 18M83 80v35"/>',
    "Explorer": '<circle cx="118" cy="117" r="36"/><path d="M144 144l37 37M98 117h40M118 97v40"/>',
    "Voyager": '<path d="M72 151h112l-20 26H94zM128 76v75M119 85l-35 54h35zM138 92l33 47h-33M73 190q14-11 28 0t28 0 28 0 28 0"/>',
    "Wayfarer": '<path d="M83 180l7-100M83 100h35l-9 46H85M144 181l26-96M154 82l16 3 6-15M74 187h109"/>',
    "Citizen": '<circle cx="128" cy="102" r="23"/><path d="M82 178v-12a46 36 0 0 1 92 0v12z"/>',
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
    ranks = json.loads(text)["global"]
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
