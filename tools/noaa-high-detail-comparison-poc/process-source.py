#!/usr/bin/env python3
"""Strict GDAL helpers for the isolated Southern Tampa Bay comparison POC.

This utility is intentionally coupled to one approved NOAA source tile and one
approved 2 km x 2 km extent. It is executed only inside the pinned GDAL
container by process-source.sh; it is not a runtime application dependency.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import time
from pathlib import Path
from typing import Any, Iterable

import numpy as np
from osgeo import gdal, osr


gdal.UseExceptions()

SOURCE_FILENAME = "2021_339000e_3067000n_dem.tif"
SOURCE_URL = (
    "https://noaa-nos-coastal-lidar-pds.s3.amazonaws.com/dem/"
    "NGS_South_TampBay_Topobathy_2021_9481/"
    "2021_339000e_3067000n_dem.tif"
)
SOURCE_METADATA_URL = (
    "https://noaa-nos-coastal-lidar-pds.s3.amazonaws.com/dem/"
    "NGS_South_TampBay_Topobathy_2021_9481/"
    "2021_ngs_topobathy_southTampaBay_dem_m9481_met_forHumans.html"
)
SOURCE_EXPECTED_SIZE = 102_303_312
SOURCE_EXPECTED_SHA256 = (
    "4d943093c0f88b72007d0f99e3e325395a8d0ec21c8be01baba1e7d87de43c90"
)
SOURCE_SIZE = (5000, 5000)
SOURCE_GEOTRANSFORM = (339000.0, 1.0, 0.0, 3067000.0, 0.0, -1.0)
SOURCE_EXPECTED_STATS = {
    "minimum": -12.875007629395,
    "maximum": 2.5756149291992,
    "mean": -4.5845984344772,
    "standard_deviation": 2.1032851725218,
}

EPSG_CODE = 6346
NODATA_VALUE = -999999.0
CLIP_BOUNDS_UTM17 = {
    "west": 339267.0,
    "east": 341267.0,
    "south": 3064121.0,
    "north": 3066121.0,
}
CLIP_SIZE = (2000, 2000)
CLIP_GEOTRANSFORM = (339267.0, 1.0, 0.0, 3066121.0, 0.0, -1.0)
CLIP_EXPECTED_VALID_CELLS = 3_998_814
CLIP_EXPECTED_NODATA_CELLS = 1_186
CLIP_EXPECTED_STATS = {
    "minimum": -7.9072036743164,
    "maximum": -0.27562141418457,
    "mean": -4.2005139953864,
    "standard_deviation": 1.7865790127101,
}

PALETTE = (
    ("nv", 0, 0, 0, 0),
    (-20.0, 31, 154, 138, 255),
    (-18.0, 32, 164, 134, 255),
    (-16.0, 40, 174, 128, 255),
    (-14.0, 53, 183, 121, 255),
    (-12.0, 72, 193, 110, 255),
    (-10.0, 94, 201, 98, 255),
    (-5.0, 117, 208, 84, 255),
    (-0.1, 144, 215, 67, 255),
    (0.0, 173, 220, 48, 255),
    (5.0, 229, 228, 25, 255),
    (25.0, 253, 231, 37, 255),
)

EXPECTED_TILE_RANGES = {
    14: {"x_min": 4431, "x_max": 4432, "y_min": 6878, "y_max": 6879},
    15: {"x_min": 8862, "x_max": 8864, "y_min": 13757, "y_max": 13759},
    16: {"x_min": 17725, "x_max": 17729, "y_min": 27514, "y_max": 27518},
    17: {"x_min": 35451, "x_max": 35458, "y_min": 55029, "y_max": 55036},
}
GROUND_RESOLUTION_METRES_PER_PIXEL = {
    14: 8.459536849,
    15: 4.229768425,
    16: 2.114884212,
    17: 1.057442106,
}


class ValidationError(RuntimeError):
    """Raised when an approved-source or generated-output invariant fails."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValidationError(message)


def require_close(
    actual: float,
    expected: float,
    label: str,
    *,
    absolute_tolerance: float = 1e-8,
) -> None:
    require(
        math.isclose(
            float(actual),
            float(expected),
            rel_tol=0.0,
            abs_tol=absolute_tolerance,
        ),
        f"{label} mismatch: expected {expected!r}, got {actual!r}",
    )


def require_sequence_close(
    actual: Iterable[float],
    expected: Iterable[float],
    label: str,
    *,
    absolute_tolerance: float = 1e-8,
) -> None:
    actual_values = tuple(float(value) for value in actual)
    expected_values = tuple(float(value) for value in expected)
    require(
        len(actual_values) == len(expected_values),
        f"{label} length mismatch",
    )
    for index, (actual_value, expected_value) in enumerate(
        zip(actual_values, expected_values)
    ):
        require_close(
            actual_value,
            expected_value,
            f"{label}[{index}]",
            absolute_tolerance=absolute_tolerance,
        )


def open_raster(path: Path) -> gdal.Dataset:
    require(path.is_file(), f"Raster is missing: {path}")
    dataset = gdal.Open(str(path), gdal.GA_ReadOnly)
    require(dataset is not None, f"GDAL could not open raster: {path}")
    return dataset


def spatial_reference(dataset: gdal.Dataset) -> osr.SpatialReference:
    projection = dataset.GetProjection()
    require(bool(projection), "Raster has no projection")
    reference = osr.SpatialReference()
    require(reference.ImportFromWkt(projection) == 0, "Projection WKT is invalid")
    reference.AutoIdentifyEPSG()
    return reference


def authority_code(reference: osr.SpatialReference) -> int:
    code = reference.GetAuthorityCode(None)
    if code is None:
        code = reference.GetAuthorityCode("PROJCS")
    require(code is not None, "Raster CRS has no identifiable EPSG authority code")
    return int(code)


def raster_extent(dataset: gdal.Dataset) -> dict[str, float]:
    transform = dataset.GetGeoTransform()
    require_close(transform[2], 0.0, "geotransform rotation x")
    require_close(transform[4], 0.0, "geotransform rotation y")
    x_values = (
        transform[0],
        transform[0] + (dataset.RasterXSize * transform[1]),
    )
    y_values = (
        transform[3],
        transform[3] + (dataset.RasterYSize * transform[5]),
    )
    return {
        "west": min(x_values),
        "east": max(x_values),
        "south": min(y_values),
        "north": max(y_values),
    }


def band_stats(band: gdal.Band) -> dict[str, float]:
    statistics = band.GetStatistics(False, True)
    require(statistics is not None, "GDAL did not return raster statistics")
    return {
        "minimum": float(statistics[0]),
        "maximum": float(statistics[1]),
        "mean": float(statistics[2]),
        "standard_deviation": float(statistics[3]),
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    require(not temporary.exists(), f"Temporary output already exists: {temporary}")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def validate_common_float_raster(
    dataset: gdal.Dataset,
    *,
    expected_size: tuple[int, int],
    expected_geotransform: tuple[float, ...],
    label: str,
) -> tuple[gdal.Band, osr.SpatialReference]:
    require(
        (dataset.RasterXSize, dataset.RasterYSize) == expected_size,
        (
            f"{label} dimensions mismatch: expected {expected_size}, got "
            f"{(dataset.RasterXSize, dataset.RasterYSize)}"
        ),
    )
    require(dataset.RasterCount == 1, f"{label} must have exactly one band")
    band = dataset.GetRasterBand(1)
    require(
        gdal.GetDataTypeName(band.DataType) == "Float32",
        f"{label} band must be Float32",
    )
    nodata = band.GetNoDataValue()
    require(nodata is not None, f"{label} has no nodata value")
    require_close(nodata, NODATA_VALUE, f"{label} nodata value")
    require_sequence_close(
        dataset.GetGeoTransform(),
        expected_geotransform,
        f"{label} geotransform",
    )
    reference = spatial_reference(dataset)
    require(
        authority_code(reference) == EPSG_CODE,
        f"{label} CRS must be EPSG:{EPSG_CODE}",
    )
    return band, reference


def inspect_source(arguments: argparse.Namespace) -> None:
    input_path = Path(arguments.input)
    require(
        input_path.name == SOURCE_FILENAME,
        f"Only the approved source filename is accepted: {SOURCE_FILENAME}",
    )
    dataset = open_raster(input_path)
    band, reference = validate_common_float_raster(
        dataset,
        expected_size=SOURCE_SIZE,
        expected_geotransform=SOURCE_GEOTRANSFORM,
        label="Source",
    )
    unit = band.GetUnitType()
    require(unit == "metre", f"Source vertical unit must be metre, got {unit!r}")
    extent = raster_extent(dataset)
    for key, expected_value in {
        "west": 339000.0,
        "east": 344000.0,
        "south": 3062000.0,
        "north": 3067000.0,
    }.items():
        require_close(extent[key], expected_value, f"source extent {key}")
    for key, clip_value in CLIP_BOUNDS_UTM17.items():
        if key in {"west", "south"}:
            require(
                clip_value >= extent[key],
                f"Approved clip {key} is outside the source footprint",
            )
        else:
            require(
                clip_value <= extent[key],
                f"Approved clip {key} is outside the source footprint",
            )

    statistics = band_stats(band)
    for key, expected_value in SOURCE_EXPECTED_STATS.items():
        require_close(
            statistics[key],
            expected_value,
            f"source statistic {key}",
            absolute_tolerance=1e-6,
        )

    payload = {
        "source_filename": SOURCE_FILENAME,
        "source_url": SOURCE_URL,
        "source_metadata_url": SOURCE_METADATA_URL,
        "raster_size": {
            "columns": dataset.RasterXSize,
            "rows": dataset.RasterYSize,
            "bands": dataset.RasterCount,
        },
        "data_type": gdal.GetDataTypeName(band.DataType),
        "crs": {
            "epsg": authority_code(reference),
            "name": reference.GetName(),
            "horizontal_datum": "NAD83(2011)",
            "utm_zone": "17N",
            "wkt": dataset.GetProjection(),
        },
        "vertical_datum": "NAVD88, Geoid18",
        "vertical_unit": unit,
        "native_resolution_metres": {
            "x": abs(dataset.GetGeoTransform()[1]),
            "y": abs(dataset.GetGeoTransform()[5]),
        },
        "geotransform": list(dataset.GetGeoTransform()),
        "extent_utm17_metres": extent,
        "nodata_value": float(band.GetNoDataValue()),
        "elevation_statistics_metres_navd88": statistics,
        "survey_dates": {
            "start": "2021-01-26",
            "end": "2021-02-27",
        },
    }
    write_json(Path(arguments.output), payload)


def inspect_clip(arguments: argparse.Namespace) -> None:
    dataset = open_raster(Path(arguments.input))
    band, reference = validate_common_float_raster(
        dataset,
        expected_size=CLIP_SIZE,
        expected_geotransform=CLIP_GEOTRANSFORM,
        label="Clip",
    )
    extent = raster_extent(dataset)
    for key, expected_value in CLIP_BOUNDS_UTM17.items():
        require_close(extent[key], expected_value, f"clip extent {key}")

    values = band.ReadAsArray()
    require(values is not None, "GDAL could not read the clipped elevation grid")
    valid_mask = np.isfinite(values) & (values != NODATA_VALUE)
    valid_count = int(np.count_nonzero(valid_mask))
    nodata_count = int(values.size - valid_count)
    require(
        valid_count == CLIP_EXPECTED_VALID_CELLS,
        (
            "Clip valid-cell count mismatch: expected "
            f"{CLIP_EXPECTED_VALID_CELLS}, got {valid_count}"
        ),
    )
    require(
        nodata_count == CLIP_EXPECTED_NODATA_CELLS,
        (
            "Clip nodata-cell count mismatch: expected "
            f"{CLIP_EXPECTED_NODATA_CELLS}, got {nodata_count}"
        ),
    )
    valid_values = values[valid_mask].astype(np.float64, copy=False)
    computed_stats = {
        "minimum": float(np.min(valid_values)),
        "maximum": float(np.max(valid_values)),
        "mean": float(np.mean(valid_values)),
        "standard_deviation": float(np.std(valid_values)),
    }
    for key, expected_value in CLIP_EXPECTED_STATS.items():
        require_close(
            computed_stats[key],
            expected_value,
            f"clip statistic {key}",
            absolute_tolerance=1e-6,
        )

    nodata_sample: dict[str, Any] | None = None
    nodata_locations = np.argwhere(~valid_mask)
    if nodata_locations.size:
        row, column = (int(value) for value in nodata_locations[0])
        transform = dataset.GetGeoTransform()
        x_utm = transform[0] + ((column + 0.5) * transform[1])
        y_utm = transform[3] + ((row + 0.5) * transform[5])
        source_reference = reference.Clone()
        target_reference = osr.SpatialReference()
        target_reference.ImportFromEPSG(4326)
        source_reference.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        target_reference.SetAxisMappingStrategy(osr.OAMS_TRADITIONAL_GIS_ORDER)
        coordinate_transform = osr.CoordinateTransformation(
            source_reference,
            target_reference,
        )
        longitude, latitude, _ = coordinate_transform.TransformPoint(x_utm, y_utm)
        nodata_sample = {
            "pixel": {"column": column, "row": row},
            "cell_center_utm17_metres": {"x": x_utm, "y": y_utm},
            "cell_center_wgs84": {
                "latitude": latitude,
                "longitude": longitude,
            },
            "stored_value": float(values[row, column]),
        }

    payload = {
        "raster_size": {
            "columns": dataset.RasterXSize,
            "rows": dataset.RasterYSize,
            "cells": int(values.size),
        },
        "crs_epsg": authority_code(reference),
        "geotransform": list(dataset.GetGeoTransform()),
        "extent_utm17_metres": extent,
        "native_resolution_metres": 1.0,
        "nodata_value": NODATA_VALUE,
        "valid_cells": valid_count,
        "nodata_cells": nodata_count,
        "valid_coverage_percent": (valid_count / values.size) * 100.0,
        "elevation_statistics_metres_navd88": computed_stats,
        "representative_nodata_sample": nodata_sample,
    }
    write_json(Path(arguments.output), payload)


def write_palette(arguments: argparse.Namespace) -> None:
    output_path = Path(arguments.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    require(not output_path.exists(), f"Palette output already exists: {output_path}")
    lines = [" ".join(str(value) for value in entry) for entry in PALETTE]
    output_path.write_text("\n".join(lines) + "\n", encoding="ascii")


def same_grid(left: gdal.Dataset, right: gdal.Dataset, label: str) -> None:
    require(
        (left.RasterXSize, left.RasterYSize)
        == (right.RasterXSize, right.RasterYSize),
        f"{label} raster dimensions differ",
    )
    require_sequence_close(
        left.GetGeoTransform(),
        right.GetGeoTransform(),
        f"{label} geotransform",
    )
    left_reference = spatial_reference(left)
    right_reference = spatial_reference(right)
    require(
        bool(left_reference.IsSame(right_reference)),
        f"{label} projections differ",
    )


def combine_relief(arguments: argparse.Namespace) -> None:
    color_path = Path(arguments.color)
    hillshade_path = Path(arguments.hillshade)
    output_path = Path(arguments.output)
    require(not output_path.exists(), f"Combined output already exists: {output_path}")

    color = open_raster(color_path)
    hillshade = open_raster(hillshade_path)
    require(color.RasterCount == 4, "Color relief must be RGBA")
    require(hillshade.RasterCount == 1, "Hillshade must have one band")
    require(
        (color.RasterXSize, color.RasterYSize) == CLIP_SIZE,
        "Color relief dimensions do not match the approved clip",
    )
    same_grid(color, hillshade, "Color relief and hillshade")

    color_values = np.stack(
        [color.GetRasterBand(index).ReadAsArray() for index in range(1, 5)],
        axis=0,
    )
    require(
        color_values.dtype == np.uint8,
        f"Color relief must be Byte, got {color_values.dtype}",
    )
    alpha = color_values[3]
    alpha_values = set(int(value) for value in np.unique(alpha))
    require(
        alpha_values.issubset({0, 255}),
        f"Color-relief alpha must be binary, got {sorted(alpha_values)}",
    )
    require(
        int(np.count_nonzero(alpha == 255)) == CLIP_EXPECTED_VALID_CELLS,
        "Color-relief opaque-cell count does not match the approved clip",
    )

    hillshade_values = hillshade.GetRasterBand(1).ReadAsArray()
    require(hillshade_values is not None, "GDAL could not read the hillshade")
    factor = 0.65 + (0.35 * (hillshade_values.astype(np.float32) / 255.0))
    combined_rgb = np.rint(
        color_values[:3].astype(np.float32) * factor[np.newaxis, :, :]
    )
    combined_rgb = np.clip(combined_rgb, 0, 255).astype(np.uint8)
    combined_rgb[:, alpha == 0] = 0

    driver = gdal.GetDriverByName("GTiff")
    require(driver is not None, "GTiff driver is unavailable")
    output = driver.Create(
        str(output_path),
        color.RasterXSize,
        color.RasterYSize,
        4,
        gdal.GDT_Byte,
        options=[
            "TILED=YES",
            "BLOCKXSIZE=256",
            "BLOCKYSIZE=256",
            "COMPRESS=DEFLATE",
            "PREDICTOR=2",
            "BIGTIFF=IF_SAFER",
        ],
    )
    require(output is not None, "GDAL could not create the combined relief")
    output.SetGeoTransform(color.GetGeoTransform())
    output.SetProjection(color.GetProjection())
    output.SetMetadata(
        {
            "FPW_COMBINATION_FORMULA": (
                "color_rgb * (0.65 + 0.35 * hillshade/255)"
            ),
            "FPW_COLOR_SOURCE": "NOAA BlueTopo nbs_elevation palette",
            "FPW_HILLSHADE": (
                "multidirectional; vertical_exaggeration=2.0; compute_edges=true"
            ),
        }
    )
    interpretations = (
        gdal.GCI_RedBand,
        gdal.GCI_GreenBand,
        gdal.GCI_BlueBand,
        gdal.GCI_AlphaBand,
    )
    for index in range(3):
        output_band = output.GetRasterBand(index + 1)
        output_band.SetColorInterpretation(interpretations[index])
        output_band.WriteArray(combined_rgb[index])
    alpha_band = output.GetRasterBand(4)
    alpha_band.SetColorInterpretation(gdal.GCI_AlphaBand)
    alpha_band.WriteArray(alpha)
    output.FlushCache()
    output = None


def validate_combined(arguments: argparse.Namespace) -> None:
    dataset = open_raster(Path(arguments.input))
    require(
        (dataset.RasterXSize, dataset.RasterYSize) == CLIP_SIZE,
        "Combined relief dimensions do not match the approved clip",
    )
    require(dataset.RasterCount == 4, "Combined relief must have four bands")
    require_sequence_close(
        dataset.GetGeoTransform(),
        CLIP_GEOTRANSFORM,
        "combined relief geotransform",
    )
    require(
        authority_code(spatial_reference(dataset)) == EPSG_CODE,
        f"Combined relief CRS must be EPSG:{EPSG_CODE}",
    )
    for index, expected_interpretation in enumerate(
        (
            gdal.GCI_RedBand,
            gdal.GCI_GreenBand,
            gdal.GCI_BlueBand,
            gdal.GCI_AlphaBand,
        ),
        start=1,
    ):
        band = dataset.GetRasterBand(index)
        require(
            band.DataType == gdal.GDT_Byte,
            f"Combined relief band {index} must be Byte",
        )
        require(
            band.GetColorInterpretation() == expected_interpretation,
            f"Combined relief band {index} has the wrong color interpretation",
        )
    alpha = dataset.GetRasterBand(4).ReadAsArray()
    alpha_values = set(int(value) for value in np.unique(alpha))
    require(
        alpha_values.issubset({0, 255}),
        f"Combined alpha must be binary, got {sorted(alpha_values)}",
    )
    opaque_count = int(np.count_nonzero(alpha == 255))
    transparent_count = int(np.count_nonzero(alpha == 0))
    require(
        opaque_count == CLIP_EXPECTED_VALID_CELLS,
        f"Combined opaque count mismatch: got {opaque_count}",
    )
    require(
        transparent_count == CLIP_EXPECTED_NODATA_CELLS,
        f"Combined transparent count mismatch: got {transparent_count}",
    )
    transparent_mask = alpha == 0
    for index in range(1, 4):
        color_band = dataset.GetRasterBand(index).ReadAsArray()
        require(
            bool(np.all(color_band[transparent_mask] == 0)),
            f"Combined RGB band {index} is nonzero under transparent pixels",
        )


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_tile_paths() -> set[str]:
    paths: set[str] = set()
    for zoom, ranges in EXPECTED_TILE_RANGES.items():
        for x_value in range(ranges["x_min"], ranges["x_max"] + 1):
            for y_value in range(ranges["y_min"], ranges["y_max"] + 1):
                paths.add(f"{zoom}/{x_value}/{y_value}.png")
    return paths


def load_json(path: Path) -> dict[str, Any]:
    require(path.is_file(), f"Required metadata JSON is missing: {path}")
    value = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(value, dict), f"Metadata JSON must contain an object: {path}")
    return value


def validate_tile(path: Path) -> dict[str, int]:
    require(path.is_file(), f"Tile is missing: {path}")
    require(not path.is_symlink(), f"Tile must not be a symlink: {path}")
    dataset = open_raster(path)
    require(
        (dataset.RasterXSize, dataset.RasterYSize) == (256, 256),
        f"Tile must be 256 x 256 pixels: {path}",
    )
    require(
        dataset.RasterCount in {3, 4},
        f"Tile must be RGB or RGBA: {path}",
    )
    for index in range(1, dataset.RasterCount + 1):
        require(
            dataset.GetRasterBand(index).DataType == gdal.GDT_Byte,
            f"Tile band {index} must be Byte: {path}",
        )
    if dataset.RasterCount == 3:
        return {
            "opaque_pixels": 256 * 256,
            "transparent_pixels": 0,
        }

    alpha = dataset.GetRasterBand(4).ReadAsArray()
    alpha_values = set(int(value) for value in np.unique(alpha))
    require(
        alpha_values.issubset({0, 255}),
        f"Tile alpha must be binary: {path} has {sorted(alpha_values)}",
    )
    opaque_pixels = int(np.count_nonzero(alpha == 255))
    require(opaque_pixels > 0, f"Fully transparent tile must be excluded: {path}")
    return {
        "opaque_pixels": opaque_pixels,
        "transparent_pixels": int(np.count_nonzero(alpha == 0)),
    }


def output_transparent_sample(
    tiles_directory: Path,
    source_nodata_sample: dict[str, Any],
    *,
    zoom: int = 17,
    search_radius_pixels: int = 4,
) -> dict[str, Any]:
    source_wgs84 = source_nodata_sample["cell_center_wgs84"]
    latitude = float(source_wgs84["latitude"])
    longitude = float(source_wgs84["longitude"])
    scale = float(256 * (2**zoom))
    latitude_radians = math.radians(latitude)
    source_global_x = ((longitude + 180.0) / 360.0) * scale
    source_global_y = (
        1.0
        - (math.asinh(math.tan(latitude_radians)) / math.pi)
    ) * 0.5 * scale
    base_global_x = math.floor(source_global_x)
    base_global_y = math.floor(source_global_y)

    candidates: list[tuple[float, int, int]] = []
    for offset_y in range(-search_radius_pixels, search_radius_pixels + 1):
        for offset_x in range(-search_radius_pixels, search_radius_pixels + 1):
            global_x = base_global_x + offset_x
            global_y = base_global_y + offset_y
            distance_pixels = math.hypot(
                (global_x + 0.5) - source_global_x,
                (global_y + 0.5) - source_global_y,
            )
            candidates.append((distance_pixels, global_x, global_y))

    for distance_pixels, global_x, global_y in sorted(candidates):
        tile_x = global_x // 256
        tile_y = global_y // 256
        pixel_x = global_x % 256
        pixel_y = global_y % 256
        tile_path = tiles_directory / str(zoom) / str(tile_x) / f"{tile_y}.png"
        if not tile_path.is_file():
            continue
        dataset = open_raster(tile_path)
        if dataset.RasterCount != 4:
            continue
        alpha = dataset.GetRasterBand(4).ReadAsArray(pixel_x, pixel_y, 1, 1)
        if alpha is None or int(alpha[0, 0]) != 0:
            continue

        world_x = (global_x + 0.5) / scale
        world_y = (global_y + 0.5) / scale
        output_longitude = (world_x * 360.0) - 180.0
        output_latitude = math.degrees(
            math.atan(math.sinh(math.pi * (1.0 - (2.0 * world_y))))
        )
        earth_radius_metres = 6_371_008.8
        latitude_delta = math.radians(output_latitude - latitude)
        longitude_delta = math.radians(output_longitude - longitude)
        haversine = (
            math.sin(latitude_delta / 2.0) ** 2
            + math.cos(latitude_radians)
            * math.cos(math.radians(output_latitude))
            * math.sin(longitude_delta / 2.0) ** 2
        )
        distance_metres = 2.0 * earth_radius_metres * math.asin(
            min(1.0, math.sqrt(haversine))
        )
        return {
            "purpose": (
                "Deterministic browser proof of preserved natural nodata "
                "transparency after Web Mercator reprojection."
            ),
            "zoom": zoom,
            "tile": {"x": tile_x, "y": tile_y},
            "pixel": {"x": pixel_x, "y": pixel_y},
            "pixel_center_wgs84": {
                "latitude": output_latitude,
                "longitude": output_longitude,
            },
            "alpha": 0,
            "distance_from_source_nodata_cell_center_metres": distance_metres,
            "distance_from_source_nodata_cell_center_pixels": distance_pixels,
        }

    raise ValidationError(
        "No transparent output pixel was found near the representative "
        "natural source nodata cell"
    )


def build_manifest(arguments: argparse.Namespace) -> None:
    tiles_directory = Path(arguments.tiles_dir)
    require(tiles_directory.is_dir(), f"Tiles directory is missing: {tiles_directory}")
    require(
        int(arguments.source_size_bytes) == SOURCE_EXPECTED_SIZE,
        "Manifest source size does not match the approved source",
    )
    require(
        arguments.source_sha256 == SOURCE_EXPECTED_SHA256,
        "Manifest source checksum does not match the approved source",
    )

    expected_paths = expected_tile_paths()
    actual_paths = {
        path.relative_to(tiles_directory).as_posix()
        for path in tiles_directory.rglob("*.png")
    }
    missing_paths = sorted(expected_paths - actual_paths)
    extra_paths = sorted(actual_paths - expected_paths)
    require(not missing_paths, f"Generated tile set is missing: {missing_paths}")
    require(not extra_paths, f"Generated tile set has extras: {extra_paths}")
    require(
        len(actual_paths) == 102,
        f"Generated tile count must be 102, got {len(actual_paths)}",
    )

    tile_set_digest = hashlib.sha256()
    per_zoom: dict[str, dict[str, Any]] = {}
    total_tile_bytes = 0
    total_opaque_pixels = 0
    total_transparent_pixels = 0
    for relative_path in sorted(actual_paths):
        tile_path = tiles_directory / relative_path
        tile_result = validate_tile(tile_path)
        tile_bytes = tile_path.stat().st_size
        tile_sha = file_sha256(tile_path)
        tile_set_digest.update(relative_path.encode("utf-8"))
        tile_set_digest.update(b"\0")
        tile_set_digest.update(bytes.fromhex(tile_sha))
        zoom = relative_path.split("/", 1)[0]
        zoom_entry = per_zoom.setdefault(
            zoom,
            {
                "tile_count": 0,
                "png_bytes": 0,
                "ground_resolution_metres_per_pixel": (
                    GROUND_RESOLUTION_METRES_PER_PIXEL[int(zoom)]
                ),
                **EXPECTED_TILE_RANGES[int(zoom)],
            },
        )
        zoom_entry["tile_count"] += 1
        zoom_entry["png_bytes"] += tile_bytes
        total_tile_bytes += tile_bytes
        total_opaque_pixels += tile_result["opaque_pixels"]
        total_transparent_pixels += tile_result["transparent_pixels"]

    require(
        total_transparent_pixels > 0,
        "Generated tile set must preserve transparent nodata pixels",
    )

    source_metadata = load_json(Path(arguments.source_metadata))
    clip_metadata = load_json(Path(arguments.clip_metadata))
    representative_output_transparent_sample = output_transparent_sample(
        tiles_directory,
        clip_metadata["representative_nodata_sample"],
    )
    manifest_measurement_at = time.time()
    payload = {
        "schema_version": 1,
        "layer": {
            "id": "south-tampa-high-detail",
            "title": "2021 NOAA NGS Southern Tampa Bay 1 m Topobathymetry",
            "description": (
                "Restrained color relief and multidirectional hillshade derived "
                "from the approved native-resolution NOAA topobathymetry clip."
            ),
            "tile_url_template": (
                "/assets/maps/poc/south-tampa-high-detail/{z}/{x}/{y}.png"
            ),
            "tile_format": (
                "XYZ PNG; RGB for fully opaque tiles and RGBA where nodata "
                "requires transparency"
            ),
            "min_zoom": 14,
            "max_zoom": 17,
            "max_native_zoom": 17,
            "native_resolution_metres": 1.0,
            "vertical_datum": "NAVD88, Geoid18",
            "units": "metres",
            "value_label": "Bathymetric elevation relative to NAVD88",
            "valid_coverage_percent": clip_metadata["valid_coverage_percent"],
            "not_current_water_depth": True,
            "not_for_navigation": True,
        },
        "source": {
            "product_name": (
                "2021 NOAA NGS Southern Tampa Bay Topobathy DEM"
            ),
            "agency": (
                "National Oceanic and Atmospheric Administration, "
                "National Geodetic Survey"
            ),
            "filename": SOURCE_FILENAME,
            "url": SOURCE_URL,
            "metadata_url": SOURCE_METADATA_URL,
            "size_bytes": int(arguments.source_size_bytes),
            "sha256": arguments.source_sha256,
            "survey_dates": {
                "start": "2021-01-26",
                "end": "2021-02-27",
            },
            "horizontal_crs": "NAD83(2011) / UTM zone 17N",
            "horizontal_crs_epsg": EPSG_CODE,
            "vertical_datum": "NAVD88, Geoid18",
            "units": "metres",
            "source_metadata_verified": source_metadata,
            "dataset_level_qa": {
                "bathymetric_rmsez_centimetres": 15.5,
                "bathymetric_95_percent_confidence_centimetres": 30.4,
                "scope_note": (
                    "These are dataset-level QA values reported by the source; "
                    "they are not per-cell guarantees."
                ),
            },
            "limitations": [
                "Informational visualization; not intended for charting or navigation.",
                "Bathymetric elevation relative to NAVD88 is not current water depth.",
                "Do not directly compare these values with NOAA charted depths relative to MLLW.",
                "NOAA does not endorse or certify FloatPlanWizard.",
            ],
        },
        "approved_extent": {
            "center_wgs84": {
                "latitude": 27.7009075652856,
                "longitude": -82.6200072680348,
            },
            "bounds_utm17_metres": CLIP_BOUNDS_UTM17,
            "corners_wgs84": {
                "northwest": {
                    "latitude": 27.7098125683432,
                    "longitude": -82.6302800675715,
                },
                "northeast": {
                    "latitude": 27.7100499393613,
                    "longitude": -82.6100010567928,
                },
                "southeast": {
                    "latitude": 27.6920017176445,
                    "longitude": -82.6097361351387,
                },
                "southwest": {
                    "latitude": 27.6917645274034,
                    "longitude": -82.6300118126363,
                },
            },
            "clip_metadata_verified": clip_metadata,
        },
        "rendering": {
            "palette": {
                "name": "NOAA BlueTopo nbs_elevation",
                "entries": [
                    {
                        "value_metres": entry[0],
                        "rgba": list(entry[1:]),
                    }
                    for entry in PALETTE
                ],
                "interpolation": "linear between documented breakpoints",
            },
            "hillshade": {
                "algorithm": "multidirectional",
                "vertical_exaggeration": 2.0,
                "compute_edges": True,
            },
            "combination": {
                "formula": "color_rgb * (0.65 + 0.35 * hillshade/255)",
                "alpha": "source color-relief alpha preserved",
            },
            "sharpening": False,
            "smoothing": False,
            "spatial_resampling": "nearest neighbour",
            "nodata": "transparent; missing cells are not filled",
        },
        "tiles": {
            "count": len(actual_paths),
            "png_bytes": total_tile_bytes,
            "size_note": "PNG byte count excludes this manifest file.",
            "tile_set_sha256": tile_set_digest.hexdigest(),
            "per_zoom": per_zoom,
            "opaque_pixels_across_tiles": total_opaque_pixels,
            "transparent_pixels_across_tiles": total_transparent_pixels,
            "representative_natural_nodata_output_sample": (
                representative_output_transparent_sample
            ),
        },
        "processing": {
            "generated_at_utc": arguments.generated_at_utc,
            "pinned_gdal_image": arguments.gdal_image,
            "container_image_id": arguments.gdal_image_id,
            "gdal_version": arguments.gdal_version,
            "durations_seconds": {
                "download": float(arguments.download_seconds),
                "source_validation": float(arguments.source_validation_seconds),
                "clip": float(arguments.clip_seconds),
                "relief": float(arguments.relief_seconds),
                "tiles": float(arguments.tiles_seconds),
                "validation_and_manifest_before_json_write": max(
                    0.0,
                    manifest_measurement_at
                    - float(arguments.validation_started_epoch),
                ),
                "total_before_publish_before_json_write": max(
                    0.0,
                    manifest_measurement_at
                    - float(arguments.processing_started_epoch),
                ),
            },
            "public_output_policy": (
                "Only XYZ PNG tiles and this manifest are published. The source, "
                "clip, palette, and intermediate rasters are temporary."
            ),
        },
    }
    write_json(Path(arguments.output), payload)


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        description=(
            "Strict helper for the isolated NOAA Southern Tampa Bay tile processor"
        )
    )
    commands = root.add_subparsers(dest="command", required=True)

    source_parser = commands.add_parser("inspect-source")
    source_parser.add_argument("--input", required=True)
    source_parser.add_argument("--output", required=True)
    source_parser.set_defaults(handler=inspect_source)

    clip_parser = commands.add_parser("inspect-clip")
    clip_parser.add_argument("--input", required=True)
    clip_parser.add_argument("--output", required=True)
    clip_parser.set_defaults(handler=inspect_clip)

    palette_parser = commands.add_parser("write-palette")
    palette_parser.add_argument("--output", required=True)
    palette_parser.set_defaults(handler=write_palette)

    combine_parser = commands.add_parser("combine")
    combine_parser.add_argument("--color", required=True)
    combine_parser.add_argument("--hillshade", required=True)
    combine_parser.add_argument("--output", required=True)
    combine_parser.set_defaults(handler=combine_relief)

    validate_parser = commands.add_parser("validate-combined")
    validate_parser.add_argument("--input", required=True)
    validate_parser.set_defaults(handler=validate_combined)

    manifest_parser = commands.add_parser("build-manifest")
    manifest_parser.add_argument("--source-metadata", required=True)
    manifest_parser.add_argument("--clip-metadata", required=True)
    manifest_parser.add_argument("--tiles-dir", required=True)
    manifest_parser.add_argument("--output", required=True)
    manifest_parser.add_argument("--source-size-bytes", required=True)
    manifest_parser.add_argument("--source-sha256", required=True)
    manifest_parser.add_argument("--generated-at-utc", required=True)
    manifest_parser.add_argument("--gdal-image", required=True)
    manifest_parser.add_argument("--gdal-image-id", required=True)
    manifest_parser.add_argument("--gdal-version", required=True)
    manifest_parser.add_argument("--download-seconds", required=True)
    manifest_parser.add_argument("--source-validation-seconds", required=True)
    manifest_parser.add_argument("--clip-seconds", required=True)
    manifest_parser.add_argument("--relief-seconds", required=True)
    manifest_parser.add_argument("--tiles-seconds", required=True)
    manifest_parser.add_argument("--processing-started-epoch", required=True)
    manifest_parser.add_argument("--validation-started-epoch", required=True)
    manifest_parser.set_defaults(handler=build_manifest)
    return root


def main() -> int:
    try:
        arguments = parser().parse_args()
        arguments.handler(arguments)
        return 0
    except (RuntimeError, OSError, ValueError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
