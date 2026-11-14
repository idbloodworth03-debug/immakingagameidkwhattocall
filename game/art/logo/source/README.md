# Logo sources

The logo, the app icon and the splash screen one folder up are made by
`tools/make_logo.py` from the two pictures here:

- `trio.png`: the Red Fox, the Brown Bear and the Gray Squirrel
- `fox.png`: the Red Fox alone, close up

Both are drawn by the game itself, exactly as the home screen draws your
squad (the 3D toys, on a see-through background): `game/tests/squad_shot.gd`
takes them, and `tools/make_logo.py` says how. The sign is the menus' own
wooden plank (`tools/make_ui_art.py`) and the letters are **Lilita One**
(`game/art/fonts/LilitaOne-Regular.ttf`). Nothing here comes from outside
the project.

The `.gdignore` file keeps Godot from importing these sources.
