class_name BuildInfo
extends RefCounted
## Which build this is, shown small in a corner of the main menu and the
## profile (where the settings are), e.g. "v1.5.186 · 3a165b7": the game's
## version (project.godot application/config/version), the build number (the
## GitHub Actions run that built it) and the commit. The web build writes
## res://build.json (tools/build_web.sh); without it (running from the
## editor) the build number reads "dev".

const FILE := "res://build.json"

static var _text := ""


static func text() -> String:
	if _text != "":
		return _text
	var version := String(ProjectSettings.get_setting("application/config/version", "1.0"))
	var build := "dev"
	var commit := ""
	if FileAccess.file_exists(FILE):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			build = String(parsed.get("build", build))
			commit = String(parsed.get("commit", ""))
	_text = "v%s.%s" % [version, build] + (" · %s" % commit if commit != "" else "")
	return _text


## A small, faint label with the version, for a corner of a screen.
static func label() -> Label:
	var l := Label.new()
	l.text = text()
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", UIKit.INK)
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
