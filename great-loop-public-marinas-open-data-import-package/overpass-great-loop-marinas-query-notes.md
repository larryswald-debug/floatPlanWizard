# Overpass query strategy for Great Loop marinas

The generator queries broad route-corridor bounding boxes. This is intentionally inclusive because the user requested all marina candidates that can be found, not a manually selected subset.

## OSM tags queried

```overpass
node["leisure"="marina"](...);
way["leisure"="marina"](...);
relation["leisure"="marina"](...);
node["seamark:harbour:category"="marina"](...);
way["seamark:harbour:category"="marina"](...);
relation["seamark:harbour:category"="marina"](...);
node["harbour"="marina"](...);
way["harbour"="marina"](...);
relation["harbour"="marina"](...);
```

## Why candidate status is needed

OSM can tell us that a mapped object is a marina, but it does not reliably tell us whether:

- transients are accepted,
- the marina is open this season,
- it has fuel,
- it has pumpout,
- it has adequate depth,
- it is members-only,
- it is private,
- it is still operating.

Therefore, every row is generated with `verification_status=needs_verification` and `is_published=0` in the suggested table.

## Broad Great Loop route groups included

- Chicago / Illinois Waterway
- Illinois River
- Upper Mississippi / Ohio River Connector
- Ohio River / Kentucky Lake
- Tennessee River / Tenn-Tom
- Mobile Bay / Alabama Gulf
- Florida Panhandle / Big Bend
- Florida West Coast
- Florida Keys
- Okeechobee Waterway
- Florida East Coast
- Georgia / South Carolina ICW
- North Carolina ICW
- Virginia / Chesapeake Bay
- Maryland Chesapeake
- Delaware Bay / C&D Canal / Cape May
- New Jersey Coast
- New York Harbor / Hudson River
- Erie Canal / Western NY
- Oswego Canal / Lake Ontario
- Trent-Severn / Georgian Bay
- North Channel / Lake Huron
- Straits of Mackinac
- Lake Michigan - East Shore
- Lake Michigan - Wisconsin / Door County

## Public status values generated

- `public_candidate` — OSM tags suggest public or fee-based access.
- `restricted_or_private_review` — OSM tags suggest private, members, customers, or no access.
- `unknown_review` — OSM does not provide enough access information.

Do not publish `restricted_or_private_review` or `unknown_review` rows without manual review.
