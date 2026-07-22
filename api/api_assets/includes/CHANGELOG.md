# Changelog
All notable changes to FloatPlanWizard are documented in this file.

The project follows a simple versioning approach:
- `1` = current live version
- `1.1` = next milestone (feature-complete, not yet released)
- `2` = future major evolution

---

## [1.1] – Milestone (Frozen)
**Status:** Feature-complete milestone (not yet released)  
**Tag:** v1.1-milestone

### Added
- Complete CRUD support for:
  - Float Plans
  - Vessels
  - Contacts
  - Passengers & Crew
  - Operators
  - Waypoints
- Interactive map-based waypoint creation and editing
- Dashboard panels for all core data domains
- System Alerts panel (new design)
- Centralized API handling and auth helpers
- Consistent modal-based editing workflows across the dashboard

### Improved
- Dashboard UI/UX finalized for v1.x
- Map interaction reliability (add/edit waypoint behavior)
- Client-side structure and organization (vanilla JS modules)
- Error handling and user feedback consistency
- Overall visual consistency across panels and modals

### Technical
- ColdFusion API endpoints consolidated and stabilized
- JavaScript refactored toward modular, maintainable structure
- Project frozen at a known-good state for safe future development

---

## [1] – Initial Live Release
**Status:** Live / Production

### Added
- Core FloatPlanWizard functionality
- User authentication
- Initial dashboard and data management features
- Base API and database integration

---

## Planned
### [1.1] – Public Release
- Bug fixes and polish based on milestone testing
- Performance tuning
- Final QA pass before deployment

### [2]
- Major feature expansion and/or architectural changes
- Enhanced marine data layers and integrations
- Expanded alerting, mapping, and automation features
