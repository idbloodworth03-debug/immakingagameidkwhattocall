"""Helpers for species built from another species' file."""


def recolor(module, colors):
    """`module`'s paint function, with some of its colors swapped."""
    def paint(mesh, creature):
        old = dict(module.COLORS)
        module.COLORS.update(colors)
        try:
            return module.paint(mesh, creature)
        finally:
            module.COLORS.clear()
            module.COLORS.update(old)
    return paint


def scaled(joints, k):
    return {name: tuple(x * k for x in p) for name, p in joints.items()}


def scaled_r(r, k, keep=("skull_pitch", "scapula_pitch", "thigh_pitch", "ear_yaw")):
    out = {}
    for key, value in r.items():
        if key in keep:
            out[key] = value
        elif isinstance(value, tuple):
            out[key] = tuple(x * k for x in value)
        else:
            out[key] = value * k
    return out
