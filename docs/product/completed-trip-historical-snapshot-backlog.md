# Completed Trip Historical Snapshot Backlog

## Non-blocking Future Contract

The minimal Completed Trip view intentionally does not create a vessel/contact
snapshot system.

Current approved compromise:

- Display only the current associated `vessels.vesselName` value.
- Treat that vessel name as mutable current-profile data, not as a historical
  vessel snapshot.
- Do not display additional mutable vessel profile details as historical facts.
- Do not display live shore-contact details as historical facts.

Future backlog item:

- Define a historical completed-trip snapshot contract for vessel identity and
  shore-contact display data captured at the appropriate lifecycle point.
- Update the Completed Trip view to use those snapshots once the contract
  exists.
