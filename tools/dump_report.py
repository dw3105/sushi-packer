#!/usr/bin/env python3
"""Print sushi-packer technologies and recipes from a Factorio raw data dump."""
import json
import sys


def ingredient_name_amount(value):
    if isinstance(value, dict):
        return value.get("name", ""), value.get("amount", "")
    return value[0], value[1]


def main(path):
    with open(path) as f:
        dump = json.load(f)
    technologies = dump.get("technology", {})
    recipes = dump.get("recipe", {})
    for name in sorted(n for n in technologies if n.endswith("sushi-packer")):
        tech = technologies[name]
        unit = tech.get("unit")
        prereq = ",".join(tech.get("prerequisites", []))
        packs = ",".join(ingredient_name_amount(i)[0] for i in (unit or {}).get("ingredients", []))
        count = (unit or {}).get("count", "-")
        print(f"TECH {name} prereq={prereq} packs={packs} count={count}")
    for name in sorted(n for n in recipes if n.endswith("sushi-packer")):
        recipe = recipes[name]
        ingredients = ",".join(f"{ingredient_name_amount(i)[0]}:{ingredient_name_amount(i)[1]}"
                               for i in recipe.get("ingredients", []))
        print(f"RECIPE {name} {ingredients}")
    print(f"dump-report-ok {path}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: tools/dump_report.py <data-raw-dump.json>")
    main(sys.argv[1])
