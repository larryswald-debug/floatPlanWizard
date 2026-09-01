const { test, expect } = require("@playwright/test");

const baseUrl = "http://localhost:8500/fpw";
const cleanupUrl = `${baseUrl}/tests/onboarding-runner.cfm`
  + "?confirm=RUN_DISPOSABLE_WELCOME_ONBOARDING_TESTS&reporter=json&cleanupOnly=1";
const password = "VesselCrud!2026";

test.describe.configure({ mode: "serial" });

function disposableEmail(label) {
  const nonce = `${Date.now()}-${Math.random().toString(16).slice(2)}`;
  return `codex-welcome-onboarding-vessel-crud-${label}-${nonce}@example.test`;
}

async function createDisposableMember(page, label) {
  const email = disposableEmail(label);
  const response = await page.goto(`${baseUrl}/app/join.cfm`, { waitUntil: "domcontentloaded" });

  expect(response && response.status()).toBe(200);
  await page.locator("#firstName").fill("Vessel");
  await page.locator("#lastName").fill("Contract");
  await page.locator("#email").fill(email);
  await page.locator("#password").fill(password);
  await page.locator("#confirmPassword").fill(password);
  await page.locator("#termsAccepted").check();

  await Promise.all([
    page.waitForURL(/\/fpw\/app\/dashboard\.cfm/),
    page.locator("#joinButton").click()
  ]);
  await page.waitForFunction(() => window.Api && typeof window.Api.saveVessel === "function");
  await expect(page.locator("#welcomeOnboardingModal")).toBeVisible();
  await page.locator("#welcomeOnboardingCloseBtn").click();
  await expect(page.locator("#welcomeOnboardingModal")).toBeHidden();
}

function valueFrom(source, ...keys) {
  for (const key of keys) {
    if (source && source[key] !== undefined && source[key] !== null) return source[key];
  }
  return "";
}

async function saveVessel(page, vessel) {
  return page.evaluate((payload) => window.Api.saveVessel({ vessel: payload }), vessel);
}

async function loadVessels(page) {
  const response = await page.evaluate(() => window.Api.getVessels({ limit: 100 }));
  expect(response && response.SUCCESS).toBe(true);
  return response.VESSELS || response.vessels || [];
}

async function loadVessel(page, vesselId) {
  const vessels = await loadVessels(page);
  const vessel = vessels.find((candidate) => Number(valueFrom(candidate, "VESSELID", "vesselId")) === Number(vesselId));
  expect(vessel).toBeTruthy();
  return vessel;
}

function requiredCore(vesselId, name = "Expanded Contract Vessel") {
  return {
    VESSELID: vesselId,
    VESSELNAME: name,
    REGISTRATION: "CF-2026-TEST",
    TYPE: "Power",
    LENGTH: "31",
    MAX_SPEED: "24",
    MOST_EFFICIENT_SPEED: "14",
    GALLONS_PER_HOUR: "8.5",
    GPH_AT_MAX_SPEED: "13",
    FUEL_CAPACITY: "210",
    ISDEFAULTVESSEL: 1,
    MAKE: "Codex",
    MODEL: "Contract",
    COLOR: "White",
    HOMEPORT: "Legacy Vessel Port"
  };
}

function expectTextField(vessel, key, expected) {
  expect(String(valueFrom(vessel, key))).toBe(expected);
}

async function expectRejectedCapacity(page, vesselId, key, value) {
  const outcome = await page.evaluate(async ({ payload, capacityKey, capacityValue }) => {
    payload[capacityKey] = capacityValue;
    try {
      const result = await window.Api.saveVessel({ vessel: payload });
      return { rejected: false, result };
    } catch (error) {
      return {
        rejected: true,
        message: String((error && (error.MESSAGE || error.message || error.DETAIL)) || "")
      };
    }
  }, {
    payload: requiredCore(vesselId),
    capacityKey: key,
    capacityValue: value
  });
  expect(outcome.rejected).toBe(true);
  expect(outcome.message.toLowerCase()).toContain("fuel capacity");
}

test.afterAll(async ({ request }) => {
  const response = await request.get(cleanupUrl);
  expect(response.status()).toBe(200);
  const payload = await response.json();
  expect(payload.SUCCESS).toBe(true);
  expect(payload.CLEANUP && payload.CLEANUP.SUCCESS).toBe(true);
});

test("existing-style vessel remains editable with every new field blank", async ({ page }) => {
  await createDisposableMember(page, "basic");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.locator('[data-quick-action="add-vessel"]').click();
  await expect(page.locator("#vesselModal")).toBeVisible();
  await expect(page.locator("#vesselForm legend")).toHaveText([
    "Vessel Basics",
    "Identification",
    "Communications",
    "Propulsion & Fuel",
    "Navigation",
    "Safety & Distress Equipment",
    "Anchor & Additional Gear",
    "Other Equipment"
  ]);
  await expect(page.locator("#vesselPrimaryFuelCapacity")).toHaveAccessibleName("Primary Fuel Capacity (gal)");
  await expect(page.locator("#vesselAuxFuelCapacity")).toHaveAccessibleName("Auxiliary Fuel Capacity (gal)");
  const modalOverflow = await page.locator("#vesselModal .modal-content").evaluate((element) => ({
    scrollWidth: element.scrollWidth,
    clientWidth: element.clientWidth
  }));
  expect(modalOverflow.scrollWidth).toBeLessThanOrEqual(modalOverflow.clientWidth);
  await page.locator("#vesselModal .btn-close").click();

  const created = await saveVessel(page, requiredCore(0, "Basic Compatibility Vessel"));
  expect(created && created.SUCCESS).toBe(true);
  const vesselId = Number(created.VESSELID);
  expect(vesselId).toBeGreaterThan(0);

  const vessel = await loadVessel(page, vesselId);
  for (const key of [
    "HIN", "YEARBUILT", "DRAFT", "HULLMATERIAL", "PROMINENTFEATURES",
    "CALLSIGNNUMBER", "DSCMMSI", "RADIO_1_TYPE", "RADIO_1_CHANNEL",
    "RADIO_2_TYPE", "RADIO_2_CHANNEL", "MOBILEPHONE", "SATTELITE",
    "PRIMARYPROPULSION", "PRIMARYPROPULSIONTYPE", "NUMBERPRIMARY",
    "PRIMARYFUELCAPACITY", "AUXPROPULSION", "AUXPROPULSIONTYPE", "NUMBERAUX",
    "AUXFUELCAPACITY", "NAVIGATION", "OTHERNAVIGATION", "VISUALDISTRESSSIGNALS",
    "AUDIBLEDISTRESSSIGNALS", "AEPIRB", "ANCHOR", "ANCHORLINELENGTH",
    "ADDITIONALGEAR", "OTHEREQUIPMENT", "OTHEREQUIPMENT_B", "OTHEREQUIPMENT_C",
    "OTHEREQUIPMENT_D"
  ]) {
    expect(String(valueFrom(vessel, key))).toBe("");
  }

  const edited = await saveVessel(page, requiredCore(vesselId, "Basic Compatibility Vessel Edited"));
  expect(edited && edited.SUCCESS).toBe(true);
  expectTextField(await loadVessel(page, vesselId), "VESSELNAME", "Basic Compatibility Vessel Edited");

  const deleted = await page.evaluate((id) => window.Api.deleteVessel(id), vesselId);
  expect(deleted && deleted.SUCCESS).toBe(true);
});

test("full optional vessel data round-trips, omitted fields survive updates, blanks clear, and invalid capacities reject", async ({ page }) => {
  await createDisposableMember(page, "full");

  const fullPayload = {
    ...requiredCore(0),
    HIN: "HIN-CODEX-2026",
    YEARBUILT: "2024",
    DRAFT: "3.5 ft",
    HULLMATERIAL: "Fiberglass",
    PROMINENTFEATURES: "Blue hardtop",
    CALLSIGNNUMBER: "WDCX26",
    DSCMMSI: "367123456",
    RADIO_1_TYPE: "VHF-FM",
    RADIO_1_CHANNEL: "16",
    RADIO_2_TYPE: "HF",
    RADIO_2_CHANNEL: "2182 kHz",
    MOBILEPHONE: "727-555-0101",
    SATTELITE: "+1-480-555-0102",
    PRIMARYPROPULSION: "Yamaha F300",
    PRIMARYPROPULSIONTYPE: "Gas OB",
    NUMBERPRIMARY: "2",
    PRIMARYFUELCAPACITY: "125",
    AUXPROPULSION: "Electric trolling motor",
    AUXPROPULSIONTYPE: "Electric OB",
    NUMBERAUX: "1",
    AUXFUELCAPACITY: "35.5",
    NAVIGATION: "compass,gps_dgps,depthSounder,other",
    OTHERNAVIGATION: "AIS transceiver",
    VISUALDISTRESSSIGNALS: "ElectricDistressLight,FlareAerial,SignalMirror",
    AUDIBLEDISTRESSSIGNALS: "Bell,Horn,Whistle",
    AEPIRB: "2DCC123456FFBFF",
    ANCHOR: 1,
    ANCHORLINELENGTH: "150",
    ADDITIONALGEAR: "DewateringDevice,FireExtinguisher,RaftDinghy",
    OTHEREQUIPMENT: "First aid kit",
    OTHEREQUIPMENT_B: "Tool kit",
    OTHEREQUIPMENT_C: "Spare propeller",
    OTHEREQUIPMENT_D: "Emergency blanket"
  };
  const created = await saveVessel(page, fullPayload);
  expect(created && created.SUCCESS).toBe(true);
  const vesselId = Number(created.VESSELID);
  expect(vesselId).toBeGreaterThan(0);

  let vessel = await loadVessel(page, vesselId);
  const expectedText = {
    HIN: fullPayload.HIN,
    YEARBUILT: fullPayload.YEARBUILT,
    DRAFT: fullPayload.DRAFT,
    HULLMATERIAL: fullPayload.HULLMATERIAL,
    PROMINENTFEATURES: fullPayload.PROMINENTFEATURES,
    CALLSIGNNUMBER: fullPayload.CALLSIGNNUMBER,
    DSCMMSI: fullPayload.DSCMMSI,
    RADIO_1_TYPE: fullPayload.RADIO_1_TYPE,
    RADIO_1_CHANNEL: fullPayload.RADIO_1_CHANNEL,
    RADIO_2_TYPE: fullPayload.RADIO_2_TYPE,
    RADIO_2_CHANNEL: fullPayload.RADIO_2_CHANNEL,
    MOBILEPHONE: fullPayload.MOBILEPHONE,
    SATTELITE: fullPayload.SATTELITE,
    PRIMARYPROPULSION: fullPayload.PRIMARYPROPULSION,
    PRIMARYPROPULSIONTYPE: fullPayload.PRIMARYPROPULSIONTYPE,
    NUMBERPRIMARY: fullPayload.NUMBERPRIMARY,
    AUXPROPULSION: fullPayload.AUXPROPULSION,
    AUXPROPULSIONTYPE: fullPayload.AUXPROPULSIONTYPE,
    NUMBERAUX: fullPayload.NUMBERAUX,
    NAVIGATION: fullPayload.NAVIGATION,
    OTHERNAVIGATION: fullPayload.OTHERNAVIGATION,
    VISUALDISTRESSSIGNALS: fullPayload.VISUALDISTRESSSIGNALS,
    AUDIBLEDISTRESSSIGNALS: fullPayload.AUDIBLEDISTRESSSIGNALS,
    AEPIRB: fullPayload.AEPIRB,
    ANCHOR: "1",
    ANCHORLINELENGTH: fullPayload.ANCHORLINELENGTH,
    ADDITIONALGEAR: fullPayload.ADDITIONALGEAR,
    OTHEREQUIPMENT: fullPayload.OTHEREQUIPMENT,
    OTHEREQUIPMENT_B: fullPayload.OTHEREQUIPMENT_B,
    OTHEREQUIPMENT_C: fullPayload.OTHEREQUIPMENT_C,
    OTHEREQUIPMENT_D: fullPayload.OTHEREQUIPMENT_D
  };
  for (const [key, expected] of Object.entries(expectedText)) {
    expectTextField(vessel, key, expected);
  }
  expect(Number(valueFrom(vessel, "PRIMARYFUELCAPACITY"))).toBe(125);
  expect(Number(valueFrom(vessel, "AUXFUELCAPACITY"))).toBe(35.5);
  expect(Number(valueFrom(vessel, "FUEL_CAPACITY"))).toBe(210);

  const partialUpdate = {
    ...requiredCore(vesselId, "Expanded Contract Vessel Updated"),
    PRIMARYPROPULSION: "Updated primary details"
  };
  const updated = await saveVessel(page, partialUpdate);
  expect(updated && updated.SUCCESS).toBe(true);
  vessel = await loadVessel(page, vesselId);
  expectTextField(vessel, "PRIMARYPROPULSION", "Updated primary details");
  expectTextField(vessel, "AUXPROPULSION", fullPayload.AUXPROPULSION);
  expectTextField(vessel, "NAVIGATION", fullPayload.NAVIGATION);
  expectTextField(vessel, "ADDITIONALGEAR", fullPayload.ADDITIONALGEAR);
  expect(Number(valueFrom(vessel, "AUXFUELCAPACITY"))).toBe(35.5);

  const cleared = await saveVessel(page, {
    ...requiredCore(vesselId, "Expanded Contract Vessel Updated"),
    PRIMARYPROPULSION: "",
    PRIMARYFUELCAPACITY: "",
    AUXFUELCAPACITY: "",
    OTHERNAVIGATION: ""
  });
  expect(cleared && cleared.SUCCESS).toBe(true);
  vessel = await loadVessel(page, vesselId);
  expectTextField(vessel, "PRIMARYPROPULSION", "");
  expectTextField(vessel, "PRIMARYFUELCAPACITY", "");
  expectTextField(vessel, "AUXFUELCAPACITY", "");
  expectTextField(vessel, "OTHERNAVIGATION", "");
  expectTextField(vessel, "AUXPROPULSION", fullPayload.AUXPROPULSION);

  await expectRejectedCapacity(page, vesselId, "PRIMARYFUELCAPACITY", "abc");
  await expectRejectedCapacity(page, vesselId, "PRIMARYFUELCAPACITY", "100 gallons");
  await expectRejectedCapacity(page, vesselId, "AUXFUELCAPACITY", "-1");
  await expectRejectedCapacity(page, vesselId, "AUXFUELCAPACITY", "35.555");
  vessel = await loadVessel(page, vesselId);
  expectTextField(vessel, "PRIMARYFUELCAPACITY", "");
  expectTextField(vessel, "AUXFUELCAPACITY", "");
  expect(Number(valueFrom(vessel, "FUEL_CAPACITY"))).toBe(210);

  const deleted = await page.evaluate((id) => window.Api.deleteVessel(id), vesselId);
  expect(deleted && deleted.SUCCESS).toBe(true);
});
