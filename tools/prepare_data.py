#!/usr/bin/env python3
"""تجهيز بيانات تطبيق أطلس السوق من الملفين الأصليين.

المدخلات (خارج المستودع):
  ~/Desktop/اهم ملفات/Saudi_Population_Geospatial_Normalized (1).xlsx
  ~/Desktop/اهم ملفات/Saudi_Retail_Branches_Aligned.xlsx

المخرجات:
  assets/data/*.json                 أصول يقرأها التطبيق دون إنترنت
  tools/output/Saudi_Population_Simplified.xlsx  نسخة مبسطة من التعداد
  tools/output/DATA_DICTIONARY.md    شرح الأعمدة المبسطة

لا يعدّل هذا السكربت الملفات الأصلية.
"""

import json
import os
from pathlib import Path

from openpyxl import Workbook, load_workbook

ROOT = Path(__file__).resolve().parents[1]
DESKTOP = Path.home() / "Desktop" / "اهم ملفات"
POP_SRC = DESKTOP / "Saudi_Population_Geospatial_Normalized (1).xlsx"
BRANCH_SRC = DESKTOP / "Saudi_Retail_Branches_Aligned.xlsx"
ASSETS = ROOT / "assets" / "data"
OUT = ROOT / "tools" / "output"


def s(v):
    return "" if v is None else str(v).strip()


def num(v):
    if v is None or v == "":
        return None
    try:
        f = float(v)
        return int(f) if f.is_integer() else round(f, 6)
    except (TypeError, ValueError):
        return None


def rows(ws, header_row=4):
    it = ws.iter_rows(values_only=True)
    for _ in range(header_row - 1):
        next(it, None)
    header = [s(c) for c in next(it, ())]
    for r in it:
        yield dict(zip(header, r))


def sheet(wb, keyword):
    for ws in wb.worksheets:
        if keyword in ws.title:
            return ws
    raise KeyError(keyword)


def dump(name, obj):
    p = ASSETS / name
    p.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size:,} bytes)")


def main():
    ASSETS.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    pop_wb = load_workbook(POP_SRC, read_only=True, data_only=True)

    # --- السكان: الأعمدة الأكثر أهمية فقط ---
    pop_rows = list(rows(sheet(pop_wb, "07_السكان")))
    pop_by_geo = {}
    for r in pop_rows:
        geo = s(r.get("geo_id"))
        if not geo:
            continue
        pop_by_geo[geo] = {
            "geoId": geo,
            "unit": s(r.get("unit_type")),
            "year": num(r.get("data_year")),
            "class": s(r.get("data_class")),
            "source": s(r.get("source_id")),
            "total": num(r.get("population_total")),
            "male": num(r.get("population_male")),
            "female": num(r.get("population_female")),
            "saudi": num(r.get("population_saudi")),
            "nonSaudi": num(r.get("population_non_saudi")),
            "medianAge": num(r.get("median_age_derived")),
            "density": num(r.get("population_density_published")),
            "nameAr": s(r.get("name_ar")),
            "nameEn": s(r.get("name_en")),
        }

    # --- المناطق والمحافظات ---
    geo_rows = list(rows(sheet(pop_wb, "01_المناطق_والمحافظات")))
    regions, governorates = [], []
    for r in geo_rows:
        geo = s(r.get("geo_id"))
        base = {
            "geoId": geo,
            "nameAr": s(r.get("name_ar")),
            "nameEn": s(r.get("name_en")),
            "lat": num(r.get("centroid_lat")),
            "lon": num(r.get("centroid_lon")),
            "areaKm2": num(r.get("area_km2_reference")),
            "pop": (pop_by_geo.get(geo) or {}).get("total"),
        }
        unit = s(r.get("unit_type"))
        if unit == "منطقة" or geo.startswith("DS_REG_"):
            regions.append({**base, "id": num(r.get("region_id"))})
        else:
            governorates.append({
                **base,
                "id": num(r.get("governorate_id")),
                "regionId": num(r.get("region_id")),
                "parentGeoId": s(r.get("parent_geo_id")),
            })

    # --- المدن والأحياء (دليل مجتمعي، ليس تعداداً) ---
    city_rows = list(rows(sheet(pop_wb, "02_المدن_والتجمعات")))
    cities = [{
        "id": num(r.get("city_id")),
        "geoId": s(r.get("geo_id")),
        "regionId": num(r.get("region_id")),
        "nameAr": s(r.get("name_ar")),
        "nameEn": s(r.get("name_en")),
        "lat": num(r.get("latitude")),
        "lon": num(r.get("longitude")),
    } for r in city_rows if s(r.get("geo_id"))]

    district_rows = list(rows(sheet(pop_wb, "03_الأحياء")))
    districts = [{
        "id": num(r.get("district_id")),
        "geoId": s(r.get("geo_id")),
        "cityId": num(r.get("city_id")),
        "regionId": num(r.get("region_id")),
        "nameAr": s(r.get("name_ar")),
        "nameEn": s(r.get("name_en")),
        "lat": num(r.get("latitude")),
        "lon": num(r.get("longitude")),
        "areaKm2": num(r.get("area_km2_reference")),
    } for r in district_rows if s(r.get("geo_id"))]
    pop_wb.close()

    # --- الفروع: دمج كل أوراق العلامات ---
    br_wb = load_workbook(BRANCH_SRC, read_only=True, data_only=True)
    brands = {
        "فروع أسواق النخبة": "أسواق النخبة",
        "فروع بنده": "بنده",
        "فروع أسواق العثيم": "العثيم",
        "فروع التميمي": "التميمي",
        "فروع الراية": "الراية",
        "فروع الدكان": "الدكان",
        "فروع ديل": "ديل",
        "فروع منافس": "منافس",
        "فروع الصالة الاقتصادية": "الصالة الاقتصادية",
        "فروع كيو": "كيو",
        "فروع لولو": "لولو",
    }
    branches = []
    for ws in br_wb.worksheets:
        brand = brands.get(ws.title, ws.title.replace("فروع ", ""))
        for i, r in enumerate(rows(ws), start=1):
            lat, lon = num(r.get("خط العرض")), num(r.get("خط الطول"))
            branches.append({
                "id": s(r.get("branch_join_id")) or f"{ws.title}-{i}",
                "brand": brand,
                "name": s(r.get("الفرع")) or s(r.get("الكود الرسمي")),
                "code": s(r.get("الكود الرسمي")),
                "region": s(r.get("المنطقة")),
                "city": s(r.get("المدينة / التجمع")),
                "district": s(r.get("الحي")),
                "address": s(r.get("العنوان المنشور أو المرجع")),
                "lat": lat,
                "lon": lon,
                "source": s(r.get("مصدر العنوان")),
                "verification": s(r.get("حالة التحقق")),
                "countStatus": s(r.get("العد في الدراسة")),
                "regionGeoId": s(r.get("region_geo_id")),
                "govGeoId": s(r.get("governorate_geo_id")),
                "cityGeoId": s(r.get("city_geo_id")),
                "districtGeoId": s(r.get("district_geo_id")),
            })
    br_wb.close()

    dump("regions.json", regions)
    dump("governorates.json", governorates)
    dump("cities.json", cities)
    dump("districts.json", districts)
    dump("population.json", sorted(pop_by_geo.values(), key=lambda x: x["geoId"]))
    dump("branches.json", branches)

    # --- نسخة مبسطة من ملف التعداد ---
    wb = Workbook()
    ws = wb.active
    ws.title = "السكان المبسط"
    cols = [
        ("geo_id", "geoId"), ("name_ar", "nameAr"), ("name_en", "nameEn"),
        ("unit_type", "unit"), ("data_year", "year"), ("data_class", "class"),
        ("source_id", "source"), ("population_total", "total"),
        ("population_male", "male"), ("population_female", "female"),
        ("population_saudi", "saudi"), ("population_non_saudi", "nonSaudi"),
        ("median_age", "medianAge"), ("density", "density"),
    ]
    ws.append([ar for ar, _ in cols])
    for rec in sorted(pop_by_geo.values(), key=lambda x: x["geoId"]):
        ws.append([rec.get(k) for _, k in cols])
    p = OUT / "Saudi_Population_Simplified.xlsx"
    wb.save(p)
    print(f"  {p.relative_to(ROOT)}  ({p.stat().st_size:,} bytes)")

    dictionary = """# ملف التعداد المبسط

تم استخراج الأعمدة الأكثر أهمية من `07_السكان` في الملف الأصلي، مع حذف
جداول العمر المفرد والخماسي والجنسية وتفاصيل المساكن التي لا يستخدمها التطبيق.

| العمود | المعنى |
|---|---|
| geo_id | معرف الوحدة الجغرافية في المصدر (مثال: DS_GOV_101) |
| name_ar / name_en | اسم الوحدة بالعربية والإنجليزية |
| unit_type | منطقة / محافظة / المملكة |
| data_year | سنة البيانات (2022 للتعداد) |
| data_class | تعداد رسمي أو تقدير |
| source_id | معرف المصدر كما ورد في الملف الأصلي |
| population_total | إجمالي السكان |
| population_male / female | حسب الجنس |
| population_saudi / non_saudi | حسب الجنسية |
| median_age | العمر الوسيط المشتق |
| density | الكثافة المنشورة إن وُجدت |

**قاعدة عرض مهمة:** لا تُقارن أرقام مستويات جغرافية مختلفة ببعضها، ولا تُستخدم
أرقام المنطقة أو المحافظة كأنها «سكان دائرة نصف قطرها 5 كم».
"""
    (OUT / "DATA_DICTIONARY.md").write_text(dictionary, encoding="utf-8")

    print(f" regions={len(regions)} governorates={len(governorates)} "
          f"cities={len(cities)} districts={len(districts)} "
          f"population={len(pop_by_geo)} branches={len(branches)}")


if __name__ == "__main__":
    main()
