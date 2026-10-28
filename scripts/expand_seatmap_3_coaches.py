#!/usr/bin/env python3
"""
Expands scripts/SeatMap_1coach_base.json so that EVERY ONE of the 7 KAI seat classes
has 3 connected coaches (Gerbong 1, Gerbong 2, Gerbong 3) with gangways, row numbers,
and varied seat availability across all 3 coaches.
Writes the result to both web/assets/data/SeatMap.json and flutter/assets/data/SeatMap.json.
"""
import copy
import json
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
BASE_PATH = ROOT_DIR / "scripts" / "SeatMap_1coach_base.json"
WEB_OUT = ROOT_DIR / "web" / "assets" / "data" / "SeatMap.json"
FLUTTER_OUT = ROOT_DIR / "flutter" / "assets" / "data" / "SeatMap.json"

COACHES_PER_CLASS = 3

CLASS_SPECS = [
    {
        "seatClass": "ordinary",
        "prefix": "Eko",
        "g_front": -8.50,
        "g_back": -26.05516,
    },
    {
        "seatClass": "ekonomiTosca",
        "prefix": "Eko Mod",
        "g_front": -26.05516,
        "g_back": -50.87265,
    },
    {
        "seatClass": "ekonomiPremium",
        "prefix": "Prem",
        "g_front": -50.87265,
        "g_back": -75.97477,
    },
    {
        "seatClass": "ekonomiNewGenDual",
        "prefix": "Eko ND",
        "g_front": -75.97477,
        "g_back": -100.81344,
    },
    {
        "seatClass": "green",
        "prefix": "Eko NG",
        "g_front": -100.81344,
        "g_back": -125.69410,
    },
    {
        "seatClass": "eksekutifDualTone",
        "prefix": "Eks NI",
        "g_front": -125.69410,
        "g_back": -150.50806,
    },
    {
        "seatClass": "granClass",
        "prefix": "Eks",
        "g_front": -150.50806,
        "g_back": -175.52900,
    },
]


def main():
    base = json.loads(BASE_PATH.read_text(encoding="utf-8"))
    sce_by_class = {s["seatClass"]: s for s in base["seatClassEntities"]}
    base_texts = base["transformedTextModelEntities"]

    new_global_statics = [
        {"modelEntity": "e7-main-shadow", "position": {"x": 0, "y": 0, "z": 0}},
        {"modelEntity": "e7-train-head-chasis", "position": {"x": 0, "y": 0, "z": -1.80336}},
    ]
    new_texts = []
    expanded_by_class = {}

    cursor_shift = 0.0
    next_seat_id = 1001

    for spec in CLASS_SPECS:
        sc = spec["seatClass"]
        prefix = spec["prefix"]
        g_front = spec["g_front"]
        g_back = spec["g_back"]
        span = g_front - g_back  # positive (~24.85m)

        orig_sce = copy.deepcopy(sce_by_class[sc])
        orig_statics = orig_sce["transformedModelEntities"]
        orig_seats = orig_sce["reservableEntities"]
        orig_vr = [orig_sce["viewableRange"][0]["z"], orig_sce["viewableRange"][1]["z"]]

        # Text nodes belonging to this coach
        cls_texts = [
            t for t in base_texts
            if (g_back - 0.5) <= t["position"]["z"] <= (g_front + 0.5)
        ]

        combined_statics = []
        combined_seats = []

        shift_first = cursor_shift
        shift_last = cursor_shift - (COACHES_PER_CLASS - 1) * span

        for k in range(COACHES_PER_CLASS):
            coach_num = k + 1
            car_label = f"{prefix} {coach_num}"
            shift_k = cursor_shift - k * span

            # 1. Replicate static cabin/partition/vestibule entities
            for st in orig_statics:
                if k > 0 and st["modelEntity"] == "e7-train-head-inside":
                    continue
                st_copy = copy.deepcopy(st)
                st_copy["position"]["z"] = round(st["position"]["z"] + shift_k, 5)
                combined_statics.append(st_copy)

            # 2. Replicate reservable seats with unique IDs, coach carNumber, and varied availability
            for s_idx, rev in enumerate(orig_seats):
                rev_copy = copy.deepcopy(rev)
                rev_copy["id"] = next_seat_id
                next_seat_id += 1
                rev_copy["carNumber"] = car_label
                rev_copy["transformedModelEntity"]["position"]["z"] = round(
                    rev["transformedModelEntity"]["position"]["z"] + shift_k, 5
                )
                if k > 0:
                    # Vary availability across Coach 2 and Coach 3 so each coach has a distinct realistic pattern
                    hash_val = (s_idx * 7 + k * 13) % 11
                    rev_copy["isAvailable"] = hash_val != 0 and hash_val != 5
                combined_seats.append(rev_copy)

            # 3. Replicate row number text nodes for this coach
            for t in cls_texts:
                t_copy = copy.deepcopy(t)
                t_copy["position"]["z"] = round(t["position"]["z"] + shift_k, 5)
                new_texts.append(t_copy)

            # 4. Add gangway at the back of this coach
            gangway_z = round(g_back + shift_k, 5)
            new_global_statics.append({
                "modelEntity": "e7-gangway",
                "position": {"x": 0, "y": 0, "z": gangway_z},
            })

        # Update class entity with 3 coaches
        orig_sce["carNumber"] = f"{prefix} 1–{COACHES_PER_CLASS}"
        orig_sce["transformedModelEntities"] = combined_statics
        orig_sce["reservableEntities"] = combined_seats
        new_lower_z = round(orig_vr[0] - shift_first, 2)
        new_upper_z = round(orig_vr[1] - shift_last, 2)
        orig_sce["viewableRange"] = [
            {"x": 0, "y": 0, "z": new_lower_z},
            {"x": 0, "y": 0, "z": new_upper_z},
        ]
        expanded_by_class[sc] = orig_sce

        # Advance cursor_shift by the (COACHES_PER_CLASS - 1) extra coaches added
        cursor_shift -= (COACHES_PER_CLASS - 1) * span

    # Add rear train head chassis at the end of the 21-coach train
    rear_head_z = round(-199.70214 + cursor_shift, 5)
    new_global_statics.append({
        "modelEntity": "e7-train-head-chasis",
        "position": {"x": 0, "y": 0, "z": rear_head_z},
    })

    # Preserve original class order in seatClassEntities
    out_data = {
        "id": base["id"],
        "name": base["name"],
        "transformedModelEntities": new_global_statics,
        "transformedTextModelEntities": new_texts,
        "seatClassEntities": [
            expanded_by_class[s["seatClass"]] for s in base["seatClassEntities"]
        ],
    }

    json_str = json.dumps(out_data, separators=(",", ":"))
    WEB_OUT.write_text(json_str, encoding="utf-8")
    FLUTTER_OUT.write_text(json_str, encoding="utf-8")

    for sce in out_data["seatClassEntities"]:
        cars = sorted(list(set(r["carNumber"] for r in sce["reservableEntities"])))
        vr = [sce["viewableRange"][0]["z"], sce["viewableRange"][1]["z"]]
        print(
            f"{sce['seatClass']:18s} | carNumber: {sce['carNumber']:12s} | coaches: {cars} | total seats: {len(sce['reservableEntities']):3d} | viewableRange: {vr}"
        )


if __name__ == "__main__":
    main()
