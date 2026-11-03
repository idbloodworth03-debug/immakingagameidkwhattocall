class_name GroundArt
extends RefCounted
## The round shapes under every animal (shadow, team ring, class badge disc),
## made once as one small texture. Drawn as stretched pictures from it, a
## whole herd's shapes go out in a single batch; drawn as flattened circles
## and arcs they cost a few draw calls per animal, which a big fight on a
## phone feels.

## Each shape's square in the texture.
enum Cell { SHADOW, DISC, RING, LINE }
## Where each ring sits in its square (0..1 of the square's half-width).
const RING_AT := 0.93

const SIZE := 96
static var _texture: Texture2D


static func texture() -> Texture2D:
	if _texture == null:
		var image := Image.create(SIZE * 4, SIZE, false, Image.FORMAT_RGBA8)
		var half := SIZE / 2.0
		for cell in 4:
			for y in SIZE:
				for x in SIZE:
					var d := Vector2(x + 0.5 - half, y + 0.5 - half).length() / half
					image.set_pixel(cell * SIZE + x, y, Color(1, 1, 1, _alpha(cell, d)))
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
	return _texture


static func _alpha(cell: int, d: float) -> float:
	var edge := 1.5 / (SIZE / 2.0)  # a soft pixel and a half at the edge
	match cell:
		Cell.SHADOW:
			return clampf(1.0 - smoothstep(0.55, 1.0, d), 0.0, 1.0)
		Cell.DISC:
			return clampf((1.0 - d) / edge, 0.0, 1.0)
		Cell.RING:
			return clampf(minf((1.0 - d) / edge, (d - 0.86) / edge), 0.0, 1.0)
		Cell.LINE:
			return clampf(minf((0.965 - d) / edge, (d - 0.895) / edge), 0.0, 1.0)
	return 0.0


static func region(cell: int) -> Rect2:
	return Rect2(cell * SIZE, 0, SIZE, SIZE)


## A shape centered at `at`, `radius` wide and `radius * squash` tall.
static func draw(canvas: CanvasItem, cell: int, at: Vector2, radius: float, squash: float, color: Color) -> void:
	var size := Vector2(radius, radius * squash)
	canvas.draw_texture_rect_region(texture(), Rect2(at - size, size * 2.0), region(cell), color)


## A ring whose line runs at `radius`.
static func draw_ring(canvas: CanvasItem, cell: int, at: Vector2, radius: float, squash: float, color: Color) -> void:
	draw(canvas, cell, at, radius / RING_AT, squash, color)
