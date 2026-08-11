# Solo Boater Reference Pamphlets

The seven downloadable pamphlets are generated assets for the public Solo Boating Safety Guide. The HTML guide remains the source of truth for the checklist wording: the generator parses the seven checklist groups from `solo-boating-safety-guide.cfm` and refuses to continue if their expected counts or the 84-item total change unexpectedly.

## Requirements

- Python 3
- ReportLab
- pypdf
- Poppler (`pdfinfo`, `pdftoppm`, and `pdftotext`) for independent inspection and visual QA

Install the Python packages in the intended development environment if they are not already available:

```sh
python3 -m pip install reportlab pypdf
```

## Generate and validate

Run from the FPW repository root:

```sh
python3 scripts/generate-solo-boater-pamphlets.py
python3 scripts/generate-solo-boater-pamphlets.py --check
```

Generation is deterministic. It uses the existing print-quality FloatPlanWizard logo at `assets/press/logo.png`, the shared branded Letter-size template in the generator, and the publication date defined in the generator. Each run replaces only these generated public files:

| Public file | Checklist items |
| --- | ---: |
| `downloads/solo-boater-trip-planning-guide.pdf` | 12 |
| `downloads/solo-boater-vessel-information-guide.pdf` | 7 |
| `downloads/solo-boater-personal-safety-guide.pdf` | 10 |
| `downloads/solo-boater-weather-guide.pdf` | 14 |
| `downloads/solo-boater-communications-guide.pdf` | 12 |
| `downloads/solo-boater-boat-readiness-guide.pdf` | 19 |
| `downloads/solo-boater-precautions-guide.pdf` | 10 |

The built-in validation checks PDF validity, two-to-five-page length, US Letter dimensions, nonblank pages, metadata and document language, exact checklist fidelity, supported safety language, link annotations, and the 84-item series total.

## Visual and print QA

The generator's structural checks do not replace visual inspection. Render every page after changing the template or editorial definitions:

```sh
mkdir -p tmp/pdfs/solo-boater-series
for pdf in downloads/solo-boater-*.pdf; do
  stem=${pdf:t:r}
  pdftoppm -png -r 150 "$pdf" "tmp/pdfs/solo-boater-series/$stem"
done
```

Inspect every rendered page for clipping, overlap, orphaned headings, unintended blank pages, checklist readability, link treatment, page numbering, and consistent branding. Render a grayscale pass when changing colors to confirm that borders, checkbox outlines, headings, and body copy remain distinguishable in black-and-white printing.

## Public-page contract

The checklist-panel links in `solo-boating-safety-guide.cfm` are ordinary same-origin anchors with the `download` attribute. They do not require JavaScript, account creation, authentication, payment, or form submission. `assets/js/solo-boating-safety-guide.js` records one best-effort analytics event per click without delaying or blocking the browser's normal download behavior.
