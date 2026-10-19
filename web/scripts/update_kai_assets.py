import json
import copy

# Load base models.json (re-extract or use existing structure)
with open("web/assets/scn/models.json", "r") as f:
    models = json.load(f)

# Load original SeatMap.json from Xcode dataset as clean starting point
with open("Shinkansen3DSeatBookingPrototype/Assets.xcassets/Data Sources/SeatMap.dataset/SeatMap.json", "r") as f:
    orig_seat_map = json.load(f)

# ==============================================================================
# Color Palettes for the 4 Indonesian KAI Seat Classes
# ==============================================================================
# 1. Eksekutif Next Gen (Maroon 2-2)
MAROON_MAIN = [0.490, 0.216, 0.278, 1.0]      # #7D3747
MAROON_DARK = [0.396, 0.161, 0.216, 1.0]      # #652937
MAROON_HEAD = [0.467, 0.200, 0.263, 1.0]      # #773343
MAROON_HI_MAIN = [0.345, 0.133, 0.184, 1.0]
MAROON_HI_DARK = [0.275, 0.102, 0.145, 1.0]
TEAK_WOOD = [0.620, 0.420, 0.231, 1.0]        # #9E6B3B
SILVER_SHELL = [0.557, 0.592, 0.651, 1.0]     # #8E97A6
DARK_BASE = [0.180, 0.192, 0.224, 1.0]

# 2. Ekonomi New Gen / Eksekutif Biru (Navy/Slate Blue 2-2)
BLUE_MAIN = [0.298, 0.388, 0.569, 1.0]        # #4C6391
BLUE_DARK = [0.224, 0.302, 0.463, 1.0]        # #394D76
BLUE_HEAD = [0.278, 0.369, 0.545, 1.0]        # #475E8B
BLUE_HI_MAIN = [0.196, 0.267, 0.412, 1.0]
BLUE_HI_DARK = [0.149, 0.208, 0.333, 1.0]
BROWN_WOOD = [0.545, 0.392, 0.255, 1.0]       # #8B6441
LIGHT_SHELL = [0.784, 0.804, 0.839, 1.0]      # #C8CDD6

# 3. Ekonomi Premium (Warm Taupe / Beige / Tan 2-2)
PREM_MAIN = [0.655, 0.580, 0.522, 1.0]        # #A79485
PREM_DARK = [0.549, 0.478, 0.424, 1.0]        # #8C7A6C
PREM_HEAD = [0.635, 0.561, 0.502, 1.0]        # #A28F80
PREM_HI_MAIN = [0.482, 0.416, 0.365, 1.0]
PREM_HI_DARK = [0.400, 0.341, 0.298, 1.0]
ESPRESSO_ARM = [0.235, 0.184, 0.157, 1.0]     # #3C2F28
CHROME_FRAME = [0.784, 0.812, 0.847, 1.0]     # #C8CFD8

# 4. Ekonomi 2-3 Reguler (Cream / Khaki Bench 3-2 + Tubular Steel Frame)
EKO_CREAM_MAIN = [0.737, 0.690, 0.592, 1.0]   # #BCBO97
EKO_CREAM_DARK = [0.643, 0.596, 0.502, 1.0]   # #A49880
EKO_CREAM_HEAD = [0.753, 0.706, 0.608, 1.0]   # #C0B49B
EKO_HI_MAIN = [0.565, 0.522, 0.435, 1.0]
EKO_ARM_BLACK = [0.200, 0.184, 0.173, 1.0]    # #332F2C
EKO_STEEL_PIPE = [0.776, 0.804, 0.835, 1.0]   # #C6CDD5

# Cabin Floor & Wall Palettes
FLOOR_MAROON_A = [0.400, 0.420, 0.455, 1.0]
FLOOR_MAROON_B = [0.465, 0.490, 0.525, 1.0]

FLOOR_BLUE_A = [0.553, 0.580, 0.620, 1.0]     # Glossy light-grey floor
FLOOR_BLUE_B = [0.620, 0.647, 0.686, 1.0]

FLOOR_PREM_A = [0.369, 0.345, 0.333, 1.0]     # Dark brownish-grey floor
FLOOR_PREM_B = [0.424, 0.396, 0.380, 1.0]

FLOOR_EKO_GREEN = [0.510, 0.647, 0.455, 1.0]  # #82A574 Sage green linoleum floor

CABIN_WALL_CREAM = [0.918, 0.902, 0.875, 1.0]
CABIN_RACK_CREAM = [0.875, 0.859, 0.831, 1.0]
STAINLESS_BODY = [0.765, 0.780, 0.804, 1.0]

def recolor_green_seat_clone(model_obj, main_c, dark_c, head_c, arm_c, shell_c, hi_main, hi_dark):
    def walk(node):
        if "geometry" in node and "allMaterials" in node["geometry"]:
            for m in node["geometry"]["allMaterials"]:
                nm = (m.get("name") or "").strip()
                if nm == "seat-cloth-1-normal":
                    m["diffuse"] = {"type": "color", "color": dark_c}
                elif nm == "seat-cloth-2-normal":
                    m["diffuse"] = {"type": "color", "color": main_c}
                elif nm in ("seat-cloth-3-normal", "seat-plasict-cream-normal"):
                    m["diffuse"] = {"type": "color", "color": arm_c}
                elif nm == "seat-cloth-white-normal":
                    m["diffuse"] = {"type": "color", "color": head_c}
                elif nm == "seat-gray-normal":
                    m["diffuse"] = {"type": "color", "color": shell_c}
                elif nm == "seat-plastic-black-normal":
                    m["diffuse"] = {"type": "color", "color": DARK_BASE}
                elif nm == "seat-cloth-1-highlighted":
                    m["diffuse"] = {"type": "color", "color": hi_dark}
                elif nm in ("seat-cloth-2-highlighted", "seat-cloth-white-highlighted"):
                    m["diffuse"] = {"type": "color", "color": hi_main}
                elif nm == "seat-cloth-3-highlighted":
                    m["diffuse"] = {"type": "color", "color": arm_c}
        for c in node.get("children", []):
            walk(c)
    walk(model_obj["rootNode"])

def recolor_complete_2seat_clone(model_obj, main_c, dark_c, head_c, arm_c, shell_c):
    mats = model_obj["rootNode"]["children"][0]["geometry"]["allMaterials"]
    if len(mats) >= 7:
        mats[0]["diffuse"] = {"type": "color", "color": dark_c}
        mats[1]["diffuse"] = {"type": "color", "color": main_c}
        mats[2]["diffuse"] = {"type": "color", "color": arm_c}
        mats[3]["diffuse"] = {"type": "color", "color": arm_c}
        mats[4]["diffuse"] = {"type": "color", "color": head_c}
        mats[5]["diffuse"] = {"type": "color", "color": shell_c}
        mats[6]["diffuse"] = {"type": "color", "color": DARK_BASE}

def recolor_section_clone(model_obj, floor_a, floor_b):
    def walk(node):
        if "geometry" in node and "allMaterials" in node["geometry"]:
            for m in node["geometry"]["allMaterials"]:
                nm = (m.get("name") or "").strip()
                if "floor-a-normal" in nm or "section-floor-normal" in nm or "partition-floor-normal" in nm:
                    m["diffuse"] = {"type": "color", "color": floor_a}
                elif "floor-b-normal" in nm:
                    m["diffuse"] = {"type": "color", "color": floor_b}
                elif "wall-a-normal" in nm or "partition-wall-normal" in nm:
                    m["diffuse"] = {"type": "color", "color": CABIN_WALL_CREAM}
                elif "wall-b-normal" in nm:
                    m["diffuse"] = {"type": "color", "color": CABIN_RACK_CREAM}
                elif "cross-body" in nm:
                    m["diffuse"] = {"type": "color", "color": STAINLESS_BODY}
        for c in node.get("children", []):
            walk(c)
    walk(model_obj["rootNode"])

# Create dedicated clones in models.json for:
# 1. Maroon Eksekutif Next Gen (kai-maroon-*)
for suffix in ("a", "b"):
    m_clone = copy.deepcopy(models[f"e7-green-seat-{suffix}"])
    m_clone["name"] = f"kai-maroon-seat-{suffix}"
    recolor_green_seat_clone(m_clone, MAROON_MAIN, MAROON_DARK, MAROON_HEAD, TEAK_WOOD, SILVER_SHELL, MAROON_HI_MAIN, MAROON_HI_DARK)
    models[f"kai-maroon-seat-{suffix}"] = m_clone

for sec_name in ("e7-green-seat-section", "e7-green-seat-section-ending-a", "e7-green-seat-section-ending-b", "e7-green-seat-partition-a", "e7-green-seat-partition-b"):
    new_name = sec_name.replace("e7-green-seat-", "kai-maroon-")
    s_clone = copy.deepcopy(models[sec_name])
    s_clone["name"] = new_name
    recolor_section_clone(s_clone, FLOOR_MAROON_A, FLOOR_MAROON_B)
    models[new_name] = s_clone

c_maroon = copy.deepcopy(models["_e7_green_seat_complete"])
c_maroon["name"] = "_kai_maroon_seat_complete"
recolor_complete_2seat_clone(c_maroon, MAROON_MAIN, MAROON_DARK, MAROON_HEAD, TEAK_WOOD, SILVER_SHELL)
models["_kai_maroon_seat_complete"] = c_maroon

# 2. Navy Blue Ekonomi New Gen (kai-blue-* and e7-green-seat-*)
for suffix in ("a", "b"):
    b_clone = copy.deepcopy(models[f"e7-green-seat-{suffix}"])
    b_clone["name"] = f"kai-blue-seat-{suffix}"
    recolor_green_seat_clone(b_clone, BLUE_MAIN, BLUE_DARK, BLUE_HEAD, BROWN_WOOD, LIGHT_SHELL, BLUE_HI_MAIN, BLUE_HI_DARK)
    models[f"kai-blue-seat-{suffix}"] = b_clone
    # Also update e7-green-seat-* in place
    recolor_green_seat_clone(models[f"e7-green-seat-{suffix}"], BLUE_MAIN, BLUE_DARK, BLUE_HEAD, BROWN_WOOD, LIGHT_SHELL, BLUE_HI_MAIN, BLUE_HI_DARK)

for sec_name in ("e7-green-seat-section", "e7-green-seat-section-ending-a", "e7-green-seat-section-ending-b", "e7-green-seat-partition-a", "e7-green-seat-partition-b"):
    new_name = sec_name.replace("e7-green-seat-", "kai-blue-")
    s_clone = copy.deepcopy(models[sec_name])
    s_clone["name"] = new_name
    recolor_section_clone(s_clone, FLOOR_BLUE_A, FLOOR_BLUE_B)
    models[new_name] = s_clone
    recolor_section_clone(models[sec_name], FLOOR_BLUE_A, FLOOR_BLUE_B)

c_blue = copy.deepcopy(models["_e7_green_seat_complete"])
c_blue["name"] = "_kai_blue_seat_complete"
recolor_complete_2seat_clone(c_blue, BLUE_MAIN, BLUE_DARK, BLUE_HEAD, BROWN_WOOD, LIGHT_SHELL)
models["_kai_blue_seat_complete"] = c_blue
recolor_complete_2seat_clone(models["_e7_green_seat_complete"], BLUE_MAIN, BLUE_DARK, BLUE_HEAD, BROWN_WOOD, LIGHT_SHELL)

# 3. Taupe/Tan Ekonomi Premium (kai-prem-*)
for suffix in ("a", "b"):
    p_clone = copy.deepcopy(models[f"e7-green-seat-{suffix}"])
    p_clone["name"] = f"kai-prem-seat-{suffix}"
    recolor_green_seat_clone(p_clone, PREM_MAIN, PREM_DARK, PREM_HEAD, ESPRESSO_ARM, CHROME_FRAME, PREM_HI_MAIN, PREM_HI_DARK)
    models[f"kai-prem-seat-{suffix}"] = p_clone

for sec_name in ("e7-green-seat-section", "e7-green-seat-section-ending-a", "e7-green-seat-section-ending-b", "e7-green-seat-partition-a", "e7-green-seat-partition-b"):
    new_name = sec_name.replace("e7-green-seat-", "kai-prem-")
    s_clone = copy.deepcopy(models[sec_name])
    s_clone["name"] = new_name
    recolor_section_clone(s_clone, FLOOR_PREM_A, FLOOR_PREM_B)
    models[new_name] = s_clone

c_prem = copy.deepcopy(models["_e7_green_seat_complete"])
c_prem["name"] = "_kai_prem_seat_complete"
recolor_complete_2seat_clone(c_prem, PREM_MAIN, PREM_DARK, PREM_HEAD, ESPRESSO_ARM, CHROME_FRAME)
models["_kai_prem_seat_complete"] = c_prem

# 4. Cream/Khaki Ekonomi 2-3 Bench (e7-ordinary-seat-a..e, e7-ordinary-seat-section*, _e7_ordinary_seat_complete)
for suffix in ("a", "b", "c", "d", "e"):
    om = models[f"e7-ordinary-seat-{suffix}"]
    def walk_ord(node):
        if "geometry" in node and "allMaterials" in node["geometry"]:
            for m in node["geometry"]["allMaterials"]:
                nm = (m.get("name") or "").strip()
                if nm == "red-normal":
                    m["diffuse"] = {"type": "color", "color": EKO_CREAM_MAIN}
                elif nm == "dark-gray-normal":
                    m["diffuse"] = {"type": "color", "color": EKO_CREAM_DARK}
                elif nm == "off-white-normal":
                    m["diffuse"] = {"type": "color", "color": EKO_CREAM_HEAD}
                elif nm == "gray-normal":
                    m["diffuse"] = {"type": "color", "color": EKO_STEEL_PIPE}
                elif nm == "off-black-normal":
                    m["diffuse"] = {"type": "color", "color": EKO_ARM_BLACK}
                elif nm in ("red-highlighted", "dark-gray-highlighted", "off-white-highlighted"):
                    m["diffuse"] = {"type": "color", "color": EKO_HI_MAIN}
        for c in node.get("children", []):
            walk_ord(c)
    walk_ord(om["rootNode"])

for leg_name in ("e7-ordinary-leg-a-to-c", "e7-ordinary-leg-d-to-e"):
    def walk_leg(node):
        if "geometry" in node and "allMaterials" in node["geometry"]:
            for m in node["geometry"]["allMaterials"]:
                if "normal" in (m.get("name") or ""):
                    m["diffuse"] = {"type": "color", "color": EKO_STEEL_PIPE}
        for c in node.get("children", []):
            walk_leg(c)
    walk_leg(models[leg_name]["rootNode"])

for sec_name in ("e7-ordinary-seat-section", "e7-ordinary-seat-section-ending-a", "e7-ordinary-seat-section-ending-b", "e7-ordinary-seat-partition-a", "e7-ordinary-seat-partition-b"):
    recolor_section_clone(models[sec_name], FLOOR_EKO_GREEN, FLOOR_EKO_GREEN)

ord_comp_mats = models["_e7_ordinary_seat_complete"]["rootNode"]["children"][0]["geometry"]["allMaterials"]
if len(ord_comp_mats) >= 5:
    ord_comp_mats[0]["diffuse"] = {"type": "color", "color": EKO_CREAM_MAIN}
    ord_comp_mats[1]["diffuse"] = {"type": "color", "color": EKO_CREAM_DARK}
    ord_comp_mats[2]["diffuse"] = {"type": "color", "color": EKO_CREAM_HEAD}
    ord_comp_mats[3]["diffuse"] = {"type": "color", "color": EKO_STEEL_PIPE}
    ord_comp_mats[4]["diffuse"] = {"type": "color", "color": EKO_ARM_BLACK}

with open("web/assets/scn/models.json", "w") as f:
    json.dump(models, f)
print("Saved all 4 KAI seat & cabin model families in web/assets/scn/models.json.")

# ==============================================================================
# Build 4 SeatClassEntities in SeatMap.json:
# 1. granClass       -> Eksekutif (Maroon 2-2) in Car 7 (z: 147..165)
# 2. green           -> Ekonomi New Gen (Biru 2-2) in Car 6 (z: 122..140)
# 3. ekonomiPremium  -> Ekonomi Premium (Tan 2-2) in Car 5 (z: 97..115)
# 4. ordinary        -> Ekonomi 2-3 (Cream 3-2 Tegak) in Cars 1..4 (z: -2..90)
# ==============================================================================
orig_ordinary = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "ordinary")
orig_green = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "green")
orig_gran = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "granClass")

# 1. Eksekutif Next Gen (Maroon 2-2) using Car 7 geometry
eks_maroon_entity = copy.deepcopy(orig_green)
eks_maroon_entity["id"] = 0
eks_maroon_entity["seatClass"] = "granClass"
eks_maroon_entity["name"] = "Eksekutif"
eks_maroon_entity["carNumber"] = "Eks 1"
for rev in eks_maroon_entity["reservableEntities"]:
    rev["carNumber"] = "Eks 1"
    me = rev["transformedModelEntity"]["modelEntity"]
    rev["transformedModelEntity"]["modelEntity"] = me.replace("e7-green-seat-", "kai-maroon-seat-")
for st in eks_maroon_entity["transformedModelEntities"]:
    st["modelEntity"] = st["modelEntity"].replace("e7-green-seat-", "kai-maroon-")

# Helper to convert a single car from orig_ordinary into a 2+2 car
def build_2x2_car_from_ordinary(car_label_orig, new_car_label, seat_class_key, class_display_name, model_prefix, z_range):
    reservables = []
    for rev in copy.deepcopy(orig_ordinary["reservableEntities"]):
        if rev["carNumber"] != car_label_orig:
            continue
        letter = rev["name"][-1]
        if letter == "E":
            continue
        rev["carNumber"] = new_car_label
        pos = rev["transformedModelEntity"]["position"]
        if letter == "A":
            pos["x"] = 1.2193
            rev["transformedModelEntity"]["modelEntity"] = f"{model_prefix}-seat-a"
        elif letter == "B":
            pos["x"] = 0.5988
            rev["transformedModelEntity"]["modelEntity"] = f"{model_prefix}-seat-b"
        elif letter == "C":
            pos["x"] = -0.5988
            rev["transformedModelEntity"]["modelEntity"] = f"{model_prefix}-seat-a"
        elif letter == "D":
            pos["x"] = -1.2193
            rev["transformedModelEntity"]["modelEntity"] = f"{model_prefix}-seat-b"
        reservables.append(rev)

    z_min, z_max = -z_range[1] - 6, -z_range[0] + 6
    statics = []
    for st in copy.deepcopy(orig_ordinary["transformedModelEntities"]):
        sz = st["position"]["z"]
        if not (z_min <= sz <= z_max):
            continue
        me = st["modelEntity"]
        if me in ("e7-ordinary-leg-a-to-c", "e7-ordinary-leg-d-to-e"):
            continue
        if me == "e7-ordinary-seat-section":
            st["modelEntity"] = f"{model_prefix}-section"
        elif me == "e7-ordinary-seat-section-ending-a":
            st["modelEntity"] = f"{model_prefix}-section-ending-a"
        elif me == "e7-ordinary-seat-section-ending-b":
            st["modelEntity"] = f"{model_prefix}-section-ending-b"
        elif me == "e7-ordinary-seat-partition-a":
            st["modelEntity"] = f"{model_prefix}-partition-a"
        elif me == "e7-ordinary-seat-partition-b":
            st["modelEntity"] = f"{model_prefix}-partition-b"
        statics.append(st)

    return {
        "id": 1,
        "seatClass": seat_class_key,
        "name": class_display_name,
        "carNumber": new_car_label,
        "viewableRange": [{"x": 0, "y": 0, "z": z_range[0]}, {"x": 0, "y": 0, "z": z_range[1]}],
        "reservableEntities": reservables,
        "transformedModelEntities": statics
    }

# 2. Ekonomi New Gen (Navy Blue 2-2) in Car 6 (z: 122..143)
eko_blue_entity = build_2x2_car_from_ordinary(
    car_label_orig="Car 6",
    new_car_label="Eko NG 1",
    seat_class_key="green",
    class_display_name="Ekonomi New Gen",
    model_prefix="kai-blue",
    z_range=(122, 143)
)

# 3. Ekonomi Premium (Taupe/Tan 2-2) in Car 5 (z: 97..118)
eko_prem_entity = build_2x2_car_from_ordinary(
    car_label_orig="Car 5",
    new_car_label="Prem 1",
    seat_class_key="ekonomiPremium",
    class_display_name="Ekonomi Premium",
    model_prefix="kai-prem",
    z_range=(97, 118)
)

# 4. Ekonomi 2-3 (Cream 3-2 Upright Bench) in Cars 1..4 (z: -2..92)
eko_23_entity = copy.deepcopy(orig_ordinary)
eko_23_entity["id"] = 3
eko_23_entity["seatClass"] = "ordinary"
eko_23_entity["name"] = "Ekonomi (2-3)"
eko_23_entity["carNumber"] = "Eko 1–4"
eko_23_entity["viewableRange"] = [{"x": 0, "y": 0, "z": -2}, {"x": 0, "y": 0, "z": 92}]
eko_23_reservables = []
for rev in eko_23_entity["reservableEntities"]:
    if rev["carNumber"] in ("Car 1", "Car 2", "Car 3", "Car 4"):
        rev["carNumber"] = rev["carNumber"].replace("Car ", "Eko ")
        eko_23_reservables.append(rev)
eko_23_entity["reservableEntities"] = eko_23_reservables
eko_23_entity["transformedModelEntities"] = [
    st for st in eko_23_entity["transformedModelEntities"]
    if st["position"]["z"] >= -99.0
]

# Also keep Car 8 static models so gangways/head look complete
car8_statics = copy.deepcopy(orig_gran["transformedModelEntities"])
eko_23_entity["transformedModelEntities"].extend(car8_statics)

new_seat_map = {
    "id": 0,
    "name": "KAI Next Gen & Ekonomi Series",
    "transformedModelEntities": orig_seat_map["transformedModelEntities"],
    "transformedTextModelEntities": orig_seat_map["transformedTextModelEntities"],
    "seatClassEntities": [
        eks_maroon_entity,
        eko_blue_entity,
        eko_prem_entity,
        eko_23_entity
    ]
}

with open("web/assets/data/SeatMap.json", "w") as f:
    json.dump(new_seat_map, f)
print("Saved 4-class KAI SeatMap.json (Eksekutif Maroon 2-2, Ekonomi New Gen Biru 2-2, Ekonomi Premium Tan 2-2, Ekonomi 2-3 Tegak).")

# ==============================================================================
# Update TrainCriteria.json so trains offer all 4 Indonesian KAI Seat Classes!
# ==============================================================================
with open("web/assets/data/TrainCriteria.json", "r") as f:
    tc = json.load(f)

tc["fromStationName"] = "Gambir"
tc["fromStationJPName"] = "GMR"
tc["toStationName"] = "Surabaya"
tc["toStationJPName"] = "SBI"

kai_schedules_meta = [
    ("Argo Bromo 2", "Next Gen Stainless", "e7-series"),
    ("Jayabaya 108", "Stainless New Gen", "e2-series"),
    ("Gaya Baru 104", "New Gen & Premium", "e5-series"),
    ("Kertajaya 218", "Premium & Ekonomi", "e3-series"),
    ("Argo Bromo 4", "Next Gen Stainless", "e7-series"),
    ("Gumarang 70", "Stainless Steel", "e6-series"),
    ("Brantas 112", "Eksekutif & Ekonomi", "e4-series"),
    ("Airlangga 236", "Rangkaian Ekonomi", "e3-series"),
]

for idx, sched in enumerate(tc["trainSchedules"]):
    t_num, t_series, t_img = kai_schedules_meta[idx % len(kai_schedules_meta)]
    sched["trainNumber"] = t_num
    sched["trainName"] = t_series
    sched["trainImageName"] = t_img

    sched["seatClasses"] = [
        {
            "id": 0,
            "seatClass": "granClass",
            "isAvailable": True,
            "name": "Eksekutif Next Gen",
            "description": "Kursi kulit maroon ergonomis 2-2 dengan winged headrest, footrest, & armrest kayu.",
            "price": 650000
        },
        {
            "id": 1,
            "seatClass": "green",
            "isAvailable": True,
            "name": "Ekonomi New Gen",
            "description": "Kursi captain seat biru ergonomis 2-2 searah laju kereta dengan winged headrest & armrest kayu.",
            "price": 420000
        },
        {
            "id": 2,
            "seatClass": "ekonomiPremium",
            "isAvailable": True,
            "name": "Ekonomi Premium",
            "description": "Kursi kulit beige/tan 2-2 reclining dengan sandaran tinggi, armrest lengkung, & stopkontak.",
            "price": 320000
        },
        {
            "id": 3,
            "seatClass": "ordinary",
            "isAvailable": True,
            "name": "Ekonomi (2-3)",
            "description": "Kursi bench krem tegak 90° konfigurasi 3-2 berbingkai pipa stainless, tirai biru, & lantai hijau.",
            "price": 150000
        }
    ]

with open("web/assets/data/TrainCriteria.json", "w") as f:
    json.dump(tc, f, indent=2)
print("Updated TrainCriteria.json with all 4 Indonesian KAI seat classes.")
