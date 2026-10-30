import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
const source = fs.readFileSync(new URL('../fpw_great_loop_clockwise/assets/js/cruise-timeline-page.js', import.meta.url), 'utf8');
function clock() {
  const context = { window: {}, document: {getElementById: () => null}, Date, Intl };
  vm.runInNewContext(source, context);
  return context.window.FPW.LoopDepartureClock;
}
const cases = [
  ['exact hour','2026-10-29T08:00:00-04:00','2026-10-29T12:00:00.000Z'],
  ['one minute later','2026-10-29T08:01:00-04:00','2026-10-29T13:00:00.000Z'],
  ['one second later','2026-10-29T08:00:01-04:00','2026-10-29T13:00:00.000Z'],
  ['one millisecond later','2026-10-29T08:00:00.001-04:00','2026-10-29T13:00:00.000Z'],
  ['11:59 PM','2026-10-29T23:59:00-04:00','2026-10-30T04:00:00.000Z'],
  ['midnight','2026-10-29T00:00:00-04:00','2026-10-29T04:00:00.000Z'],
  ['month end','2026-01-31T23:59:59-05:00','2026-02-01T05:00:00.000Z'],
  ['year end','2026-12-31T23:59:59-05:00','2027-01-01T05:00:00.000Z'],
  ['spring DST gap','2026-03-08T01:59:00-05:00','2026-03-08T07:00:00.000Z'],
  ['fall DST fold','2026-11-01T01:59:00-04:00','2026-11-01T06:00:00.000Z'],
  ['after fall fold','2026-11-01T01:01:00-05:00','2026-11-01T07:00:00.000Z']
];
for (const [name,input,expected] of cases) test('departure: '+name, () => {
  const previous = process.env.TZ; process.env.TZ = 'America/New_York';
  try { const original = new Date(input); const before = original.getTime(); const result = clock().round(original); assert.equal(result.toISOString(),expected); assert.equal(result.getMinutes(),0); assert.equal(original.getTime(),before); }
  finally { if(previous===undefined) delete process.env.TZ; else process.env.TZ=previous; }
});
test('departure: half-hour DST transition reaches the next whole local hour', () => {
  const previous=process.env.TZ; process.env.TZ='Australia/Lord_Howe';
  try { const result=clock().round(new Date('2026-04-05T01:59:00+11:00')); assert.equal(result.toISOString(),'2026-04-04T15:30:00.000Z'); assert.equal(clock().localValue(result),'2026-04-05T02:00'); }
  finally { if(previous===undefined) delete process.env.TZ; else process.env.TZ=previous; }
});
test('departure: invalid clock values are rejected',()=>assert.throws(()=>clock().round(new Date('invalid'))));
