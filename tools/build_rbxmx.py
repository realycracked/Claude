#!/usr/bin/env python3
"""
Génère les fichiers .rbxmx (modèles Roblox) à partir du dossier src/.

Usage :  python3 tools/build_rbxmx.py
Sortie : build/ReplicatedStorage.rbxmx, build/ServerScriptService.rbxmx,
         build/StarterPlayerScripts.rbxmx

Dans Roblox Studio : clic droit sur le service correspondant > "Insert from File..."
et choisir le fichier. Les scripts arrivent déjà au bon endroit.

Convention des noms de fichiers (identique à Rojo) :
  Nom.server.lua  -> Script
  Nom.client.lua  -> LocalScript
  Nom.lua         -> ModuleScript
  dossier/        -> Folder
"""

from pathlib import Path
import sys
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
OUT = ROOT / "build"

TARGETS = {
    "ReplicatedStorage": SRC / "ReplicatedStorage",
    "ServerScriptService": SRC / "ServerScriptService",
    "StarterPlayerScripts": SRC / "StarterPlayer" / "StarterPlayerScripts",
}

_ref = 0


def next_ref():
    global _ref
    _ref += 1
    return f"RBX{_ref}"


def cdata(text):
    # Un "]]>" dans le code couperait le CDATA : on le découpe proprement.
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def script_item(path: Path):
    name = path.name
    if name.endswith(".server.lua"):
        cls, name = "Script", name[: -len(".server.lua")]
    elif name.endswith(".client.lua"):
        cls, name = "LocalScript", name[: -len(".client.lua")]
    elif name.endswith(".lua"):
        cls, name = "ModuleScript", name[: -len(".lua")]
    else:
        return ""
    source = path.read_text(encoding="utf-8")
    props = [f'<string name="Name">{escape(name)}</string>']
    if cls != "ModuleScript":
        props.append('<bool name="Disabled">false</bool>')
    props.append(f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>')
    return (
        f'<Item class="{cls}" referent="{next_ref()}"><Properties>'
        + "".join(props)
        + "</Properties></Item>"
    )


def folder_item(path: Path):
    children = "".join(build_children(path))
    return (
        f'<Item class="Folder" referent="{next_ref()}"><Properties>'
        f'<string name="Name">{escape(path.name)}</string></Properties>{children}</Item>'
    )


def build_children(folder: Path):
    for child in sorted(folder.iterdir(), key=lambda p: (p.is_file(), p.name)):
        if child.is_dir():
            yield folder_item(child)
        elif child.suffix == ".lua":
            yield script_item(child)


def build(target_name: str, folder: Path):
    body = "".join(build_children(folder))
    xml = (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'
        "<Meta name=\"ExplicitAutoJoints\">true</Meta><External>null</External><External>nil</External>"
        + body
        + "</roblox>"
    )
    OUT.mkdir(exist_ok=True)
    out = OUT / f"{target_name}.rbxmx"
    out.write_text(xml, encoding="utf-8")
    return out


def main():
    for name, folder in TARGETS.items():
        if not folder.exists():
            print(f"Dossier manquant : {folder}", file=sys.stderr)
            sys.exit(1)
        out = build(name, folder)
        print(f"OK  {out.relative_to(ROOT)}  ({out.stat().st_size // 1024} Ko)")


if __name__ == "__main__":
    main()
