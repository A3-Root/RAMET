"""Model category rules shared by the terrain 3D pack and the model library.

The planner colours and filters 3D objects by category, so the terrain pack
(build_3d.py) and the map-independent model library (build_models.py) must
agree on them — a Zeus-placed house and a terrain house should look the same.

Categories: tree, bush, rock, wall, building, vehicle, unit, other.
"""
from __future__ import annotations

# Values of a model's Geometry-LOD "map" named property.
_TREE = {"tree", "small tree"}
_BUSH = {"bush"}
_ROCK = {"rock", "rocks"}
_WALL = {"wall", "fence"}
_BUILDING = {"house", "building", "bunker", "chapel", "church", "fortress", "fuelstation",
             "hospital", "lighthouse", "ruin", "stack", "tourism", "transmitter",
             "view-tower", "watertower", "busstop", "quay", "powersolar", "powerwave",
             "powerwind", "shipwreck", "fountain", "cross"}

# Vehicles and people carry no useful "map" property, so they are recognised by
# where their model lives. Checked only after the map property has had its say.
_VEHICLE_HINTS = ("\\air\\", "\\air_f", "\\armor\\", "\\armor_f", "\\boat\\", "\\boat_f",
                  "\\cars\\", "\\car\\", "\\soft_f", "\\wheeled", "\\tracked", "\\heli",
                  "\\plane", "\\ship", "\\submarine", "\\vehicles\\", "\\static_f",
                  "\\drones", "\\uav")
_UNIT_HINTS = ("\\characters\\", "\\characters_f", "\\people\\", "\\men\\", "\\heads\\")
_WALL_HINTS = ("\\walls", "\\fence", "\\barrier", "\\barricade", "\\sandbag", "\\wire",
               "\\hedgehog", "\\gate", "\\door")
_BUILDING_HINTS = ("\\buildings", "\\structures", "\\house", "\\bunker", "\\ruins",
                   "\\industrial", "\\military", "\\furniture", "\\cargo")


def categorise(map_type: str, path: str) -> str:
    """Pick the planner category for one model."""
    t = (map_type or "").strip().lower()
    if t in _TREE:
        return "tree"
    if t in _BUSH:
        return "bush"
    if t in _ROCK:
        return "rock"
    if t in _WALL:
        return "wall"
    if t in _BUILDING:
        return "building"

    p = "\\" + (path or "").lower().replace("/", "\\").lstrip("\\")
    if "\\vegetation" in p or "\\plants" in p or "\\tree" in p:
        return "bush" if "\\bush" in p else "tree"
    if any(hint in p for hint in _UNIT_HINTS):
        return "unit"
    if any(hint in p for hint in _VEHICLE_HINTS):
        return "vehicle"
    if any(hint in p for hint in _WALL_HINTS):
        return "wall"
    if any(hint in p for hint in _BUILDING_HINTS):
        return "building"
    return "other"
