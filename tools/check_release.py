"""Fails if any testing switch in game/data/testing.json is still on.

Run it before a real release (the testing switches give endless gold, gems
and Acorns, unlock every animal and show the developer tools):

    python3 tools/check_release.py
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PATH = os.path.join(ROOT, "game", "data", "testing.json")


def switches_on():
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f)
    return [key for key, value in data.items() if not key.startswith("_") and value is True]


def main():
    on = switches_on()
    if on:
        print("Not ready for release: these testing switches are on in game/data/testing.json:")
        for key in on:
            print("  - " + key)
        print("Set them to false first.")
        return 1
    print("Release check passed: every testing switch is off.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
