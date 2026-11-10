extends Node
## The art tests (data/art_tests.json: animals from an outside art pack)
## next to the animals they play as: how heavy each one's models are (file
## size, triangles, vertices, bones, blendshapes, graphics memory: what the
## mesh takes once, and what each animal on the field takes on top), how
## tall each stands, and the drawn size and tallest pose to put in
## art_tests.json (size: so it stands exactly as tall on screen as the
## animal it plays as; pose_up as bodies.json has it).
##   godot --headless --path game res://tests/art_test_report.tscn
## The last line (ARTTEST {...}) is for tools/packs/sizes.py, which writes
## those two numbers into art_tests.json.


func _ready() -> void:
	GameData.install_art_tests()
	var out := {}
	var tests: Dictionary = GameData.art_tests.get("animals", {})
	print("%-18s %-9s %8s %7s %7s %5s %6s %9s %9s   %s" % ["animal", "model", "file KB", "tris", "verts", "bones", "shapes", "mesh KB", "each KB", "animations"])
	for id: String in tests:
		var like := GameData.plays_as(id)
		for who in [like, id]:
			for kind in ["battle", "viewer"]:
				_model_line(who, kind)
		var mine := _stand(id)
		var theirs := _stand(like)
		var their_size := float(GameData.bodies.animals[like].size)
		# Drawn height on screen: natural "up" times size over natural longest.
		var their_tall := float(theirs.up) / float(theirs.longest) * their_size
		var size := their_tall / (float(mine.up) / float(mine.longest))
		out[id] = {"size": snappedf(size, 0.01), "pose_up": snappedf(float(mine.pose_up), 0.001)}
		print("  %s stands %.2f tiles tall drawn %.2f long; %s needs size %.2f to stand as tall (its tallest pose %.3f of standing; the %s's %.3f)" % [
			like, their_tall, their_size, id, size, float(mine.pose_up), like, float(theirs.pose_up)])
	print("ARTTEST " + JSON.stringify(out))
	get_tree().quit()


## Its battle model's natural box and tallest pose share.
func _stand(id: String) -> Dictionary:
	var box := ModelStage.natural_box(id)
	var m := ModelStage.new_model(id, 1.0, true)
	add_child(m.pivot)
	var share := ModelStage.tallest_share(m)
	m.pivot.free()
	return {"longest": box.longest, "up": box.up, "pose_up": share}


func _model_line(id: String, kind: String) -> void:
	var path := ("res://art/models/battle/%s.glb" if kind == "battle" else "res://art/models/%s.glb") % id
	if not ResourceLoader.exists(path):
		print("%-18s %-9s (no model)" % [id, kind])
		return
	var file := FileAccess.open(path, FileAccess.READ)
	var file_kb := (file.get_length() / 1024.0) if file != null else 0.0
	var root := (load(path) as PackedScene).instantiate() as Node3D
	var tris := 0
	var verts := 0
	var shapes := 0
	var shared := 0
	var each := 0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		shapes += mi.get_blend_shape_count()
		for s in mi.mesh.get_surface_count():
			var surface := RenderingServer.mesh_get_surface(mi.mesh.get_rid(), s)
			var count := int(surface.get("vertex_count", 0))
			verts += count
			var index_count := int(surface.get("index_count", 0))
			tris += (index_count if index_count > 0 else count) / 3
			var bytes := 0
			for key in ["vertex_data", "attribute_data", "skin_data", "index_data", "blend_shape_data"]:
				bytes += (surface.get(key, PackedByteArray()) as PackedByteArray).size()
			shared += bytes
			# A skinned or blendshaped animal on the field keeps its own
			# posed copy of the vertices.
			each += (surface.get("vertex_data", PackedByteArray()) as PackedByteArray).size()
	var bones := 0
	for node in root.find_children("*", "Skeleton3D", true, false):
		bones += (node as Skeleton3D).get_bone_count()
	var anims := []
	for node in root.find_children("*", "AnimationPlayer", true, false):
		for a in (node as AnimationPlayer).get_animation_list():
			anims.append("%s %.2fs" % [a, (node as AnimationPlayer).get_animation(a).length])
	root.free()
	print("%-18s %-9s %8.0f %7d %7d %5d %6d %9.1f %9.1f   %s" % [id, kind, file_kb, tris, verts, bones, shapes, shared / 1024.0, each / 1024.0, ", ".join(anims)])
