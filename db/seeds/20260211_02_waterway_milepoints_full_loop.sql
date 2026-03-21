-- Full-loop milepoint anchors for FPW route auto-fill.
-- These are practical planning references for section-level RM auto-population.
-- Re-runnable: this script clears only rows loaded by source='FPW_FULL_LOOP'.

DELETE FROM waterway_milepoints
WHERE source = 'FPW_FULL_LOOP';

INSERT INTO waterway_milepoints (waterway_code, location_name, alias_name, rm_value, source, is_active) VALUES
-- Great Lakes / inland route around Lakes MI-Huron-Erie
('GREAT_LAKES', 'Chicago', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'St. Joseph', 'Saint Joseph', 90.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'South Haven', NULL, 115.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Grand Haven', NULL, 160.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Ludington', NULL, 212.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Mackinaw City', 'Mackinac City', 460.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Drummond Island', NULL, 540.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Detroit', NULL, 730.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Buffalo', NULL, 980.00, 'FPW_FULL_LOOP', 1),
('GREAT_LAKES', 'Oswego', NULL, 1140.00, 'FPW_FULL_LOOP', 1),

-- Trent-Severn Waterway
('TRENT_SEVERN', 'Port Severn', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('TRENT_SEVERN', 'Big Chute', NULL, 10.00, 'FPW_FULL_LOOP', 1),
('TRENT_SEVERN', 'Orillia', NULL, 35.00, 'FPW_FULL_LOOP', 1),
('TRENT_SEVERN', 'Peterborough', NULL, 140.00, 'FPW_FULL_LOOP', 1),
('TRENT_SEVERN', 'Trenton', NULL, 240.00, 'FPW_FULL_LOOP', 1),

-- St. Lawrence River
('ST_LAWRENCE', 'Kingston', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('ST_LAWRENCE', 'Montreal', NULL, 160.00, 'FPW_FULL_LOOP', 1),
('ST_LAWRENCE', 'Quebec City', NULL, 430.00, 'FPW_FULL_LOOP', 1),

-- Erie / Oswego / NY Canal system
('ERIE_CANAL', 'Waterford', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Amsterdam', NULL, 35.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Utica', NULL, 90.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Syracuse', NULL, 150.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Oswego', NULL, 171.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Rochester', NULL, 240.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Lockport', NULL, 338.00, 'FPW_FULL_LOOP', 1),
('ERIE_CANAL', 'Tonawanda', NULL, 351.00, 'FPW_FULL_LOOP', 1),

-- Hudson River (Battery to Troy)
('HUDSON', 'New York Harbor', 'Battery', 0.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Haverstraw', NULL, 35.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Poughkeepsie', NULL, 75.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Kingston', NULL, 92.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Catskill', NULL, 112.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Albany', NULL, 145.00, 'FPW_FULL_LOOP', 1),
('HUDSON', 'Troy', NULL, 153.00, 'FPW_FULL_LOOP', 1),

-- Atlantic ICW (Norfolk southbound)
('ATLANTIC_ICW', 'Norfolk', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Beaufort', 'Beaufort NC', 200.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Myrtle Beach', NULL, 370.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Charleston', NULL, 470.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Beaufort SC', 'Beaufort South Carolina', 535.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Savannah', NULL, 560.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Brunswick', NULL, 640.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'St. Augustine', 'Saint Augustine', 780.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Jacksonville', NULL, 830.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Cape Canaveral', NULL, 900.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Stuart', NULL, 1080.00, 'FPW_FULL_LOOP', 1),
('ATLANTIC_ICW', 'Miami', NULL, 1190.00, 'FPW_FULL_LOOP', 1),

-- Okeechobee Waterway
('OKEECHOBEE', 'Stuart', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('OKEECHOBEE', 'Port Mayaca', NULL, 25.00, 'FPW_FULL_LOOP', 1),
('OKEECHOBEE', 'Clewiston', NULL, 70.00, 'FPW_FULL_LOOP', 1),
('OKEECHOBEE', 'Fort Myers', NULL, 154.00, 'FPW_FULL_LOOP', 1),

-- Gulf ICW / Gulf coast leg
('GULF_ICW', 'Fort Myers', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Sarasota', NULL, 70.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Tampa', NULL, 120.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Tarpon Springs', NULL, 170.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Carrabelle', NULL, 350.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Panama City', NULL, 470.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Pensacola', NULL, 570.00, 'FPW_FULL_LOOP', 1),
('GULF_ICW', 'Mobile', NULL, 620.00, 'FPW_FULL_LOOP', 1),

-- Tennessee River
('TENNESSEE', 'Paducah', NULL, 22.00, 'FPW_FULL_LOOP', 1),
('TENNESSEE', 'Paris Landing', NULL, 67.00, 'FPW_FULL_LOOP', 1),
('TENNESSEE', 'Clifton', NULL, 158.00, 'FPW_FULL_LOOP', 1),
('TENNESSEE', 'Pickwick', NULL, 206.00, 'FPW_FULL_LOOP', 1),
('TENNESSEE', 'Chattanooga', NULL, 464.00, 'FPW_FULL_LOOP', 1),
('TENNESSEE', 'Knoxville', NULL, 652.00, 'FPW_FULL_LOOP', 1),

-- Tenn-Tom Waterway
('TENN_TOM', 'Pickwick', NULL, 450.00, 'FPW_FULL_LOOP', 1),
('TENN_TOM', 'Aliceville', NULL, 287.00, 'FPW_FULL_LOOP', 1),
('TENN_TOM', 'Demopolis', NULL, 213.00, 'FPW_FULL_LOOP', 1),
('TENN_TOM', 'Coffeeville', NULL, 116.00, 'FPW_FULL_LOOP', 1),
('TENN_TOM', 'Mobile', NULL, 0.00, 'FPW_FULL_LOOP', 1),

-- Ohio River
('OHIO', 'Pittsburgh', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('OHIO', 'Cincinnati', NULL, 470.00, 'FPW_FULL_LOOP', 1),
('OHIO', 'Louisville', NULL, 606.00, 'FPW_FULL_LOOP', 1),
('OHIO', 'Evansville', NULL, 792.00, 'FPW_FULL_LOOP', 1),
('OHIO', 'Paducah', NULL, 934.00, 'FPW_FULL_LOOP', 1),
('OHIO', 'Cairo', NULL, 981.00, 'FPW_FULL_LOOP', 1),

-- Upper Mississippi Connector
('MISSISSIPPI', 'Cairo', NULL, 953.00, 'FPW_FULL_LOOP', 1),
('MISSISSIPPI', 'Cape Girardeau', NULL, 49.00, 'FPW_FULL_LOOP', 1),
('MISSISSIPPI', 'St. Louis', NULL, 180.00, 'FPW_FULL_LOOP', 1),
('MISSISSIPPI', 'Grafton', NULL, 218.00, 'FPW_FULL_LOOP', 1),

-- Illinois Waterway
('ILLINOIS', 'Grafton', NULL, 0.00, 'FPW_FULL_LOOP', 1),
('ILLINOIS', 'Peoria', NULL, 164.00, 'FPW_FULL_LOOP', 1),
('ILLINOIS', 'Joliet', NULL, 286.00, 'FPW_FULL_LOOP', 1),
('ILLINOIS', 'Lockport', NULL, 291.00, 'FPW_FULL_LOOP', 1),
('ILLINOIS', 'Chicago', NULL, 327.00, 'FPW_FULL_LOOP', 1);
