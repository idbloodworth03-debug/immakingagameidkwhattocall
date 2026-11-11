extends Node
## How every animal in the roster stands in battle, measured from its
## battle model: for tools/toys/sizes.py, which keeps an animal exactly as
## tall on screen when its art changes (bodies.json size is its longest
## side as drawn, so a model of other proportions needs another size to
## stand as tall).
##   godot --headless --path game res://tests/stand_report.tscn
## The last line (STANDS {...}) gives, per animal: stands (how tall it is
## drawn standing, in field tiles: its outline in its idle pose), size and
## pose_up as bodies.json has them, pose_up as its model measures now, the
## share of its longest side that it stands tall (up_share), the share of
## its longest side that its longest side on the ground is (flat_share: 1
## unless it is taller than it is long), and whether it is a toy (the
## flat-color look).


func _ready() -> void:
	var out := {}
	for id: String in GameData.card_order:
		if GameData.is_tool(id) or not ModelStage.has_model(id):
			continue
		var box := ModelStage.natural_box(id)
		var m := ModelStage.new_model(id, 1.0, true)
		add_child(m.pivot)
		var share := ModelStage.tallest_share(m)
		var toy := m.toon
		m.pivot.free()
		var body: Dictionary = GameData.bodies.animals.get(id, {})
		var size := float(body.get("size", 1.0))
		var up_share := float(box.up) / maxf(0.0001, float(box.longest))
		out[id] = {
			"stands": snappedf(up_share * size, 0.001), "size": size, "pose_up": float(body.get("pose_up", 1.0)),
			"pose_up_now": snappedf(share, 0.001), "up_share": snappedf(up_share, 0.0001),
			"flat_share": snappedf(_flat_share(id), 0.0001), "toy": toy}
	print("STANDS " + JSON.stringify(out))
	get_tree().quit()


## Its longest side on the ground (the longer of its length and its width
## at rest) as a share of its longest side of all.
func _flat_share(id: String) -> float:
	var root := (load("res://art/models/battle/%s.glb" % id) as PackedScene).instantiate() as Node3D
	var box := AABB()
	var first := true
	for mesh in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		var xf := mi.transform
		var p := mi.get_parent()
		while p != null and p != root:
			if p is Node3D:
				xf = (p as Node3D).transform * xf
			p = p.get_parent()
		var b: AABB = xf * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	root.free()
	if first:
		return 1.0
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	return maxf(box.size.x, box.size.z) / maxf(0.0001, longest)
