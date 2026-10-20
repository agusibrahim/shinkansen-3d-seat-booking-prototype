import json
import copy

with open("Shinkansen3DSeatBookingPrototype/Assets.xcassets/Data Sources/SeatMap.dataset/SeatMap.json", "r") as f:
    orig_seat_map = json.load(f)

orig_ordinary = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "ordinary")
orig_green = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "green")
orig_gran = next(e for e in orig_seat_map["seatClassEntities"] if e["seatClass"] == "granClass")

# 1. Eksekutif Next Gen (Maroon 2-2) in Car 7 (z: 147..165)
eks_maroon_entity = copy.deepcopy(orig_green)
eks_maroon_entity["id"] = 0
eks_maroon_entity["seatClass"] = "granClass"
eks_maroon_entity["name"] = "Eksekutif Next Gen"
eks_maroon_entity["carNumber"] = "Eks 1"
for rev in eks_maroon_entity["reservableEntities"]:
    rev["carNumber"] = "Eks 1"
    me = rev["transformedModelEntity"]["modelEntity"]
    rev["transformedModelEntity"]["modelEntity"] = me.replace("e7-green-seat-", "kai-maroon-seat-")
for st in eks_maroon_entity["transformedModelEntities"]:
    st["modelEntity"] = st["modelEntity"].replace("e7-green-seat-", "kai-maroon-")

# Helper to build a 2+2 car from orig_ordinary Car 1..6 with STRICT non-overlapping Z bounds
def build_2x2_car(car_label_orig, new_car_label, seat_class_key, class_display_name, seat_prefix, section_prefix, z_view_range, z_static_bounds):
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
            rev["transformedModelEntity"]["modelEntity"] = f"{seat_prefix}-seat-a"
        elif letter == "B":
            pos["x"] = 0.5988
            rev["transformedModelEntity"]["modelEntity"] = f"{seat_prefix}-seat-b"
        elif letter == "C":
            pos["x"] = -0.5988
            rev["transformedModelEntity"]["modelEntity"] = f"{seat_prefix}-seat-a"
        elif letter == "D":
            pos["x"] = -1.2193
            rev["transformedModelEntity"]["modelEntity"] = f"{seat_prefix}-seat-b"
        reservables.append(rev)

    z_min, z_max = z_static_bounds
    statics = []
    for st in copy.deepcopy(orig_ordinary["transformedModelEntities"]):
        sz = st["position"]["z"]
        if not (z_min <= sz < z_max):
            continue
        me = st["modelEntity"]
        if me in ("e7-ordinary-leg-a-to-c", "e7-ordinary-leg-d-to-e"):
            continue
        if me == "e7-ordinary-seat-section":
            st["modelEntity"] = f"{section_prefix}-section"
        elif me == "e7-ordinary-seat-section-ending-a":
            st["modelEntity"] = f"{section_prefix}-section-ending-a"
        elif me == "e7-ordinary-seat-section-ending-b":
            st["modelEntity"] = f"{section_prefix}-section-ending-b"
        elif me in ("e7-ordinary-seat-partition-a", "e7-green-seat-partition-a"):
            st["modelEntity"] = f"{section_prefix}-partition-a"
        elif me in ("e7-ordinary-seat-partition-b", "e7-green-seat-partition-b"):
            st["modelEntity"] = f"{section_prefix}-partition-b"
        statics.append(st)

    return {
        "id": 1,
        "seatClass": seat_class_key,
        "name": class_display_name,
        "carNumber": new_car_label,
        "viewableRange": [{"x": 0, "y": 0, "z": z_view_range[0]}, {"x": 0, "y": 0, "z": z_view_range[1]}],
        "reservableEntities": reservables,
        "transformedModelEntities": statics
    }

# Helper to build a 3+2 car from orig_ordinary with STRICT non-overlapping Z bounds
def build_3x2_car(car_labels_orig, new_car_label, seat_class_key, class_display_name, seat_prefix, section_prefix, z_view_range, z_static_bounds):
    reservables = []
    for rev in copy.deepcopy(orig_ordinary["reservableEntities"]):
        if rev["carNumber"] not in car_labels_orig:
            continue
        rev["carNumber"] = new_car_label if len(car_labels_orig) == 1 else rev["carNumber"].replace("Car ", "Eko ")
        if seat_prefix != "e7-ordinary":
            rev["transformedModelEntity"]["modelEntity"] = rev["transformedModelEntity"]["modelEntity"].replace("e7-ordinary-seat-", f"{seat_prefix}-seat-")
        reservables.append(rev)

    z_min, z_max = z_static_bounds
    statics = []
    for st in copy.deepcopy(orig_ordinary["transformedModelEntities"]):
        sz = st["position"]["z"]
        if not (z_min <= sz < z_max):
            continue
        me = st["modelEntity"]
        if me in ("e7-ordinary-leg-a-to-c", "e7-ordinary-leg-d-to-e"):
            continue
        if section_prefix != "e7-ordinary":
            if me == "e7-ordinary-seat-section":
                st["modelEntity"] = f"{section_prefix}-section"
            elif me == "e7-ordinary-seat-section-ending-a":
                st["modelEntity"] = f"{section_prefix}-section-ending-a"
            elif me == "e7-ordinary-seat-section-ending-b":
                st["modelEntity"] = f"{section_prefix}-section-ending-b"
            elif me in ("e7-ordinary-seat-partition-a", "e7-green-seat-partition-a"):
                st["modelEntity"] = f"{section_prefix}-partition-a"
            elif me in ("e7-ordinary-seat-partition-b", "e7-green-seat-partition-b"):
                st["modelEntity"] = f"{section_prefix}-partition-b"
        statics.append(st)

    return {
        "id": 2,
        "seatClass": seat_class_key,
        "name": class_display_name,
        "carNumber": new_car_label,
        "viewableRange": [{"x": 0, "y": 0, "z": z_view_range[0]}, {"x": 0, "y": 0, "z": z_view_range[1]}],
        "reservableEntities": reservables,
        "transformedModelEntities": statics
    }

# 2. Eksekutif New Image Dual-Tone (Tosca-Krem 2-2) in Car 6 (seats z: -147.91..-128.29, gangways: -150.50..-125.69)
eks_dualtone_entity = build_2x2_car(
    car_label_orig="Car 6",
    new_car_label="Eks NI 1",
    seat_class_key="eksekutifDualTone",
    class_display_name="Eksekutif (Dual-Tone)",
    seat_prefix="kai-eks-dualtone",
    section_prefix="kai-eks-dualtone",
    z_view_range=(123, 143),
    z_static_bounds=(-150.5, -125.6)
)

# 3. Ekonomi New Gen (Biru Full 2-2) in Car 5 (seats z: -117.93..-106.57, gangways: -125.69..-100.81)
eko_blue_entity = build_2x2_car(
    car_label_orig="Car 5",
    new_car_label="Eko NG 1",
    seat_class_key="green",
    class_display_name="Ekonomi New Gen (Biru)",
    seat_prefix="kai-blue",
    section_prefix="kai-blue",
    z_view_range=(101, 113),
    z_static_bounds=(-125.6, -100.8)
)

# 4. Ekonomi New Gen Dual-Tone (Biru-Tan 2-2) in Car 4 (seats z: -96.13..-78.57, gangways: -100.81..-75.97)
eko_blue_dualtone_entity = build_2x2_car(
    car_label_orig="Car 4",
    new_car_label="Eko NG 2",
    seat_class_key="ekonomiNewGenDual",
    class_display_name="Eko New Gen (Dual-Tone)",
    seat_prefix="kai-blue-dualtone",
    section_prefix="kai-blue",
    z_view_range=(73, 91),
    z_static_bounds=(-100.8, -75.9)
)

# 5. Ekonomi Premium (Taupe/Tan 2-2) in Car 3 (seats z: -70.62..-54.09, gangways: -75.97..-50.87)
eko_prem_entity = build_2x2_car(
    car_label_orig="Car 3",
    new_car_label="Prem 1",
    seat_class_key="ekonomiPremium",
    class_display_name="Ekonomi Premium",
    seat_prefix="kai-prem",
    section_prefix="kai-prem",
    z_view_range=(49, 65),
    z_static_bounds=(-75.9, -50.8)
)

# 6. Ekonomi 2-3 Modifikasi (Tosca Scalloped 3-2) in Car 2 (seats z: -48.28..-28.65, gangways: -50.87..-26.05)
eko_tosca_entity = build_3x2_car(
    car_labels_orig=["Car 2"],
    new_car_label="Eko Mod 1",
    seat_class_key="ekonomiTosca",
    class_display_name="Ekonomi Modif (2-3)",
    seat_prefix="kai-tosca",
    section_prefix="kai-tosca",
    z_view_range=(23, 43),
    z_static_bounds=(-50.8, -26.0)
)

# 7. Ekonomi 2-3 Reguler (Krem Tegak 90° 3-2) in Car 1 (seats z: -20.70..-11.40, gangways: -26.05..0.0)
eko_23_entity = build_3x2_car(
    car_labels_orig=["Car 1"],
    new_car_label="Eko 1",
    seat_class_key="ordinary",
    class_display_name="Ekonomi Reguler (2-3)",
    seat_prefix="e7-ordinary",
    section_prefix="e7-ordinary",
    z_view_range=(5, 16),
    z_static_bounds=(-26.0, 0.0)
)

new_seat_map = {
    "id": 0,
    "name": "KAI Complete 7-Class Fleet",
    "transformedModelEntities": orig_seat_map["transformedModelEntities"],
    "transformedTextModelEntities": orig_seat_map["transformedTextModelEntities"],
    "seatClassEntities": [
        eks_maroon_entity,
        eks_dualtone_entity,
        eko_blue_entity,
        eko_blue_dualtone_entity,
        eko_prem_entity,
        eko_tosca_entity,
        eko_23_entity
    ]
}

with open("web/assets/data/SeatMap.json", "w") as f:
    json.dump(new_seat_map, f)
print("Saved 7-class KAI SeatMap.json.")

# ==============================================================================
# Populate TrainCriteria.json with varied KAI trains & seat class combinations!
# ==============================================================================
with open("web/assets/data/TrainCriteria.json", "r") as f:
    tc = json.load(f)

tc["fromStationName"] = "Gambir"
tc["fromStationJPName"] = "GMR"
tc["toStationName"] = "Surabaya"
tc["toStationJPName"] = "SBI"

CLASS_CATALOG = {
    "granClass": {
        "id": 0,
        "seatClass": "granClass",
        "isAvailable": True,
        "name": "Eksekutif Next Gen",
        "description": "Kursi kulit maroon ergonomis 2-2 dengan winged headrest, footrest, & armrest kayu jati.",
        "price": 650000
    },
    "eksekutifDualTone": {
        "id": 1,
        "seatClass": "eksekutifDualTone",
        "isAvailable": True,
        "name": "Eksekutif (Dual-Tone)",
        "description": "Kursi eksekutif 2-2 dual-tone krem & bolster biru tosca dengan armrest kayu burl gelap.",
        "price": 580000
    },
    "green": {
        "id": 2,
        "seatClass": "green",
        "isAvailable": True,
        "name": "Ekonomi New Gen (Biru)",
        "description": "Captain seat kulit biru 2-2 searah laju dengan motif batik jacquard & armrest kayu.",
        "price": 420000
    },
    "ekonomiNewGenDual": {
        "id": 3,
        "seatClass": "ekonomiNewGenDual",
        "isAvailable": True,
        "name": "Eko New Gen (Dual-Tone)",
        "description": "Captain seat 2-2 dual-tone biru dongker & headrest cokelat tan dengan armrest kayu mahoni.",
        "price": 400000
    },
    "ekonomiPremium": {
        "id": 4,
        "seatClass": "ekonomiPremium",
        "isAvailable": True,
        "name": "Ekonomi Premium",
        "description": "Kursi kulit beige/tan 2-2 sandaran tinggi dengan armrest lengkung terbuka & stopkontak.",
        "price": 320000
    },
    "ekonomiTosca": {
        "id": 5,
        "seatClass": "ekonomiTosca",
        "isAvailable": True,
        "name": "Ekonomi Modif (2-3)",
        "description": "Kursi 3-2 kulit biru tosca sandaran lekuk (scalloped) dengan pegangan chrome & lis jendela kayu.",
        "price": 220000
    },
    "ordinary": {
        "id": 6,
        "seatClass": "ordinary",
        "isAvailable": True,
        "name": "Ekonomi Reguler (2-3)",
        "description": "Kursi bench krem tegak 90° konfigurasi 3-2 berbingkai pipa stainless, tirai biru, & lantai hijau.",
        "price": 150000
    }
}

train_profiles = [
    (
        "Argo Bromo 2",
        "Next Gen & New Image",
        "e7-series",
        ["granClass", "eksekutifDualTone", "green", "ekonomiNewGenDual", "ekonomiPremium", "ekonomiTosca", "ordinary"]
    ),
    (
        "Jayabaya 108",
        "Stainless New Gen",
        "e2-series",
        ["granClass", "ekonomiNewGenDual", "green"]
    ),
    (
        "Gaya Baru 104",
        "New Image & New Gen",
        "e5-series",
        ["eksekutifDualTone", "ekonomiNewGenDual", "ekonomiPremium"]
    ),
    (
        "Kertajaya 218",
        "Premium & Ekonomi",
        "e3-series",
        ["ekonomiPremium", "ekonomiTosca", "ordinary"]
    ),
    (
        "Gumarang 70",
        "Eksekutif & Modifikasi",
        "e6-series",
        ["eksekutifDualTone", "granClass", "ekonomiTosca"]
    ),
    (
        "Brantas 112",
        "Eksekutif & Ekonomi",
        "e4-series",
        ["eksekutifDualTone", "ekonomiTosca", "ordinary"]
    ),
    (
        "Majapahit 216",
        "Stainless New Gen",
        "e2-series",
        ["ekonomiNewGenDual", "green", "ekonomiPremium"]
    ),
    (
        "Airlangga 236",
        "Rangkaian Ekonomi",
        "e3-series",
        ["ekonomiTosca", "ordinary"]
    )
]

for idx, sched in enumerate(tc["trainSchedules"]):
    t_num, t_series, t_img, cls_keys = train_profiles[idx % len(train_profiles)]
    sched["trainNumber"] = t_num
    sched["trainName"] = t_series
    sched["trainImageName"] = t_img
    sched["seatClasses"] = [copy.deepcopy(CLASS_CATALOG[k]) for k in cls_keys]

with open("web/assets/data/TrainCriteria.json", "w") as f:
    json.dump(tc, f, indent=2)
print("Saved TrainCriteria.json with varied KAI trains and all 7 seat classes.")
