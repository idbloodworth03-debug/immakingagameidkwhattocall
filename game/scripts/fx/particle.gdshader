shader_type canvas_item;
// Particles (ParticleLayer): every particle is one instance of a quad,
// showing one cell of the particle sheet (art/ui/particles.png). The cell
// comes in INSTANCE_CUSTOM.x; the tint and fade come in the instance color.

uniform vec2 grid = vec2(4.0, 3.0);

void vertex() {
	float cell = INSTANCE_CUSTOM.x;
	vec2 at = vec2(mod(cell, grid.x), floor(cell / grid.x));
	UV = (at + UV) / grid;
}
