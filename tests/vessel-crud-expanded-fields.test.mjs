import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const read = (relativePath) => readFileSync(resolve(repoRoot, relativePath), "utf8");
const normalizeSpace = (value) => value.replace(/\s+/g, " ").trim();
const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const memberUi = read("app/dashboard.cfm");
const memberJs = read("assets/js/app/dashboard/vessels.js");
const memberWrite = read("api/v1/vessel.cfc");
const memberRead = read("api/v1/vessels.cfc");
const adminUi = read("admin/vessel-manager.cfm");
const adminJs = read("assets/js/app/admin/vessel-manager.js");
const adminApi = read("api/v1/adminVessels.cfc");
const pdfBuilder = read("api/api_assets/floatPlanUtils.cfc");
const migrationUp = read("database/migrations/20260831_002_vessel_fuel_capacities.up.sql");
const migrationDown = read("database/migrations/20260831_002_vessel_fuel_capacities.down.sql");
const migrationPreflight = read("database/migrations/20260831_002_vessel_fuel_capacities.preflight.sql");
const migrationVerify = read("database/migrations/20260831_002_vessel_fuel_capacities.verify.sql");

const fieldContracts = [
  ["hin", "HIN", "hin", "vesselHin", "modalHin", "Hin"],
  ["yearBuilt", "YEARBUILT", "yearBuilt", "vesselYearBuilt", "modalYearBuilt", "YearBuilt"],
  ["draft", "DRAFT", "draft", "vesselDraft", "modalDraft", "Draft"],
  ["hullMaterial", "HULLMATERIAL", "hullMaterial", "vesselHullMaterial", "modalHullMaterial", "HullMaterial"],
  ["prominentFeatures", "PROMINENTFEATURES", "prominentFeatures", "vesselProminentFeatures", "modalProminentFeatures", "ProminentFeatures"],
  ["callSignNumber", "CALLSIGNNUMBER", "callSignNumber", "vesselCallSignNumber", "modalCallSignNumber", "CallSignNumber"],
  ["DSCMMSI", "DSCMMSI", "DSCMMSI", "vesselDscMmsi", "modalDscmmsi", "DscMmsi"],
  ["radio_1_type", "RADIO_1_TYPE", "radio_1_type", "vesselRadio1Type", "modalRadio1Type", "Radio1Type"],
  ["radio_1_channel", "RADIO_1_CHANNEL", "radio_1_channel", "vesselRadio1Channel", "modalRadio1Channel", "Radio1Channel"],
  ["radio_2_type", "RADIO_2_TYPE", "radio_2_type", "vesselRadio2Type", "modalRadio2Type", "Radio2Type"],
  ["radio_2_channel", "RADIO_2_CHANNEL", "radio_2_channel", "vesselRadio2Channel", "modalRadio2Channel", "Radio2Channel"],
  ["mobilePhone", "MOBILEPHONE", "mobilePhone", "vesselMobilePhone", "modalMobilePhone", "MobilePhone"],
  ["sattelite", "SATTELITE", "sattelite", "vesselSatellitePhone", "modalSattelite", "Sattelite"],
  ["primaryPropulsion", "PRIMARYPROPULSION", "primaryPropulsion", "vesselPrimaryPropulsion", "modalPrimaryPropulsion", "PrimaryPropulsion"],
  ["primaryPropulsionType", "PRIMARYPROPULSIONTYPE", "primaryPropulsionType", "vesselPrimaryPropulsionType", "modalPrimaryPropulsionType", "PrimaryPropulsionType"],
  ["numberPrimary", "NUMBERPRIMARY", "numberPrimary", "vesselNumberPrimary", "modalNumberPrimary", "NumberPrimary"],
  ["primaryFuelCapacity", "PRIMARYFUELCAPACITY", "primaryFuelCapacity", "vesselPrimaryFuelCapacity", "modalPrimaryFuelCapacity", "PrimaryFuelCapacity"],
  ["auxPropulsion", "AUXPROPULSION", "auxPropulsion", "vesselAuxPropulsion", "modalAuxPropulsion", "AuxPropulsion"],
  ["auxPropulsionType", "AUXPROPULSIONTYPE", "auxPropulsionType", "vesselAuxPropulsionType", "modalAuxPropulsionType", "AuxPropulsionType"],
  ["numberAux", "NUMBERAUX", "numberAux", "vesselNumberAux", "modalNumberAux", "NumberAux"],
  ["auxFuelCapacity", "AUXFUELCAPACITY", "auxFuelCapacity", "vesselAuxFuelCapacity", "modalAuxFuelCapacity", "AuxFuelCapacity"],
  ["otherNavigation", "OTHERNAVIGATION", "otherNavigation", "vesselOtherNavigation", "modalOtherNavigation", "OtherNavigation"],
  ["aepirb", "AEPIRB", "aepirb", "vesselAepirb", "modalAepirb", "Aepirb"],
  ["anchor", "ANCHOR", "anchor", "vesselAnchor", "modalAnchor", "Anchor"],
  ["anchorLineLength", "ANCHORLINELENGTH", "anchorLineLength", "vesselAnchorLineLength", "modalAnchorLineLength", "AnchorLineLength"],
  ["otherEquipment", "OTHEREQUIPMENT", "otherEquipment", "vesselOtherEquipment", "modalOtherEquipment", "OtherEquipment"],
  ["otherEquipment_b", "OTHEREQUIPMENT_B", "otherEquipment_b", "vesselOtherEquipmentB", "modalOtherEquipmentB", "OtherEquipmentB"],
  ["otherEquipment_c", "OTHEREQUIPMENT_C", "otherEquipment_c", "vesselOtherEquipmentC", "modalOtherEquipmentC", "OtherEquipmentC"],
  ["otherEquipment_d", "OTHEREQUIPMENT_D", "otherEquipment_d", "vesselOtherEquipmentD", "modalOtherEquipmentD", "OtherEquipmentD"]
].map(([column, memberKey, adminKey, memberId, adminId, presenceSuffix]) => ({
  column,
  memberKey,
  adminKey,
  memberId,
  adminId,
  presenceSuffix
}));

const listContracts = [
  {
    column: "navigation",
    memberKey: "NAVIGATION",
    adminKey: "navigation",
    memberSelector: { attribute: "class", value: "vessel-navigation-option" },
    adminSelector: { attribute: "name", value: "modalNavigation" },
    tokens: ["compass", "radar", "gps_dgps", "depthSounder", "charts", "maps", "other"],
    presenceSuffix: "Navigation"
  },
  {
    column: "visualDistressSignals",
    memberKey: "VISUALDISTRESSSIGNALS",
    adminKey: "visualDistressSignals",
    memberSelector: { attribute: "class", value: "vessel-visual-distress-option" },
    adminSelector: { attribute: "name", value: "modalVisualDistressSignals" },
    tokens: ["ElectricDistressLight", "Flag", "FlareAerial", "FlareHandheld", "SignalMirror", "Smoke"],
    presenceSuffix: "VisualDistressSignals"
  },
  {
    column: "audibleDistressSignals",
    memberKey: "AUDIBLEDISTRESSSIGNALS",
    adminKey: "audibleDistressSignals",
    memberSelector: { attribute: "class", value: "vessel-audible-distress-option" },
    adminSelector: { attribute: "name", value: "modalAudibleDistressSignals" },
    tokens: ["Bell", "Horn", "Whistle"],
    presenceSuffix: "AudibleDistressSignals"
  },
  {
    column: "additionalGear",
    memberKey: "ADDITIONALGEAR",
    adminKey: "additionalGear",
    memberSelector: { attribute: "class", value: "vessel-additional-gear-option" },
    adminSelector: { attribute: "name", value: "modalAdditionalGear" },
    tokens: ["DewateringDevice", "ExposureSuits", "FireExtinguisher", "FlashlightSearchLight", "RaftDinghy"],
    presenceSuffix: "AdditionalGear"
  }
];

const allContracts = [...fieldContracts, ...listContracts];
const hullMaterials = ["Aluminum", "Composite", "Concrete", "Fabric", "Fiberglass", "Plastic", "Steel", "Wood"];
const propulsionTypes = ["Diesel IB", "Diesel IO", "Diesel OB", "Electric IB", "Electric IO", "Electric OB", "Fan", "Gas IB", "Gas IO", "Gas OB", "Oar", "Paddle", "Wind"];
const radioTypes = ["none", "CB", "HF", "MF", "VHF-FM"];

function sliceBetween(source, startNeedle, endNeedle) {
  const start = source.indexOf(startNeedle);
  const end = source.indexOf(endNeedle, start + startNeedle.length);
  assert.notEqual(start, -1, `missing start anchor: ${startNeedle}`);
  assert.notEqual(end, -1, `missing end anchor: ${endNeedle}`);
  return source.slice(start, end);
}

function openControlTag(source, id) {
  const match = source.match(new RegExp(`<(?:input|select|textarea)\\b[^>]*\\bid=["']${escapeRegExp(id)}["'][^>]*>`, "i"));
  assert.ok(match, `missing form control #${id}`);
  return match[0];
}

function attributeValue(tag, attribute) {
  const match = tag.match(new RegExp(`\\b${escapeRegExp(attribute)}=["']([^"']*)["']`, "i"));
  return match ? match[1] : "";
}

function inputValues(source, selector) {
  return [...source.matchAll(/<input\b[^>]*>/gi)]
    .map((match) => match[0])
    .filter((tag) => {
      const actual = attributeValue(tag, selector.attribute);
      return selector.attribute === "class"
        ? actual.split(/\s+/).includes(selector.value)
        : actual === selector.value;
    })
    .map((tag) => attributeValue(tag, "value"));
}

function selectValues(source, id) {
  const match = source.match(new RegExp(`<select\\b[^>]*\\bid=["']${escapeRegExp(id)}["'][^>]*>([\\s\\S]*?)<\\/select>`, "i"));
  assert.ok(match, `missing select #${id}`);
  return [...match[1].matchAll(/<option\b([^>]*)>([\s\S]*?)<\/option>/gi)].map((option) => {
    const explicitValue = attributeValue(option[1], "value");
    return /\bvalue\s*=/i.test(option[1]) ? explicitValue : option[2].replace(/<[^>]+>/g, "").trim();
  });
}

function assertOptionalControl(source, id) {
  const tag = openControlTag(source, id);
  assert.doesNotMatch(tag, /\brequired\b/i, `#${id} must remain optional`);
}

function cfArray(tokens) {
  return `[${tokens.map((token) => `"${token}"`).join(", ")}]`;
}

test("member and admin vessel forms expose the approved optional grouped controls and exact choices", () => {
  const memberModal = sliceBetween(memberUi, 'id="vesselModal"', 'id="floatPlanWizardModal"');
  const adminModal = sliceBetween(adminUi, 'id="adminVesselModal"', '<script src="https://cdn.jsdelivr.net');
  const sectionLabels = [
    "Vessel Basics",
    "Identification",
    "Communications",
    "Navigation",
    "Safety &amp; Distress Equipment",
    "Anchor &amp; Additional Gear",
    "Other Equipment"
  ];

  for (const label of sectionLabels) {
    assert.ok(memberModal.includes(label), `member form is missing ${label}`);
    assert.ok(adminModal.includes(label), `admin form is missing ${label}`);
  }
  assert.ok(memberModal.includes("Propulsion &amp; Fuel"));
  assert.ok(adminModal.includes("Propulsion &amp; Fuel"));

  for (const field of fieldContracts) {
    assertOptionalControl(memberModal, field.memberId);
    assertOptionalControl(adminModal, field.adminId);
  }

  assert.deepEqual(selectValues(memberModal, "vesselHullMaterial").slice(1), hullMaterials);
  assert.deepEqual(selectValues(adminModal, "modalHullMaterial").slice(1), hullMaterials);
  assert.deepEqual(selectValues(memberModal, "vesselPrimaryPropulsionType").slice(1), propulsionTypes);
  assert.deepEqual(selectValues(adminModal, "modalPrimaryPropulsionType").slice(1), propulsionTypes);
  assert.deepEqual(selectValues(memberModal, "vesselAuxPropulsionType").slice(1), ["none", ...propulsionTypes]);
  assert.deepEqual(selectValues(adminModal, "modalAuxPropulsionType").slice(1), ["none", ...propulsionTypes]);
  assert.deepEqual(selectValues(memberModal, "vesselRadio1Type").slice(1), radioTypes);
  assert.deepEqual(selectValues(memberModal, "vesselRadio2Type").slice(1), radioTypes);
  assert.deepEqual(selectValues(adminModal, "modalRadio1Type").slice(1), radioTypes);
  assert.deepEqual(selectValues(adminModal, "modalRadio2Type").slice(1), radioTypes);

  for (const field of listContracts) {
    assert.deepEqual(inputValues(memberModal, field.memberSelector), field.tokens, `member ${field.column} tokens changed`);
    assert.deepEqual(inputValues(adminModal, field.adminSelector), field.tokens, `admin ${field.column} tokens changed`);
  }

  for (const id of ["vesselPrimaryFuelCapacity", "vesselAuxFuelCapacity", "modalPrimaryFuelCapacity", "modalAuxFuelCapacity"]) {
    const source = id.startsWith("modal") ? adminModal : memberModal;
    const tag = openControlTag(source, id);
    assert.equal(attributeValue(tag, "type"), "number");
    assert.equal(attributeValue(tag, "min"), "0");
    assert.equal(attributeValue(tag, "step"), "0.01");
  }
  assert.match(memberModal, /for="vesselPrimaryFuelCapacity">Primary Fuel Capacity \(gal\)<\/label>/);
  assert.match(memberModal, /for="vesselAuxFuelCapacity">Auxiliary Fuel Capacity \(gal\)<\/label>/);
  assert.match(memberModal, /Total Fuel Capacity \(gal\)/);
  assert.match(adminModal, /Total Fuel Capacity/);

  for (const excluded of ["Trailer", "Food", "Water", "Timezone"]) {
    assert.doesNotMatch(memberModal, new RegExp(`(?:id|name)=["']vessel${excluded}(?:[A-Z][^"']*)?["']`, "i"));
    assert.doesNotMatch(adminModal, new RegExp(`(?:id|name)=["']modal${excluded}(?:[A-Z][^"']*)?["']`, "i"));
  }
});

test("member and admin JavaScript and APIs cover every approved field without adding deferred fields", () => {
  const memberPayload = sliceBetween(memberJs, "function buildVesselPayload()", "function saveVessel()");
  const adminPayload = sliceBetween(adminJs, "function buildModalPayload()", "async function saveModalVessel()");

  for (const field of allContracts) {
    assert.match(memberPayload, new RegExp(`\\b${escapeRegExp(field.memberKey)}\\s*:`), `member payload misses ${field.column}`);
    assert.match(adminPayload, new RegExp(`\\b${escapeRegExp(field.adminKey)}\\s*:`), `admin payload misses ${field.column}`);
    assert.match(memberRead, new RegExp(`v\\.${escapeRegExp(field.column)}\\b`, "i"), `member read query misses ${field.column}`);
    assert.match(memberRead, new RegExp(`\\b${escapeRegExp(field.memberKey)}\\s*=`), `member response misses ${field.memberKey}`);
    assert.match(adminApi, new RegExp(`\\{\\s*name\\s*=\\s*"${escapeRegExp(field.adminKey)}"\\s*,\\s*column\\s*=\\s*"${escapeRegExp(field.column)}"`), `admin optional spec misses ${field.column}`);
    assert.match(adminApi, new RegExp(`v\\.${escapeRegExp(field.column)}\\b`, "i"), `admin read query misses ${field.column}`);
  }

  for (const field of fieldContracts) {
    assert.match(memberWrite, new RegExp(`<cfset\\s+has${field.presenceSuffix}\\s*=\\s*hasPayloadKey`, "i"), `member omission flag misses ${field.column}`);
    assert.match(memberWrite, new RegExp(`<cfif\\s+has${field.presenceSuffix}>\\s*,?\\s*${escapeRegExp(field.column)}\\s*=`, "i"), `member omission-aware update misses ${field.column}`);
  }
  for (const field of listContracts) {
    assert.match(memberWrite, new RegExp(`<cfset\\s+has${field.presenceSuffix}\\s*=\\s*hasPayloadKey`, "i"));
    assert.match(memberWrite, new RegExp(`<cfif\\s+has${field.presenceSuffix}>\\s*,?\\s*${escapeRegExp(field.column)}\\s*=`, "i"));
  }

  assert.match(adminApi, /optionalPresent\[optionalSpec\.name\]\s*=\s*len\(optionalKey\)\s+GT\s+0/i);
  assert.match(adminApi, /if\s*\(!optionalPresent\[optionalSpec\.name\]\)\s*continue/i);
  assert.match(adminApi, /null\s*=\s*!len\(arguments\.value\)/i);
  assert.match(memberWrite, /primaryFuelCapacity\s*=\s*<cfqueryparam\s+cfsqltype="cf_sql_decimal"[\s\S]*?null="#NOT hasPrimaryFuelCapacityValue#"/i);
  assert.match(memberWrite, /auxFuelCapacity\s*=\s*<cfqueryparam\s+cfsqltype="cf_sql_decimal"[\s\S]*?null="#NOT hasAuxFuelCapacityValue#"/i);

  const normalizedMemberWrite = normalizeSpace(memberWrite);
  const normalizedAdminApi = normalizeSpace(adminApi);
  for (const source of [normalizedMemberWrite, normalizedAdminApi]) {
    assert.ok(source.includes(cfArray(hullMaterials)));
    assert.ok(source.includes(cfArray(propulsionTypes)));
    assert.ok(source.includes(cfArray(radioTypes)));
    for (const field of listContracts) {
      assert.ok(source.includes(cfArray(field.tokens)), `${field.column} server token contract changed`);
    }
  }

  for (const source of [memberPayload, adminPayload, memberWrite, memberRead, adminApi]) {
    assert.doesNotMatch(source, /\b(?:trailer|food|water|timezone)\b/i);
  }
});

test("primary and auxiliary capacities migrate to independent nullable decimals without redefining total fuel", () => {
  assert.match(migrationUp, /MODIFY COLUMN `primaryFuelCapacity` DECIMAL\(10,2\) NULL DEFAULT NULL/i);
  assert.match(migrationUp, /MODIFY COLUMN `auxFuelCapacity` DECIMAL\(10,2\) NULL DEFAULT NULL/i);
  assert.match(migrationDown, /MODIFY COLUMN `primaryFuelCapacity` VARCHAR\(45\)[\s\S]{0,100}?NULL DEFAULT NULL/i);
  assert.match(migrationDown, /MODIFY COLUMN `auxFuelCapacity` VARCHAR\(45\)[\s\S]{0,100}?NULL DEFAULT NULL/i);
  assert.match(migrationPreflight, /NOT REGEXP\s+''\^\[\+\]\?\[0-9\]\+\(\[\.\]\[0-9\]\+\)\?\$''/i);
  assert.match(migrationVerify, /DATA_TYPE = 'decimal'/i);
  assert.match(migrationVerify, /NUMERIC_PRECISION = 10/i);
  assert.match(migrationVerify, /NUMERIC_SCALE = 2/i);

  for (const migration of [migrationUp, migrationDown]) {
    assert.doesNotMatch(migration, /MODIFY COLUMN `fuel_capacity`/i);
    assert.doesNotMatch(migration, /SET\s+`?fuel_capacity`?\s*=/i);
  }
  assert.match(memberWrite, /Primary fuel capacity must be between 0 and 99999999\.99 with no more than two decimal places/i);
  assert.match(memberWrite, /Auxiliary fuel capacity must be between 0 and 99999999\.99 with no more than two decimal places/i);
  assert.match(adminApi, /must be a non-negative number with no more than two decimal places/i);
});

test("PDF identification uses owner-scoped Account Home Port while food and water remain trip-owned", () => {
  assert.match(pdfBuilder, /accountHomePort\s*=\s*loadAccountHomePort\(arguments\.userId,\s*ds\)/i);
  assert.match(pdfBuilder, /vesselIdentification\s*=\s*buildVesselIdentification\(vesselName,\s*accountHomePort\)/i);
  assert.match(pdfBuilder, /<cfpdfformparam\s+name="ID-VesselName"\s+value="#vesselIdentification#">/i);
  assert.match(pdfBuilder, /FROM\s+users_address[\s\S]*?WHERE\s+userId\s*=\s*:userId[\s\S]*?AND\s+isHomePort\s*=\s*1/i);
  assert.doesNotMatch(pdfBuilder, /getString\(vessel,\s*"hailingPort"/i);

  assert.match(pdfBuilder, /var\s+food\s*=\s*getString\(plan,\s*"food"/i);
  assert.match(pdfBuilder, /var\s+water\s*=\s*getString\(plan,\s*"water"/i);
  assert.doesNotMatch(pdfBuilder, /getString\(vessel,\s*"(?:food|water)"/i);
  assert.match(pdfBuilder, /formatPdfGallons\(getString\(vessel,\s*"primaryFuelCapacity"/i);
  assert.match(pdfBuilder, /formatPdfGallons\(getString\(vessel,\s*"auxFuelCapacity"/i);

  // Safest Fix: retain the existing trailer-to-PDF path but do not expose it in CRUD.
  assert.match(pdfBuilder, /getAny\(vessel,\s*"trailer"/i);
  assert.match(pdfBuilder, /name="OPR-VesselTrailored"/i);
});
