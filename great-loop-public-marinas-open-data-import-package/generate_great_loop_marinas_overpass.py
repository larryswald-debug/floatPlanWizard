#!/usr/bin/env python3
"""
Generate an FPW Great Loop public marina import CSV from OpenStreetMap/Overpass.

This script intentionally uses open data instead of proprietary marina directories.
It pulls OSM features tagged as marinas or marina-like harbors within broad Great Loop
route corridor bounding boxes, deduplicates by OSM element and approximate name/location,
and writes a DB-import-ready CSV for admin review.

License/attribution note:
OpenStreetMap data is licensed under the Open Data Commons Open Database License (ODbL).
If you publish this data, credit OpenStreetMap contributors and make clear that the data is
available under ODbL. See https://www.openstreetmap.org/copyright

Install:
  python3 -m pip install requests

Run:
  python3 generate_great_loop_marinas_overpass.py \
    --out great-loop-public-marinas-import-seed.csv

Optional:
  python3 generate_great_loop_marinas_overpass.py --sleep 2 --timeout 180
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import sys
import time
from dataclasses import dataclass
from datetime import date
from typing import Any, Dict, Iterable, List, Optional, Tuple

try:
    import requests
except ImportError as exc:
    print("Missing dependency: requests. Install with: python3 -m pip install requests", file=sys.stderr)
    raise SystemExit(2) from exc

OVERPASS_ENDPOINTS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

TODAY = date.today().isoformat()

# Broad Great Loop route corridor groups. These are intentionally coarse so the first pass captures candidates.
# Admin review should remove marinas that are too far inland, private-only, or not practical for Loop traffic.
ROUTE_GROUPS = [
    {"location_group": "Chicago / Illinois Waterway", "waterway": "Chicago River / Illinois Waterway", "country": "US", "bbox": [41.55, -88.35, 42.10, -87.40]},
    {"location_group": "Illinois River", "waterway": "Illinois River", "country": "US", "bbox": [38.85, -91.00, 41.75, -88.10]},
    {"location_group": "Upper Mississippi / Ohio River Connector", "waterway": "Mississippi River / Ohio River", "country": "US", "bbox": [36.80, -91.70, 39.60, -88.90]},
    {"location_group": "Ohio River / Kentucky Lake", "waterway": "Ohio River / Tennessee River", "country": "US", "bbox": [36.40, -89.25, 38.25, -84.90]},
    {"location_group": "Tennessee River / Tenn-Tom", "waterway": "Tennessee River / Tennessee-Tombigbee Waterway", "country": "US", "bbox": [32.25, -89.80, 37.20, -86.00]},
    {"location_group": "Mobile Bay / Alabama Gulf", "waterway": "Mobile Bay / Gulf ICW", "country": "US", "bbox": [30.20, -88.45, 31.00, -87.55]},
    {"location_group": "Florida Panhandle / Big Bend", "waterway": "Gulf ICW / Big Bend", "country": "US", "bbox": [29.35, -87.65, 30.75, -82.55]},
    {"location_group": "Florida West Coast", "waterway": "Gulf Coast / ICW", "country": "US", "bbox": [24.50, -83.25, 29.30, -81.80]},
    {"location_group": "Florida Keys", "waterway": "Florida Keys", "country": "US", "bbox": [24.35, -82.10, 25.35, -80.00]},
    {"location_group": "Okeechobee Waterway", "waterway": "Okeechobee Waterway / Caloosahatchee / St. Lucie", "country": "US", "bbox": [26.55, -81.95, 27.50, -80.15]},
    {"location_group": "Florida East Coast", "waterway": "Atlantic ICW", "country": "US", "bbox": [25.25, -81.00, 30.85, -79.75]},
    {"location_group": "Georgia / South Carolina ICW", "waterway": "Atlantic ICW", "country": "US", "bbox": [30.70, -81.75, 34.40, -78.30]},
    {"location_group": "North Carolina ICW", "waterway": "Atlantic ICW", "country": "US", "bbox": [33.75, -79.50, 36.65, -75.35]},
    {"location_group": "Virginia / Chesapeake Bay", "waterway": "Chesapeake Bay / Lower Bay", "country": "US", "bbox": [36.55, -77.80, 38.35, -75.20]},
    {"location_group": "Maryland Chesapeake", "waterway": "Chesapeake Bay", "country": "US", "bbox": [38.00, -77.40, 39.75, -75.70]},
    {"location_group": "Delaware Bay / C&D Canal / Cape May", "waterway": "C&D Canal / Delaware Bay", "country": "US", "bbox": [38.80, -76.20, 39.85, -74.75]},
    {"location_group": "New Jersey Coast", "waterway": "New Jersey ICW / Atlantic Coast", "country": "US", "bbox": [38.90, -75.20, 40.80, -73.85]},
    {"location_group": "New York Harbor / Hudson River", "waterway": "New York Harbor / Hudson River", "country": "US", "bbox": [40.45, -74.35, 42.95, -73.45]},
    {"location_group": "Erie Canal / Western NY", "waterway": "Erie Canal / New York State Canal System", "country": "US", "bbox": [42.45, -79.15, 43.35, -73.60]},
    {"location_group": "Oswego Canal / Lake Ontario", "waterway": "Oswego Canal / Lake Ontario", "country": "US/CA", "bbox": [43.15, -79.90, 44.45, -75.50]},
    {"location_group": "Trent-Severn / Georgian Bay", "waterway": "Trent-Severn Waterway / Georgian Bay", "country": "CA", "bbox": [43.60, -81.10, 45.80, -77.20]},
    {"location_group": "North Channel / Lake Huron", "waterway": "North Channel / Lake Huron", "country": "CA/US", "bbox": [45.25, -84.90, 46.40, -80.30]},
    {"location_group": "Straits of Mackinac", "waterway": "Straits of Mackinac", "country": "US", "bbox": [45.55, -85.20, 46.20, -84.20]},
    {"location_group": "Lake Michigan - East Shore", "waterway": "Lake Michigan", "country": "US", "bbox": [41.70, -87.75, 45.95, -84.90]},
    {"location_group": "Lake Michigan - Wisconsin / Door County", "waterway": "Lake Michigan / Green Bay", "country": "US", "bbox": [42.45, -88.95, 46.00, -86.50]},
]

FIELDNAMES = [
    "marina_id",
    "slug",
    "location_group",
    "waterway",
    "state_province",
    "country",
    "nearest_city",
    "marina_name",
    "latitude",
    "longitude",
    "osm_type",
    "osm_id",
    "osm_url",
    "public_status",
    "access",
    "operator",
    "phone",
    "email",
    "website",
    "vhf_channel",
    "fuel_available",
    "diesel_available",
    "gas_available",
    "pumpout_available",
    "power_available",
    "water_available",
    "showers_available",
    "toilets_available",
    "laundry_available",
    "transient_slips",
    "capacity",
    "max_length_ft",
    "fee",
    "reservation_url",
    "notes",
    "source_name",
    "source_url",
    "source_license",
    "verification_status",
    "great_loop_relevance",
    "nav_warning",
    "duplicate_review_note",
    "last_reviewed",
]


def slugify(value: str) -> str:
    value = value.lower().strip()
    value = re.sub(r"&", " and ", value)
    value = re.sub(r"[^a-z0-9]+", "-", value)
    value = re.sub(r"-+", "-", value).strip("-")
    return value or "unnamed-marina"


def yn_from_tags(tags: Dict[str, Any], keys: Iterable[str]) -> str:
    vals = []
    for key in keys:
        v = tags.get(key)
        if v is not None:
            vals.append(str(v).strip().lower())
    if not vals:
        return "unknown"
    if any(v in {"yes", "true", "1", "available"} for v in vals):
        return "yes"
    if any(v in {"no", "false", "0", "none"} for v in vals):
        return "no"
    return "; ".join(sorted(set(vals)))


def get_coord(el: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    if "lat" in el and "lon" in el:
        return float(el["lat"]), float(el["lon"])
    center = el.get("center")
    if center and "lat" in center and "lon" in center:
        return float(center["lat"]), float(center["lon"])
    return None


def detect_public_status(tags: Dict[str, Any]) -> Tuple[str, str]:
    access = str(tags.get("access") or tags.get("boat") or tags.get("mooring") or "").strip().lower()
    fee = str(tags.get("fee") or "").strip().lower()
    private_keys = {"private", "customers", "members", "no"}
    if access in private_keys:
        return "restricted_or_private_review", access
    if access in {"yes", "permissive", "destination"}:
        return "public_candidate", access
    if fee in {"yes", "no"}:
        return "public_candidate", access or "not_tagged"
    return "unknown_review", access or "not_tagged"


def build_query(bbox: List[float]) -> str:
    south, west, north, east = bbox
    # Include node/way/relation forms. Include both leisure=marina and seamark harbour-category tags.
    return f"""
[out:json][timeout:120];
(
  node["leisure"="marina"]({south},{west},{north},{east});
  way["leisure"="marina"]({south},{west},{north},{east});
  relation["leisure"="marina"]({south},{west},{north},{east});
  node["seamark:harbour:category"="marina"]({south},{west},{north},{east});
  way["seamark:harbour:category"="marina"]({south},{west},{north},{east});
  relation["seamark:harbour:category"="marina"]({south},{west},{north},{east});
  node["harbour"="marina"]({south},{west},{north},{east});
  way["harbour"="marina"]({south},{west},{north},{east});
  relation["harbour"="marina"]({south},{west},{north},{east});
);
out center tags;
""".strip()


def overpass_request(query: str, timeout: int) -> Dict[str, Any]:
    last_err = None
    for endpoint in OVERPASS_ENDPOINTS:
        try:
            resp = requests.post(endpoint, data={"data": query}, timeout=timeout, headers={"User-Agent": "FPW-Great-Loop-Marina-Research/1.0"})
            if resp.status_code == 429:
                last_err = RuntimeError(f"{endpoint} rate limited: {resp.status_code}")
                time.sleep(10)
                continue
            resp.raise_for_status()
            return resp.json()
        except Exception as exc:
            last_err = exc
            continue
    raise RuntimeError(f"All Overpass endpoints failed: {last_err}")


def state_from_tags(tags: Dict[str, Any]) -> str:
    # OSM marina objects usually do not have state/province. Leave blank for reverse geocode/admin enrichment.
    return tags.get("addr:state") or tags.get("is_in:state") or tags.get("addr:province") or ""


def city_from_tags(tags: Dict[str, Any]) -> str:
    return tags.get("addr:city") or tags.get("is_in:city") or tags.get("addr:town") or tags.get("is_in") or ""


def make_row(group: Dict[str, Any], el: Dict[str, Any]) -> Optional[Dict[str, str]]:
    coord = get_coord(el)
    if not coord:
        return None
    lat, lon = coord
    tags = el.get("tags", {}) or {}
    name = str(tags.get("name") or tags.get("seamark:name") or "Unnamed marina").strip()
    osm_type = el.get("type", "")
    osm_id = str(el.get("id", ""))
    osm_url = f"https://www.openstreetmap.org/{osm_type}/{osm_id}" if osm_type and osm_id else ""
    public_status, access = detect_public_status(tags)

    stable = f"{osm_type}:{osm_id}:{lat:.6f}:{lon:.6f}:{name}".encode("utf-8")
    marina_id = "glm-" + hashlib.sha1(stable).hexdigest()[:12]
    slug_base = f"{name}-{city_from_tags(tags) or group['location_group']}"

    notes_parts = []
    for key in ["description", "note", "opening_hours", "contact:phone", "contact:website", "addr:street", "addr:housenumber"]:
        if tags.get(key):
            notes_parts.append(f"{key}={tags[key]}")

    return {
        "marina_id": marina_id,
        "slug": slugify(slug_base),
        "location_group": group["location_group"],
        "waterway": group["waterway"],
        "state_province": state_from_tags(tags),
        "country": tags.get("addr:country") or group["country"],
        "nearest_city": city_from_tags(tags),
        "marina_name": name,
        "latitude": f"{lat:.7f}",
        "longitude": f"{lon:.7f}",
        "osm_type": osm_type,
        "osm_id": osm_id,
        "osm_url": osm_url,
        "public_status": public_status,
        "access": access,
        "operator": tags.get("operator", ""),
        "phone": tags.get("phone") or tags.get("contact:phone") or "",
        "email": tags.get("email") or tags.get("contact:email") or "",
        "website": tags.get("website") or tags.get("contact:website") or "",
        "vhf_channel": tags.get("vhf") or tags.get("seamark:radio_station:vhf_channel") or tags.get("communication:vhf") or "",
        "fuel_available": yn_from_tags(tags, ["fuel", "waterway:fuel", "seamark:small_craft_facility:category:fuel"]),
        "diesel_available": yn_from_tags(tags, ["fuel:diesel", "diesel"]),
        "gas_available": yn_from_tags(tags, ["fuel:gasoline", "fuel:petrol", "gasoline"]),
        "pumpout_available": yn_from_tags(tags, ["sanitary_dump_station", "pumpout", "waste_disposal"]),
        "power_available": yn_from_tags(tags, ["power_supply", "electricity", "power"]),
        "water_available": yn_from_tags(tags, ["drinking_water", "water_point", "water"]),
        "showers_available": yn_from_tags(tags, ["shower", "showers"]),
        "toilets_available": yn_from_tags(tags, ["toilets", "amenity:toilets"]),
        "laundry_available": yn_from_tags(tags, ["washing_machine", "laundry"]),
        "transient_slips": tags.get("transient", "unknown"),
        "capacity": tags.get("capacity", ""),
        "max_length_ft": tags.get("maxlength") or tags.get("max_length") or "",
        "fee": tags.get("fee", ""),
        "reservation_url": tags.get("reservation") or tags.get("booking") or "",
        "notes": "; ".join(notes_parts),
        "source_name": "OpenStreetMap",
        "source_url": osm_url,
        "source_license": "ODbL - https://www.openstreetmap.org/copyright",
        "verification_status": "needs_verification",
        "great_loop_relevance": "candidate_within_broad_route_corridor",
        "nav_warning": "For planning only. Verify current charts, local rules, availability, depth, fuel, transient access, and marina status before relying on this record.",
        "duplicate_review_note": "Deduplicated by OSM element ID and approximate name/location; review overlapping facilities and nearby yacht clubs manually.",
        "last_reviewed": TODAY,
    }


def dedupe(rows: List[Dict[str, str]]) -> List[Dict[str, str]]:
    seen_osm = set()
    seen_fuzzy = set()
    out = []
    for row in rows:
        osm_key = (row["osm_type"], row["osm_id"])
        if osm_key in seen_osm:
            continue
        seen_osm.add(osm_key)
        fuzzy = (slugify(row["marina_name"]), round(float(row["latitude"]), 4), round(float(row["longitude"]), 4))
        if fuzzy in seen_fuzzy:
            continue
        seen_fuzzy.add(fuzzy)
        out.append(row)
    out.sort(key=lambda r: (r["location_group"], r["state_province"], r["nearest_city"], r["marina_name"]))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="great-loop-public-marinas-import-seed.csv")
    ap.add_argument("--raw-json", default="great-loop-public-marinas-overpass-raw.json")
    ap.add_argument("--timeout", type=int, default=180)
    ap.add_argument("--sleep", type=float, default=2.0, help="Delay between Overpass requests to be polite")
    args = ap.parse_args()

    rows: List[Dict[str, str]] = []
    raw_bundle = {"generated": TODAY, "source": "OpenStreetMap via Overpass API", "groups": []}
    for i, group in enumerate(ROUTE_GROUPS, start=1):
        print(f"[{i}/{len(ROUTE_GROUPS)}] Querying {group['location_group']}...", file=sys.stderr)
        query = build_query(group["bbox"])
        data = overpass_request(query, timeout=args.timeout)
        elements = data.get("elements", [])
        group_records = []
        for el in elements:
            row = make_row(group, el)
            if row:
                rows.append(row)
                group_records.append({"osm_type": row["osm_type"], "osm_id": row["osm_id"], "name": row["marina_name"]})
        raw_bundle["groups"].append({"group": group, "count": len(elements), "records": group_records})
        time.sleep(args.sleep)

    rows = dedupe(rows)

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)

    with open(args.raw_json, "w", encoding="utf-8") as f:
        json.dump(raw_bundle, f, indent=2, ensure_ascii=False)

    print(f"Wrote {len(rows)} rows to {args.out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
