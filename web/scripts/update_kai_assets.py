import json

# 1. Update models.json with KAI Next Gen Stainless Steel (Argo Bromo Anggrek) colors
with open("web/assets/scn/models.json", "r") as f:
    models = json.load(f)

# Colors from Image 2 (KAI Eksekutif Next Gen Burgundy Winged Leather Seat + Cabin)
BURGUNDY_MAIN = [0.490, 0.216, 0.278, 1.0]      # #7D3747 Maroon/Burgundy leather
BURGUNDY_DARK = [0.396, 0.161, 0.216, 1.0]      # #652937 Deep Burgundy bolster/seam
BURGUNDY_HEAD = [0.467, 0.200, 0.263, 1.0]      # #773343 Burgundy winged headrest
BURGUNDY_HI_MAIN = [0.345, 0.133, 0.184, 1.0]   # Highlighted dark burgundy
BURGUNDY_HI_DARK = [0.275, 0.102, 0.145, 1.0]
TEAK_WOOD = [0.620, 0.420, 0.231, 1.0]          # #9E6B3B Wooden armrest top trim
SILVER_SHELL = [0.557, 0.592, 0.651, 1.0]       # #8E97A6 Cool grey/silver side shell
ICE_DIVIDER = [0.722, 0.780, 0.863, 1.0]        # #B8C7DC Light blue-silver center divider
DARK_BASE = [0.180, 0.192, 0.224, 1.0]          # #2E3139 Pedestal base

# Cabin Interior Colors (Image 2)
FLOOR_UNDER_SEAT = [0.400, 0.420, 0.455, 1.0]   # #666B74 Dark speckled grey
FLOOR_AISLE = [0.465, 0.490, 0.525, 1.0]        # #777D86 Speckled grey aisle
CABIN_WALL_CREAM = [0.918, 0.902, 0.875, 1.0]   # #EAE6DF Cream interior wall
CABIN_RACK_CREAM = [0.875, 0.859, 0.831, 1.0]   # #DFDBD4 Overhead rack
STAINLESS_BODY = [0.765, 0.780, 0.804, 1.0]     # #C3C7CD Stainless steel exterior
ARGO_MAGENTA = [0.847, 0.169, 0.475, 1.0]       # #D82B79 Argo Bromo Anggrek magenta
LUXURY_GOLD = [0.855, 0.686, 0.216, 1.0]        # #DAAF37 Luxury gold

def update_material_list(mats, model_name):
    for m in mats:
        name = (m.get("name") or "").strip()
        # Eksekutif Next Gen Seat (green & ordinary seats)
        if model_name in ("e7-green-seat-a", "e7-green-seat-b", "e7-ordinary-seat-a", "e7-ordinary-seat-b", "e7-ordinary-seat-c", "e7-ordinary-seat-d", "e7-ordinary-seat-e"):
            if name in ("seat-cloth-1-normal", "dark-gray-normal"):
                m["diffuse"] = {"type": "color", "color": BURGUNDY_DARK}
            elif name in ("seat-cloth-2-normal", "red-normal"):
                m["diffuse"] = {"type": "color", "color": BURGUNDY_MAIN}
            elif name in ("seat-cloth-3-normal", "seat-plasict-cream-normal"):
                m["diffuse"] = {"type": "color", "color": TEAK_WOOD}
            elif name in ("seat-cloth-white-normal", "off-white-normal"):
                m["diffuse"] = {"type": "color", "color": BURGUNDY_HEAD}
            elif name in ("seat-gray-normal", "gray-normal"):
                m["diffuse"] = {"type": "color", "color": SILVER_SHELL}
            elif name in ("seat-plastic-black-normal", "off-black-normal"):
                m["diffuse"] = {"type": "color", "color": DARK_BASE}
            elif name in ("seat-cloth-1-highlighted", "dark-gray-highlighted"):
                m["diffuse"] = {"type": "color", "color": BURGUNDY_HI_DARK}
            elif name in ("seat-cloth-2-highlighted", "red-highlighted", "off-white-highlighted", "seat-cloth-white-highlighted"):
                m["diffuse"] = {"type": "color", "color": BURGUNDY_HI_MAIN}
            elif name in ("seat-cloth-3-highlighted",):
                m["diffuse"] = {"type": "color", "color": TEAK_WOOD}

        # Complete 3D Seat Preview for Confirmation Screen (_e7_green_seat_complete & _e7_ordinary_seat_complete)
        if model_name == "_e7_green_seat_complete":
            # Elements 0..7 in e7_green_seat_complete:
            # 0: outer cloth, 1: inner cloth, 2,3: armrest cream, 4: headrest, 5: side gray, 6: base black, 7: shadow plane
            pass

        # Cabin section floors & walls
        if "seat-section" in model_name or "partition" in model_name or "alley" in model_name or "entrance" in model_name or "multipurpose" in model_name:
            if "floor-a-normal" in name or "section-floor-normal" in name or "partition-floor-normal" in name or "alley-floor-normal" in name:
                if "gran" not in name and "gran" not in model_name:
                    m["diffuse"] = {"type": "color", "color": FLOOR_UNDER_SEAT}
            elif "floor-b-normal" in name:
                m["diffuse"] = {"type": "color", "color": FLOOR_AISLE}
            elif "wall-a-normal" in name or "partition-wall-normal" in name or "alley-wall-normal" in name:
                m["diffuse"] = {"type": "color", "color": CABIN_WALL_CREAM}
            elif "wall-b-normal" in name:
                m["diffuse"] = {"type": "color", "color": CABIN_RACK_CREAM}
            elif "cross-body" in name:
                m["diffuse"] = {"type": "color", "color": STAINLESS_BODY}

        # Train exterior head / chassis -> KAI Stainless Steel Next Gen livery
        if model_name == "e7-train-head-chasis":
            if "body-1" in name:
                m["diffuse"] = {"type": "color", "color": STAINLESS_BODY}
            elif "body-2" in name:
                m["diffuse"] = {"type": "color", "color": ARGO_MAGENTA}
            elif "body-3" in name:
                m["diffuse"] = {"type": "color", "color": [0.16, 0.18, 0.22, 1.0]}

    # Special positional material update for _e7_green_seat_complete and _e7_ordinary_seat_complete
    if model_name == "_e7_green_seat_complete" and len(mats) >= 7:
        mats[0]["diffuse"] = {"type": "color", "color": BURGUNDY_DARK}
        mats[1]["diffuse"] = {"type": "color", "color": BURGUNDY_MAIN}
        mats[2]["diffuse"] = {"type": "color", "color": TEAK_WOOD}
        mats[3]["diffuse"] = {"type": "color", "color": TEAK_WOOD}
        mats[4]["diffuse"] = {"type": "color", "color": BURGUNDY_HEAD}
        mats[5]["diffuse"] = {"type": "color", "color": SILVER_SHELL}
        mats[6]["diffuse"] = {"type": "color", "color": DARK_BASE}

    if model_name == "_e7_ordinary_seat_complete" and len(mats) >= 5:
        mats[0]["diffuse"] = {"type": "color", "color": BURGUNDY_MAIN}
        mats[1]["diffuse"] = {"type": "color", "color": BURGUNDY_DARK}
        mats[2]["diffuse"] = {"type": "color", "color": BURGUNDY_HEAD}
        mats[3]["diffuse"] = {"type": "color", "color": TEAK_WOOD}
        mats[4]["diffuse"] = {"type": "color", "color": DARK_BASE}

    if model_name == "_e7_gran_seat_complete" and len(mats) >= 6:
        mats[0]["diffuse"] = {"type": "color", "color": [0.95, 0.91, 0.84, 1.0]} # Champagne leather
        mats[1]["diffuse"] = {"type": "color", "color": [0.91, 0.86, 0.76, 1.0]}
        mats[2]["diffuse"] = {"type": "color", "color": [0.96, 0.93, 0.88, 1.0]}
        mats[3]["diffuse"] = {"type": "color", "color": TEAK_WOOD}
        mats[4]["diffuse"] = {"type": "color", "color": [0.22, 0.24, 0.29, 1.0]}

def walk_node(node, model_name):
    if "geometry" in node and "allMaterials" in node["geometry"]:
        update_material_list(node["geometry"]["allMaterials"], model_name)
    for ch in node.get("children", []):
        walk_node(ch, model_name)

for mname, mdata in models.items():
    walk_node(mdata["rootNode"], mname)

with open("web/assets/scn/models.json", "w") as f:
    json.dump(models, f)
print("Updated web/assets/scn/models.json with KAI Next Gen materials.")

# 2. Update SeatMap.json so ALL Eksekutif cars use 2+2 KAI Eksekutif Next Gen seats and KAI car names
with open("web/assets/data/SeatMap.json", "r") as f:
    seat_map = json.load(f)

seat_map["name"] = "Argo Bromo Anggrek Next Gen"

for sce in seat_map["seatClassEntities"]:
    if sce["seatClass"] == "granClass":
        sce["name"] = "Luxury"
        sce["carNumber"] = "Luxury 1"
        for rev in sce["reservableEntities"]:
            rev["carNumber"] = "Luxury 1"
    elif sce["seatClass"] == "green":
        sce["name"] = "Eksekutif"
        sce["carNumber"] = "Eks 1"
        for rev in sce["reservableEntities"]:
            rev["carNumber"] = "Eks 1"
    elif sce["seatClass"] == "ordinary":
        sce["name"] = "Eksekutif (H)"
        sce["carNumber"] = "Eks 2–6"
        # Convert Car 1..6 from 3+2 to 2+2 (A, B on left x=1.2193, 0.5988; C, D on right x=-0.5988, -1.2193) using e7-green-seat-a/b!
        new_reservables = []
        for rev in sce["reservableEntities"]:
            seat_name = rev["name"] # e.g. "1A", "1B", "1C", "1D", "1E"
            letter = seat_name[-1]
            row_str = seat_name[:-1]
            if letter == "E":
                continue # 2+2 has only A, B, C, D!
            old_car = rev["carNumber"] # "Car 1" .. "Car 6"
            car_num = old_car.replace("Car ", "")
            rev["carNumber"] = f"Eks {int(car_num) + 1}" if car_num.isdigit() else "Eks 2"
            pos = rev["transformedModelEntity"]["position"]
            if letter == "A":
                pos["x"] = 1.2193
                rev["transformedModelEntity"]["modelEntity"] = "e7-green-seat-a"
            elif letter == "B":
                pos["x"] = 0.5988
                rev["transformedModelEntity"]["modelEntity"] = "e7-green-seat-b"
            elif letter == "C":
                pos["x"] = -0.5988
                rev["transformedModelEntity"]["modelEntity"] = "e7-green-seat-a"
            elif letter == "D":
                pos["x"] = -1.2193
                rev["transformedModelEntity"]["modelEntity"] = "e7-green-seat-b"
            new_reservables.append(rev)
        sce["reservableEntities"] = new_reservables
        # Remove old 3+2 seat legs and use green-seat-section for 2+2 aisle
        new_statics = []
        for st in sce["transformedModelEntities"]:
            me = st["modelEntity"]
            if me in ("e7-ordinary-leg-a-to-c", "e7-ordinary-leg-d-to-e"):
                continue
            if me == "e7-ordinary-seat-section":
                st["modelEntity"] = "e7-green-seat-section"
            elif me == "e7-ordinary-seat-section-ending-a":
                st["modelEntity"] = "e7-green-seat-section-ending-a"
            elif me == "e7-ordinary-seat-section-ending-b":
                st["modelEntity"] = "e7-green-seat-section-ending-b"
            new_statics.append(st)
        sce["transformedModelEntities"] = new_statics

with open("web/assets/data/SeatMap.json", "w") as f:
    json.dump(seat_map, f)
print("Updated web/assets/data/SeatMap.json with 2+2 KAI Eksekutif Next Gen layout.")

# 3. Update TrainCriteria.json with Indonesian KAI trains (Gambir -> Surabaya Ps. Turi)
with open("web/assets/data/TrainCriteria.json", "r") as f:
    tc = json.load(f)

tc["fromStationName"] = "Gambir"
tc["fromStationJPName"] = "GMR"
tc["toStationName"] = "Surabaya Ps. Turi"
tc["toStationJPName"] = "SBI"

kai_trains = [
    ("Argo Bromo 2", "Next Gen Stainless", "e7-series", True),
    ("Sembrani 62", "Stainless New Gen", "e5-series", True),
    ("Argo Bromo 4", "Next Gen Stainless", "e7-series", True),
    ("Gumarang 70", "Stainless Steel", "e6-series", False),
    ("Sembrani 64", "Stainless New Gen", "e5-series", True),
    ("Jayabaya 108", "Stainless New Gen", "e2-series", False),
    ("Argo Bromo 6", "Next Gen Stainless", "e4-series", True),
    ("Kertajaya 218", "Stainless New Gen", "e3-series", False),
]

for idx, sched in enumerate(tc["trainSchedules"]):
    t_num, t_series, t_img, has_luxury = kai_trains[idx % len(kai_trains)]
    sched["trainNumber"] = t_num
    sched["trainName"] = t_series
    sched["trainImageName"] = t_img

    classes = []
    if has_luxury:
        classes.append({
            "id": 0,
            "seatClass": "granClass",
            "isAvailable": True,
            "name": "Luxury",
            "description": "Kursi sleeper elektrik 170° dengan partisi privasi, hiburan VOD, & layanan makan.",
            "price": 1350000
        })
    classes.append({
        "id": 1,
        "seatClass": "green",
        "isAvailable": True,
        "name": "Eksekutif",
        "description": "Kursi kulit maroon ergonomis 2+2 dengan winged headrest, footrest, & armrest kayu.",
        "price": 650000
    })
    classes.append({
        "id": 2,
        "seatClass": "ordinary",
        "isAvailable": True,
        "name": "Eksekutif (H)",
        "description": "Konfigurasi kursi 2+2 captain seat ergonomis di rangkaian Next Gen Stainless Steel.",
        "price": 580000
    })
    sched["seatClasses"] = classes

with open("web/assets/data/TrainCriteria.json", "w") as f:
    json.dump(tc, f, indent=2)
print("Updated web/assets/data/TrainCriteria.json with KAI Argo Bromo Anggrek schedules.")

