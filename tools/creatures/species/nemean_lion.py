"""Nemean Lion: the golden lion of Greek myth whose coat no weapon could
pierce, made shiny and proud: a lion with a gleaming golden coat, a huge
fiery-gold mane and bright amber eyes.

Mythical. Built from the lion.
"""
import lion as L
from derive import recolor


def make():
    c = L.make()
    c.name = "nemean_lion"
    c.paint = recolor(L, {"tawny": "#f2c454", "back": "#dca43a", "pale": "#fbe9b4", "mane": "#b04a12", "mane_dark": "#7a2a08",
                          "black": "#5a3410"})
    c.fur = dict(c.fur, sheen=0.6)
    c.tiles_long = 2.5
    c.palette = dict(c.palette or {}, mythic_glow="#ffd36a")
    return c
