# FPW Route Generator Fuel Calculation

This document describes how fuel and fuel cost are calculated in the Route Generator preview and generate flows.

## Scope

- UI module: `assets/js/app/dashboard/routebuilder.js`
- API model: `api/v1/routeBuilder.cfc`
- Modal fields: `includes/modals/route_generator_modal.cfm`

The same core model is used for preview and generated routes.

## Inputs

Primary inputs used by fuel math:

- `pace`: `RELAXED`, `BALANCED`, or `AGGRESSIVE`
- `cruising_speed` (max speed in knots)
- `fuel_burn_gph`
- `idle_burn_gph`
- `idle_hours_total`
- `weather_factor_pct`
- `reserve_pct`
- `fuel_price_per_gal`
- route distance (`total_nm`) from selected legs

Additional UI inputs now persisted:

- `fuel_burn_basis`: always `MAX_SPEED`
- `fuel_burn_gph_input`: raw user-entered burn value

## Burn Input Basis (Locked)

The UI is locked to one interpretation:

- Entered value is always treated as burn at max speed.
- Backend applies pace scaling (`paceRatio^3`) and weather adjustment.
- No selected-pace conversion path is used.

## Pace Ratios

- `RELAXED = 0.25`
- `BALANCED = 0.50`
- `AGGRESSIVE = 1.00`

## Calculation Pipeline

Let:

- `D = total distance (NM)`
- `Smax = cruising_speed`
- `R = paceRatio`
- `W = weather_factor_pct / 100`
- `Bmax = fuel_burn_gph` (max-speed burn entered by user)
- `Bidle = idle_burn_gph`
- `Hidle = idle_hours_total`
- `Pres = reserve_pct / 100`
- `Pfuel = fuel_price_per_gal`

Then:

1. Effective speed from pace  
   - `Seff = round2(Smax * R)`

2. Weather-adjusted speed  
   - `Sweather = round2(Seff * (1 - W))`
   - minimum clamp: `Sweather >= 0.5`

3. Pace-adjusted burn  
   - `Bpace = round2(Bmax * (R^3))`

4. Weather-adjusted burn  
   - `Bweather = round2(Bpace * (1 + W))`

5. Cruise hours  
   - `Hcruise = round2(D / Sweather)`

6. Cruise fuel  
   - `Fcruise = round2(Hcruise * Bweather)`

7. Idle fuel  
   - `Fidle = round2(Bidle * Hidle)`  
   - When either idle input is empty or zero, this is zero.

8. Base fuel  
   - `Fbase = round2(Fcruise + Fidle)`

9. Reserve fuel  
   - `Freserve = round2(Fbase * Pres)`  
   - If reserve resolves to `<= 0`, backend defaults reserve to `20%`.

10. Required fuel  
    - `Frequired = round2(Fbase + Freserve)`

11. Fuel cost  
    - `Cost = round2(Frequired * Pfuel)` if `Pfuel > 0`, else `0`

## Bounds and Normalization

- `fuel_burn_gph`: `0..1000`
- `idle_burn_gph`: `0..1000`
- `weather_factor_pct`: `0..60`
- `reserve_pct`: `0..100` (with model fallback to `20` when reserve is not positive)
- `fuel_price_per_gal`: `0..1000`

## Returned Fuel Fields

From `routegen_preview`, fuel-related fields include:

- `totals.cruise_fuel_gallons`
- `totals.idle_fuel_gallons`
- `totals.base_fuel_gallons`
- `totals.reserve_fuel_gallons`
- `totals.required_fuel_gallons`
- `totals.fuel_cost_estimate`
- `totals.fuel_price_per_gal`

And in `inputs`:

- `fuel_burn_gph` (max-speed equivalent used by model)
- `fuel_burn_gph_input` (raw user value)
- `fuel_burn_basis` (always `MAX_SPEED`)

## Worked Example (Chicago -> Peoria Segment)

Input set:

- distance: `555 NM`
- pace: `RELAXED`
- max speed: `20 kn`
- weather: `5%`
- reserve: `20%`
- price: `$4.99`
- entered burn: `3.0 GPH`
- idle burn: `1.0 GPH`, idle hours empty

- `Bmax = 3.0`
- model output is low due to relaxed pace cubic scaling
- required fuel is about `7.01 gal`
- cost is about `$34.98`

## Maintenance Notes

- If pace behavior changes, update both:
  - JS fuel model logic (`getFuelBurnModelValues`)
  - API pace defaults/ratio logic
- If reserve fallback behavior changes, update this document and tests.
