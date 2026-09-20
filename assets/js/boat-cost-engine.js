/* FPW boat ownership model v1. USD inputs are decimal dollars; accounting uses cents.
 * P = price; D = down payment; Ff/Fc = financed/cash extras; L = P-D+Ff;
 * C0 = D+Fc; U = preparation; R0/Ra = initial/annual reserves; O = annual operations.
 * Amortization remains full precision. Derived monetary inputs round half-up once.
 * Summary displays round half-up. monthly.roundingAdjustment reconciles displayed
 * component rows to the rounded headline without altering the financial model.
 */
(function (root, factory) {
  'use strict';
  var api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.FPWBoatCost = api;
}(typeof window !== 'undefined' ? window : null, function () {
  'use strict';
  var VERSION = 1;
  var REFERENCE_YEAR = new Date().getUTCFullYear();
  var STATES = ['', 'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'DC', 'FL', 'GA', 'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD', 'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ', 'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC', 'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY'];
  var MAX_PRICE_CENTS = 500000000;
  var STATUSES = ['unknown', 'entered', 'illustrative', 'excluded'];
  var PREP_TYPES = ['survey', 'haulout', 'engineInspection', 'delivery', 'repairs', 'batteries', 'electronics', 'safety', 'bottom', 'trailer'];
  var FEE_TYPES = ['title', 'dealer', 'lender', 'other'];
  var OTHER_TYPES = ['utilities', 'pumpouts', 'trailer', 'towing', 'launch', 'subscriptions', 'other'];
  var LABELS = {fuel: 'Fuel', storage: 'Storage', insurance: 'Insurance', maintenance: 'Routine maintenance', registration: 'Registration and recurring taxes', seasonal: 'Seasonal services', other: 'Other operating costs', survey: 'Survey', haulout: 'Inspection haul-out', engineInspection: 'Engine inspection', delivery: 'Delivery', repairs: 'Immediate repairs', batteries: 'Batteries', electronics: 'Electronics', safety: 'Safety equipment', bottom: 'Initial bottom work', trailer: 'Trailer', title: 'Title/documentation fee', dealer: 'Dealer fee', lender: 'Lender fee'};
  var EXAMPLES = {
    H: {label: 'Illustrative $25,000 trailer-kept powerboat', price: 25000, down: 5000, term: 120, tax: 1500, fee: 300, hours: 80, gph: 6, storage: 1200, insurance: 600, maintenance: 900, registration: 150, seasonal: 0, initial: 2000, annual: 600, prep: {survey: 500, repairs: 500}},
    B: {label: 'Illustrative $50,000 slip-kept cruiser', price: 50000, down: 10000, term: 120, tax: 3000, fee: 500, hours: 100, gph: 8, storage: 3000, insurance: 1000, maintenance: 1500, registration: 250, seasonal: 250, initial: 2000, annual: 1200, prep: {survey: 600, haulout: 300, engineInspection: 300, safety: 300}},
    I: {label: 'Illustrative $100,000 larger cruiser', price: 100000, down: 20000, term: 180, tax: 6000, fee: 1000, hours: 100, gph: 20, storage: 9000, insurance: 2400, maintenance: 4000, registration: 400, seasonal: 1200, initial: 5000, annual: 3000, prep: {survey: 1200, haulout: 800, engineInspection: 1000, repairs: 2000}}
  };
  function field(value, status) { return {value: value === undefined ? '' : value, status: status || 'unknown'}; }
  function sale() { return {value: field(), selling: {mode: 'amount', input: field()}}; }
  function createScenario() {
    return {version: VERSION, label: '', direction: 'price', view: 'quick', origin: 'user',
      purchase: {method: 'financed', price: field(), down: {mode: 'amount', input: field()}, rate: field(), term: field(), tax: {mode: 'amount', input: field(), treatment: 'cash'}, fees: FEE_TYPES.map(function (type) { return {type: type, input: field(), treatment: 'cash'}; }), state: ''},
      budget: {monthly: field(), cash: field()},
      profile: {boatType: 'powerboat', condition: 'used', year: '', length: '', engineType: '', engineCount: '', water: '', season: ''},
      operating: {fuel: {mode: 'annual', annual: field(), hours: field(), gph: field(), price: field(), generator: {status: 'excluded', hours: field(), gph: field(), price: field()}}, storage: {mode: 'total', total: field(), rows: []}, insurance: field(), maintenance: field(), registration: field(), seasonal: field(), other: {mode: 'total', total: field(), rows: []}},
      preparation: {mode: 'total', total: field(), rows: PREP_TYPES.map(function (type) { return {type: type, input: field(), includedElsewhere: false}; })},
      reserves: {initial: field(), annual: field()}, resale: {five: sale(), ten: sale()}};
  }
  function cloneScenario(scenario) { return JSON.parse(JSON.stringify(scenario)); }
  function example(key) {
    var e = EXAMPLES[key];
    if (!e) throw new Error('Unknown example');
    var s = createScenario();
    var f = function (n) { return field(n, 'illustrative'); };
    s.label = e.label; s.origin = 'example';
    s.purchase.price = f(e.price); s.purchase.down.input = f(e.down); s.purchase.rate = f(8); s.purchase.term = f(e.term); s.purchase.tax.input = f(e.tax);
    s.purchase.fees.forEach(function (row, i) { row.input = i === 0 ? f(e.fee) : field('', 'excluded'); });
    s.operating.fuel.mode = 'usage'; s.operating.fuel.hours = f(e.hours); s.operating.fuel.gph = f(e.gph); s.operating.fuel.price = f(5);
    ['storage', 'insurance', 'maintenance', 'registration', 'seasonal'].forEach(function (key) { if (key === 'storage') s.operating.storage.total = f(e[key]); else s.operating[key] = e[key] === 0 ? field('', 'excluded') : f(e[key]); });
    s.operating.other.total.status = 'excluded';
    s.preparation.mode = 'details'; s.preparation.rows.forEach(function (row) { row.input = e.prep[row.type] === undefined ? field('', 'excluded') : f(e.prep[row.type]); });
    s.reserves.initial = f(e.initial); s.reserves.annual = f(e.annual);
    ['five', 'ten'].forEach(function (key) { s.resale[key].value.status = 'excluded'; s.resale[key].selling.input.status = 'excluded'; });
    return s;
  }
  function roundHalfUp(value) {
    if (!Number.isFinite(value)) throw new Error('Non-finite amount');
    var sign = value < 0 ? -1 : 1;
    var absolute = Math.abs(value);
    return sign * Math.floor(absolute + 0.5 + Number.EPSILON * Math.max(1, absolute) * 2);
  }
  function centsToDollars(cents) { return cents === null ? null : cents / 100; }
  function displayRound(value) { return value === null ? null : roundHalfUp(value * 100) / 100; }
  function parseNumber(raw, options) {
    options = options || {};
    if (raw === '') return {value: null, error: null};
    if (typeof raw !== 'string' && typeof raw !== 'number') return {value: null, error: 'Enter a valid number.'};
    if (typeof raw === 'number' && !Number.isFinite(raw)) return {value: null, error: 'Enter a finite number.'};
    var text = typeof raw === 'string' ? raw.trim() : String(raw);
    if (!text) return {value: null, error: null};
    if (options.money) {
      if (!/^\$?(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?$/.test(text)) return {value: null, error: 'Use a nonnegative dollar amount with up to two decimal places.'};
      text = text.replace(/^\$/, '').replace(/,/g, '');
    } else if (!/^(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$/.test(text)) {
      return {value: null, error: 'Enter a nonnegative number.'};
    }
    var number = Number(text);
    if (!Number.isFinite(number) || Math.abs(number) > Number.MAX_SAFE_INTEGER / 100) return {value: null, error: 'The number is too large.'};
    if (number < (options.min || 0) || (options.max !== undefined && number > options.max)) return {value: null, error: 'Enter a value from ' + (options.min || 0) + ' to ' + options.max + '.'};
    if (options.integer && !Number.isInteger(number)) return {value: null, error: 'Enter a whole number.'};
    return {value: number, error: null};
  }
  function parseMoney(raw, max) {
    var parsed = parseNumber(raw, {money: true, max: max === undefined ? 20000000 : max});
    return {value: parsed.value, cents: parsed.value === null ? null : roundHalfUp(parsed.value * 100), error: parsed.error};
  }
  function validateScenario(s, options) {
    options = options || {};
    var referenceYear = options.referenceYear === undefined ? REFERENCE_YEAR : options.referenceYear;
    var errors = [];
    function error(path, code, message) { errors.push({path: path, code: code, message: message}); }
    function object(value, keys, path) {
      if (!value || typeof value !== 'object' || Array.isArray(value) || (Object.getPrototypeOf(value) !== Object.prototype && Object.getPrototypeOf(value) !== null)) { error(path, 'shape', 'Invalid scenario object.'); return false; }
      var actual = Object.keys(value);
      actual.forEach(function (key) { if (keys.indexOf(key) < 0) error(path ? path + '.' + key : key, 'unknown-field', 'Unsupported scenario field.'); });
      keys.forEach(function (key) { if (!Object.prototype.hasOwnProperty.call(value, key)) error(path ? path + '.' + key : key, 'missing-field', 'Missing scenario field.'); });
      return keys.every(function (key) { return Object.prototype.hasOwnProperty.call(value, key); });
    }
    function enumeration(value, values, path) { if (values.indexOf(value) < 0) error(path, 'enum', 'Choose a supported option.'); }
    function text(value, max, path) { if (typeof value !== 'string' || value.length > max || /[<>\u0000-\u001f\u007f]/.test(value)) error(path, 'text', 'Use plain text up to ' + max + ' characters.'); }
    function number(value, options, path) { var parsed = parseNumber(value, options); if (parsed.error) error(path, 'number', parsed.error); return parsed.value; }
    function input(value, options, path, allowExcluded) {
      if (!object(value, ['value', 'status'], path)) return null;
      enumeration(value.status, STATUSES, path + '.status');
      if (allowExcluded === false && value.status === 'excluded') error(path + '.status', 'excluded-required', 'This assumption must be entered explicitly.');
      return number(value.value, options, path + '.value');
    }
    function money(value, max, path, allowExcluded) { return input(value, {money: true, max: max}, path, allowExcluded); }
    function list(value, min, max, path) { if (!Array.isArray(value) || value.length < min || value.length > max) { error(path, 'count', 'Invalid number of rows.'); return false; } return true; }
    function uniqueRows(rows, path) { var types = []; rows.forEach(function (row, i) { if (row && types.indexOf(row.type) >= 0) error(path + '.' + i + '.type', 'duplicate', 'A category can appear only once.'); if (row) types.push(row.type); }); }
    if (!object(s, ['version', 'label', 'direction', 'view', 'origin', 'purchase', 'budget', 'profile', 'operating', 'preparation', 'reserves', 'resale'], '')) return {valid: false, errors: errors};
    if (s.version !== VERSION) error('version', 'version', 'Unsupported scenario version.');
    text(s.label, 60, 'label'); enumeration(s.direction, ['price', 'budget'], 'direction'); enumeration(s.view, ['quick', 'detailed'], 'view'); enumeration(s.origin, ['user', 'example'], 'origin');
    var p = s.purchase;
    if (object(p, ['method', 'price', 'down', 'rate', 'term', 'tax', 'fees', 'state'], 'purchase')) {
      enumeration(p.method, ['financed', 'cash'], 'purchase.method'); money(p.price, 5000000, 'purchase.price', false);
      var price = p.price && parseMoney(p.price.value).value;
      if (price !== null && price < 1) error('purchase.price.value', 'range', 'Boat price must be at least $1.');
      if (object(p.down, ['mode', 'input'], 'purchase.down')) { enumeration(p.down.mode, ['amount', 'percent'], 'purchase.down.mode'); var down = input(p.down.input, {money: p.down.mode === 'amount', max: p.down.mode === 'amount' ? 5000000 : 100}, 'purchase.down.input', false); if (p.method === 'financed' && s.direction === 'price' && p.down.mode === 'amount' && price !== null && down !== null && down > price) error('purchase.down.input.value', 'down-payment', 'Down payment cannot exceed boat price.'); }
      input(p.rate, {max: 40}, 'purchase.rate', false); input(p.term, {min: 12, max: 240, integer: true}, 'purchase.term', false);
      if (object(p.tax, ['mode', 'input', 'treatment'], 'purchase.tax')) { enumeration(p.tax.mode, ['amount', 'percent'], 'purchase.tax.mode'); enumeration(p.tax.treatment, ['cash', 'financed'], 'purchase.tax.treatment'); input(p.tax.input, {money: p.tax.mode === 'amount', max: p.tax.mode === 'amount' ? 5000000 : 30}, 'purchase.tax.input'); }
      if (list(p.fees, 4, 4, 'purchase.fees')) { uniqueRows(p.fees, 'purchase.fees'); p.fees.forEach(function (row, i) { var path = 'purchase.fees.' + i; if (object(row, ['type', 'input', 'treatment'], path)) { enumeration(row.type, FEE_TYPES, path + '.type'); money(row.input, 5000000, path + '.input'); enumeration(row.treatment, ['cash', 'financed'], path + '.treatment'); } }); }
      enumeration(p.state, STATES, 'purchase.state');
    }
    if (object(s.budget, ['monthly', 'cash'], 'budget')) { money(s.budget.monthly, 1000000, 'budget.monthly', false); money(s.budget.cash, 20000000, 'budget.cash', false); }
    var profile = s.profile;
    if (object(profile, ['boatType', 'condition', 'year', 'length', 'engineType', 'engineCount', 'water', 'season'], 'profile')) {
      enumeration(profile.boatType, ['powerboat', 'fishing', 'pontoon', 'sailboat', 'trawler', 'pwc', 'other'], 'profile.boatType'); enumeration(profile.condition, ['new', 'used'], 'profile.condition'); number(profile.year, {min: 1900, max: referenceYear + 2, integer: true}, 'profile.year'); number(profile.length, {min: 1, max: 200}, 'profile.length'); number(profile.engineCount, {max: 6, integer: true}, 'profile.engineCount'); enumeration(profile.engineType, ['', 'outboard', 'sterndrive', 'gasInboard', 'dieselInboard', 'electricOther'], 'profile.engineType'); enumeration(profile.water, ['', 'fresh', 'salt', 'mixed'], 'profile.water'); enumeration(profile.season, ['', 'seasonal', 'yearRound'], 'profile.season');
    }
    var o = s.operating;
    if (object(o, ['fuel', 'storage', 'insurance', 'maintenance', 'registration', 'seasonal', 'other'], 'operating')) {
      if (object(o.fuel, ['mode', 'annual', 'hours', 'gph', 'price', 'generator'], 'operating.fuel')) {
        enumeration(o.fuel.mode, ['annual', 'usage'], 'operating.fuel.mode'); money(o.fuel.annual, 5000000, 'operating.fuel.annual'); input(o.fuel.hours, {max: 8760}, 'operating.fuel.hours'); input(o.fuel.gph, {max: 500}, 'operating.fuel.gph'); money(o.fuel.price, 50, 'operating.fuel.price');
        if (object(o.fuel.generator, ['status', 'hours', 'gph', 'price'], 'operating.fuel.generator')) { enumeration(o.fuel.generator.status, STATUSES, 'operating.fuel.generator.status'); input(o.fuel.generator.hours, {max: 8760}, 'operating.fuel.generator.hours'); input(o.fuel.generator.gph, {max: 500}, 'operating.fuel.generator.gph'); money(o.fuel.generator.price, 50, 'operating.fuel.generator.price'); }
      }
      if (object(o.storage, ['mode', 'total', 'rows'], 'operating.storage')) {
        enumeration(o.storage.mode, ['total', 'details'], 'operating.storage.mode'); money(o.storage.total, 5000000, 'operating.storage.total');
        if (list(o.storage.rows, 0, 4, 'operating.storage.rows')) o.storage.rows.forEach(function (row, i) { var path = 'operating.storage.rows.' + i; if (object(row, ['type', 'basis', 'input', 'months', 'billableFeet', 'startMonth'], path)) { enumeration(row.type, ['slip', 'dryStack', 'land', 'trailer'], path + '.type'); enumeration(row.basis, ['annual', 'monthly', 'perFoot'], path + '.basis'); money(row.input, 5000000, path + '.input'); number(row.months, {max: 12, integer: true}, path + '.months'); number(row.billableFeet, {min: 1, max: 200}, path + '.billableFeet'); number(row.startMonth, {min: 1, max: 12, integer: true}, path + '.startMonth'); } });
      }
      ['insurance', 'maintenance', 'registration', 'seasonal'].forEach(function (key) { money(o[key], 5000000, 'operating.' + key); });
      if (object(o.other, ['mode', 'total', 'rows'], 'operating.other')) { enumeration(o.other.mode, ['total', 'details'], 'operating.other.mode'); money(o.other.total, 5000000, 'operating.other.total'); if (list(o.other.rows, 0, 7, 'operating.other.rows')) { uniqueRows(o.other.rows, 'operating.other.rows'); o.other.rows.forEach(function (row, i) { var path = 'operating.other.rows.' + i; if (object(row, ['type', 'input'], path)) { enumeration(row.type, OTHER_TYPES, path + '.type'); money(row.input, 5000000, path + '.input'); } }); } }
    }
    if (object(s.preparation, ['mode', 'total', 'rows'], 'preparation')) { enumeration(s.preparation.mode, ['total', 'details'], 'preparation.mode'); money(s.preparation.total, 5000000, 'preparation.total'); if (list(s.preparation.rows, 10, 10, 'preparation.rows')) { uniqueRows(s.preparation.rows, 'preparation.rows'); s.preparation.rows.forEach(function (row, i) { var path = 'preparation.rows.' + i; if (object(row, ['type', 'input', 'includedElsewhere'], path)) { enumeration(row.type, PREP_TYPES, path + '.type'); money(row.input, 5000000, path + '.input'); if (typeof row.includedElsewhere !== 'boolean') error(path + '.includedElsewhere', 'boolean', 'Use a valid included-elsewhere flag.'); } }); } }
    if (object(s.reserves, ['initial', 'annual'], 'reserves')) { money(s.reserves.initial, 5000000, 'reserves.initial'); money(s.reserves.annual, 5000000, 'reserves.annual'); }
    if (object(s.resale, ['five', 'ten'], 'resale')) ['five', 'ten'].forEach(function (key) { var sale = s.resale[key]; var path = 'resale.' + key; if (object(sale, ['value', 'selling'], path)) { money(sale.value, 10000000, path + '.value'); if (object(sale.selling, ['mode', 'input'], path + '.selling')) { enumeration(sale.selling.mode, ['amount', 'percent'], path + '.selling.mode'); input(sale.selling.input, {money: sale.selling.mode === 'amount', max: sale.selling.mode === 'amount' ? 10000000 : 100}, path + '.selling.input'); } } });
    return {valid: errors.length === 0, errors: errors};
  }
  function loanSchedule(principal, annualRate, months) {
    if (!Number.isFinite(principal) || principal < 0) throw new Error('Invalid principal');
    if (principal === 0) return {principal: 0, payment: 0, totalPayments: 0, totalInterest: 0, schedule: [], annualSummaries: []};
    if (!Number.isFinite(annualRate) || annualRate < 0 || annualRate > 40 || !Number.isInteger(months) || months < 12 || months > 240) throw new Error('Invalid loan assumptions');
    var rate = annualRate / 1200;
    var payment = rate < 1e-8
      ? principal / months * (1 + (months + 1) * rate / 2 + (months * months - 1) * rate * rate / 12)
      : principal * (rate / -Math.expm1(-months * Math.log1p(rate)));
    var balance = principal;
    var schedule = [];
    var annual = [];
    var payments = 0;
    var interestSum = 0;
    for (var month = 1; month <= months; month += 1) {
      var interest = balance * rate;
      var actualPayment = month === months ? balance + interest : payment;
      var principalPart = actualPayment - interest;
      balance = month === months ? 0 : Math.max(0, balance - principalPart);
      payments += actualPayment; interestSum += interest;
      var row = {month: month, payment: actualPayment, principal: principalPart, interest: interest, balance: balance};
      schedule.push(row);
      var year = Math.floor((month - 1) / 12);
      if (!annual[year]) annual[year] = {year: year + 1, payment: 0, principal: 0, interest: 0, balance: 0};
      annual[year].payment += actualPayment; annual[year].principal += principalPart; annual[year].interest += interest; annual[year].balance = balance;
    }
    return {principal: principal, payment: payment, totalPayments: payments, totalInterest: interestSum, schedule: schedule, annualSummaries: annual};
  }
  function calculate(s, options) {
    options = options || {};
    var validation = validateScenario(s, options);
    var result = {valid: validation.valid, errors: validation.errors, warnings: [], missing: [], exclusions: [], illustrativePaths: [],
      readiness: {loan: false, operations: false, purchaseCash: false, preparation: false, reserves: false, monthly: false, firstYear: false, projection: false, resaleFive: false, resaleTen: false, complete: false},
      loan: {principal: null, payment: null, totalPayments: null, totalInterest: null, schedule: [], annualSummaries: []},
      operations: {annual: null, monthly: null, knownAnnual: 0, breakdown: []},
      monthly: {expectedExpenses: null, repairSavings: null, budget: null, knownCosts: 0, roundingAdjustment: 0, label: 'Known monthly costs so far'},
      upfront: {purchaseCash: null, preparation: null, initialReserve: null, planningCash: null},
      firstYear: {loanPayments: null, spending: null, funding: null}, horizons: {five: null, ten: null}, insights: [], accounting: {P: null, D: null, Ff: null, Fc: null, L: null, C0: null, U: null, R0: null, Ra: null, O: null}};
    if (!validation.valid) return result;
    function missing(path, label) { result.missing.push({path: path, message: 'Review ' + label + '.'}); }
    function read(f, path, label, money, optional) {
      if (f.status === 'excluded') { if (!optional) result.exclusions.push({path: path, label: label}); return {value: 0, ready: true, status: 'excluded'}; }
      if (f.status === 'unknown' || f.value === '' || (typeof f.value === 'string' && !f.value.trim())) { if (!optional) missing(path, label); return {value: null, ready: false, status: 'unknown'}; }
      if (f.status === 'illustrative') result.illustrativePaths.push(path);
      return {value: money ? parseMoney(f.value, 10000000).cents : parseNumber(f.value).value, ready: true, status: f.status};
    }
    function m(f, path, label, optional) { return read(f, path, label, true, optional); }
    function n(f, path, label, optional) { return read(f, path, label, false, optional); }
    function group(parts) { return {value: parts.reduce(function (sum, part) { return sum + (part.value || 0); }, 0), ready: parts.every(function (part) { return part.ready; }), status: parts.some(function (part) { return !part.ready; }) ? 'unknown' : parts.some(function (part) { return part.status === 'illustrative'; }) ? 'illustrative' : parts.every(function (part) { return part.status === 'excluded'; }) ? 'excluded' : 'entered'}; }
    var p = s.purchase;
    var price = m(p.price, 'purchase.price', 'boat price');
    var down = p.method === 'cash' ? price : read(p.down.input, 'purchase.down.input', 'down payment', p.down.mode === 'amount');
    if (p.method !== 'cash' && p.down.mode === 'percent' && down.ready) down = {value: price.ready ? roundHalfUp(price.value * down.value / 100) : null, ready: price.ready, status: down.status};
    var tax = read(p.tax.input, 'purchase.tax.input', 'purchase tax', p.tax.mode === 'amount');
    if (p.tax.mode === 'percent' && tax.ready) tax = {value: price.ready ? roundHalfUp(price.value * tax.value / 100) : null, ready: price.ready, status: tax.status};
    var cashExtras = [], financedExtras = [];
    (p.method !== 'cash' && p.tax.treatment === 'financed' ? financedExtras : cashExtras).push(tax);
    p.fees.forEach(function (row, i) { var extra = m(row.input, 'purchase.fees.' + i + '.input', row.type === 'other' ? 'Other purchase fee' : LABELS[row.type]); (p.method !== 'cash' && row.treatment === 'financed' ? financedExtras : cashExtras).push(extra); });
    var fc = group(cashExtras), ff = group(financedExtras);
    var principalReady = p.method === 'cash' || (price.ready && down.ready && ff.ready);
    var principal = principalReady ? p.method === 'cash' ? 0 : price.value - down.value + ff.value : null;
    if (principal !== null && principal < 0) { result.valid = false; result.errors.push({path: 'purchase.down.input', code: 'down-payment', message: 'Down payment cannot exceed boat price.'}); return result; }
    var rate, term;
    if (principalReady && principal === 0) { result.loan = loanSchedule(0, 0, 0); result.readiness.loan = true; }
    else if (principalReady) {
      rate = n(p.rate, 'purchase.rate', 'annual contract interest rate'); term = n(p.term, 'purchase.term', 'loan term');
      if (rate.ready && term.ready) { result.loan = loanSchedule(principal / 100, rate.value, term.value); result.readiness.loan = true; }
      else result.loan.principal = principal / 100;
    }
    result.accounting.P = price.ready ? price.value / 100 : null; result.accounting.D = down.ready ? down.value / 100 : null; result.accounting.Ff = ff.ready ? ff.value / 100 : null; result.accounting.Fc = fc.ready ? fc.value / 100 : null; result.accounting.L = principal === null ? null : principal / 100;
    result.readiness.purchaseCash = down.ready && fc.ready;
    if (result.readiness.purchaseCash) result.upfront.purchaseCash = (down.value + fc.value) / 100;
    result.accounting.C0 = result.upfront.purchaseCash;
    function useFuel(fuel, path, label, explicitStatus) {
      if (explicitStatus === 'excluded') { result.exclusions.push({path: path, label: label}); return {value: 0, ready: true, status: 'excluded'}; }
      if (explicitStatus === 'unknown') { missing(path, label); return {value: null, ready: false, status: 'unknown'}; }
      if (explicitStatus === 'illustrative') result.illustrativePaths.push(path);
      var hours = n(fuel.hours, path + '.hours', label + ' annual hours');
      if (hours.ready && hours.value === 0) return {value: 0, ready: true, status: explicitStatus === 'illustrative' ? 'illustrative' : hours.status};
      var gph = n(fuel.gph, path + '.gph', label + ' total GPH');
      var fuelPrice = m(fuel.price, path + '.price', label + ' price per gallon');
      var combined = group([hours, gph, fuelPrice]);
      var fuelCents = combined.ready ? roundHalfUp(hours.value * gph.value * fuelPrice.value) : null;
      if (fuelCents !== null && fuelCents > 500000000) { result.valid = false; result.errors.push({path: path + '.hours', code: 'annual-cost-limit', message: 'Annual ' + label + ' cost cannot exceed $5,000,000.'}); }
      return {value: fuelCents, ready: combined.ready, status: combined.ready && explicitStatus === 'illustrative' ? 'illustrative' : combined.status};
    }
    var o = s.operating;
    var fuel = o.fuel.mode === 'annual' ? m(o.fuel.annual, 'operating.fuel.annual', 'annual fuel budget') : group([useFuel(o.fuel, 'operating.fuel', 'propulsion fuel'), useFuel(o.fuel.generator, 'operating.fuel.generator', 'generator fuel', o.fuel.generator.status)]);
    function storageCosts() {
      if (o.storage.mode === 'total') return m(o.storage.total, 'operating.storage.total', 'annual storage');
      if (!o.storage.rows.length) { missing('operating.storage.rows', 'storage rows or an explicit exclusion'); return {value: 0, ready: false, status: 'unknown'}; }
      var occupancy = [];
      var rows = o.storage.rows.map(function (row, i) {
        var path = 'operating.storage.rows.' + i;
        var base = m(row.input, path + '.input', row.type + ' storage');
        if (base.status === 'excluded') return base;
        var months = row.basis === 'annual' ? 12 : parseNumber(row.months).value;
        var feet = row.basis === 'perFoot' ? parseNumber(row.billableFeet).value : 1;
        if (months === null) { missing(path + '.months', 'paid storage months'); base.ready = false; }
        if (feet === null) { missing(path + '.billableFeet', 'billable storage length'); base.ready = false; }
        if (row.basis === 'perFoot' && s.profile.length === '') { missing('profile.length', 'physical boat length for per-foot storage'); base.ready = false; }
        var value = base.ready ? roundHalfUp(base.value * (row.basis === 'annual' ? 1 : months) * feet) : null;
        if (value !== null && value > 500000000) { result.valid = false; result.errors.push({path: path + '.input', code: 'annual-cost-limit', message: 'Annual storage per row cannot exceed $5,000,000.'}); }
        var start = parseNumber(row.startMonth).value;
        if (base.ready && value > 0) { var used = []; if (months === 12) for (var j = 1; j <= 12; j += 1) used.push(j); else if (start !== null) for (var k = 0; k < months; k += 1) used.push(((start - 1 + k) % 12) + 1); occupancy.push(used); }
        return {value: value, ready: base.ready, status: base.status};
      });
      var overlap = occupancy.some(function (months, i) { return occupancy.some(function (other, j) { return j > i && months.some(function (month) { return other.indexOf(month) >= 0; }); }); });
      if (overlap) result.warnings.push({code: 'storage-overlap', message: 'Storage charges overlap. Confirm that each contract or seasonal charge is intentional.'});
      else if (occupancy.length > 1 && occupancy.some(function (months) { return !months.length; })) result.warnings.push({code: 'storage-periods', message: 'Review storage periods for overlapping charges; start months are optional.'});
      return group(rows);
    }
    var storage = storageCosts();
    function otherCosts() {
      if (o.other.mode === 'total') return m(o.other.total, 'operating.other.total', 'other operating costs');
      var rows = OTHER_TYPES.map(function (type) { var index = o.other.rows.findIndex(function (row) { return row.type === type; }); if (index < 0) { missing('operating.other.rows', type + ' operating costs'); return {value: 0, ready: false, status: 'unknown'}; } return m(o.other.rows[index].input, 'operating.other.rows.' + index + '.input', type + ' operating costs'); });
      return group(rows);
    }
    var costs = {fuel: fuel, storage: storage, insurance: m(o.insurance, 'operating.insurance', 'insurance'), maintenance: m(o.maintenance, 'operating.maintenance', 'routine maintenance'), registration: m(o.registration, 'operating.registration', 'registration and recurring taxes'), seasonal: m(o.seasonal, 'operating.seasonal', 'seasonal services'), other: otherCosts()};
    var operations = group(Object.keys(costs).map(function (key) { var item = costs[key]; result.operations.breakdown.push({key: key, label: LABELS[key], annual: item.ready ? item.value / 100 : null, knownAnnual: (item.value || 0) / 100, monthly: item.ready ? item.value / 1200 : null, status: item.status, basis: key === 'fuel' ? o.fuel.mode === 'usage' ? 'Hours × total GPH × fuel price; generator separate' : 'Direct annual fuel budget' : key === 'storage' && o.storage.mode === 'details' ? 'Sum of annualized storage rows' : 'Annual amount'}); return item; }));
    result.operations.knownAnnual = operations.value / 100;
    result.readiness.operations = operations.ready;
    if (operations.ready) { result.operations.annual = operations.value / 100; result.operations.monthly = operations.value / 1200; result.accounting.O = operations.value / 100; }
    var prep = s.preparation.mode === 'total' ? m(s.preparation.total, 'preparation.total', 'other initial and first-year costs') : group(s.preparation.rows.map(function (row, i) { if (row.includedElsewhere) { result.exclusions.push({path: 'preparation.rows.' + i, label: LABELS[row.type] + ' — already included elsewhere'}); return {value: 0, ready: true, status: 'excluded'}; } return m(row.input, 'preparation.rows.' + i + '.input', LABELS[row.type]); }));
    var r0 = m(s.reserves.initial, 'reserves.initial', 'initial repair reserve'); var ra = m(s.reserves.annual, 'reserves.annual', 'annual repair savings');
    result.readiness.preparation = prep.ready; result.readiness.reserves = r0.ready && ra.ready;
    result.upfront.preparation = prep.ready ? prep.value / 100 : null; result.upfront.initialReserve = r0.ready ? r0.value / 100 : null;
    if (result.readiness.purchaseCash && prep.ready && r0.ready) result.upfront.planningCash = (down.value + fc.value + prep.value + r0.value) / 100;
    result.accounting.U = result.upfront.preparation; result.accounting.R0 = result.upfront.initialReserve; result.accounting.Ra = ra.ready ? ra.value / 100 : null;
    result.monthly.knownCosts = (result.readiness.loan ? result.loan.payment : 0) + (operations.value + (ra.ready ? ra.value : 0)) / 1200;
    var displayedComponentCents = result.operations.breakdown.reduce(function (sum, row) { return sum + roundHalfUp(row.knownAnnual / 12 * 100); }, 0) + (result.readiness.loan ? roundHalfUp(result.loan.payment * 100) : 0) + (ra.ready ? roundHalfUp(ra.value / 12) : 0);
    result.monthly.roundingAdjustment = (roundHalfUp(result.monthly.knownCosts * 100) - displayedComponentCents) / 100;
    if (result.readiness.loan && operations.ready) result.monthly.expectedExpenses = result.loan.payment + operations.value / 1200;
    if (ra.ready) result.monthly.repairSavings = ra.value / 1200;
    result.readiness.monthly = result.readiness.loan && operations.ready && ra.ready;
    if (result.readiness.monthly) { result.monthly.budget = result.loan.payment + (operations.value + ra.value) / 1200; result.monthly.label = 'Estimated monthly boating budget'; }
    function paidThrough(months) { return result.loan.schedule.slice(0, months).reduce(function (sum, row) { return sum + row.payment; }, 0); }
    result.firstYear.loanPayments = result.readiness.loan ? paidThrough(12) : null;
    var spendingReady = result.readiness.loan && operations.ready && result.readiness.purchaseCash && prep.ready;
    if (spendingReady) result.firstYear.spending = result.upfront.purchaseCash + prep.value / 100 + result.firstYear.loanPayments + operations.value / 100;
    result.readiness.firstYear = spendingReady && r0.ready && ra.ready;
    if (result.readiness.firstYear) result.firstYear.funding = result.firstYear.spending + (r0.value + ra.value) / 100;
    result.readiness.projection = result.readiness.firstYear;
    ['five', 'ten'].forEach(function (key) {
      var years = key === 'five' ? 5 : 10;
      var balanceRow = result.loan.schedule[Math.min(years * 12, result.loan.schedule.length) - 1];
      var sale = s.resale[key]; var saleValue = m(sale.value, 'resale.' + key + '.value', years + '-year resale value', true);
      var selling = read(sale.selling.input, 'resale.' + key + '.selling.input', years + '-year selling costs', sale.selling.mode === 'amount', true);
      var explicitResale = saleValue.ready && sale.value.status !== 'excluded';
      var explicitSelling = selling.ready && sale.selling.input.status !== 'excluded';
      if (explicitResale && !explicitSelling) missing('resale.' + key + '.selling.input', years + '-year selling costs, including an explicit zero');
      var sellCents = explicitResale && explicitSelling ? sale.selling.mode === 'percent' ? roundHalfUp(saleValue.value * selling.value / 100) : selling.value : null;
      var horizon = {years: years, cashSpent: spendingReady ? result.upfront.purchaseCash + prep.value / 100 + paidThrough(years * 12) + years * operations.value / 100 : null, reserveAllocations: r0.ready && ra.ready ? (r0.value + years * ra.value) / 100 : null, loanBalance: result.readiness.loan ? balanceRow ? balanceRow.balance : 0 : null, netOwnershipCost: null, resaleValue: explicitResale ? saleValue.value / 100 : null, sellingCosts: sellCents === null ? null : sellCents / 100};
      if (spendingReady && explicitResale && explicitSelling) { horizon.netOwnershipCost = horizon.cashSpent + horizon.loanBalance + sellCents / 100 - saleValue.value / 100; result.readiness[key === 'five' ? 'resaleFive' : 'resaleTen'] = true; if (horizon.netOwnershipCost < 0) result.warnings.push({code: 'negative-net-cost', message: years + '-year resale assumptions produce a negative net cost. This is a speculative assumption, not a guarantee of profit.'}); }
      result.horizons[key] = horizon;
    });
    result.readiness.complete = result.readiness.monthly && result.readiness.firstYear && result.valid;
    if (!options.skipInsights) {
      if (s.profile.condition === 'used' && (!prep.ready || (r0.ready && ra.ready && r0.value === 0 && ra.value === 0))) result.warnings.push({code: 'used-boat', message: !prep.ready ? 'Review the used-boat preparation checklist, including survey, inspection, and known catch-up work.' : 'No repair savings are allocated. Review liquidity for unplanned work; this model does not recommend a reserve amount.'});
      if (result.readiness.loan && result.loan.principal > 0) {
        var termRate = parseNumber(p.rate.value).value;
        result.insights.push({type: 'terms', text: 'Compare the same principal and assumed rate over 10, 15, and 20 years. Actual lender rates and eligibility may differ by term and vessel.', terms: [120, 180, 240].map(function (months) { var loan = loanSchedule(result.loan.principal, termRate, months); return {months: months, payment: loan.payment, totalInterest: loan.totalInterest, paymentDifference: loan.payment - result.loan.payment, interestDifference: loan.totalInterest - result.loan.totalInterest}; })});
      }
      if (result.readiness.monthly && operations.ready) {
        var expectedAnnual = result.loan.payment * 12 + operations.value / 100;
        var categories = result.operations.breakdown.map(function (row) { return {key: row.key, label: row.label, annual: row.annual}; }); categories.push({key: 'loan', label: 'Loan payments while active', annual: result.loan.payment * 12});
        categories.sort(function (a, b) { return b.annual - a.annual; });
        if (expectedAnnual > 0) result.insights.push({type: 'largest', text: categories[0].label + ' is the largest recurring expense. The share uses annual expected expenses including the active loan and excluding repair savings.', category: categories[0].label, annual: categories[0].annual, share: categories[0].annual / expectedAnnual, denominator: expectedAnnual});
        if (fuel.ready && result.insights.length < 3) result.insights.push({type: 'fuel', text: o.fuel.mode === 'annual' ? 'A 25% increase in the annual fuel budget, holding other assumptions fixed.' : 'A 25% increase in fuel prices, holding propulsion and generator use fixed.', monthlyIncrease: roundHalfUp(fuel.value * 1.25) / 1200 - fuel.value / 1200, annualIncrease: (roundHalfUp(fuel.value * 1.25) - fuel.value) / 100});
      }
      result.insights = result.insights.slice(0, 3);
    }
    return result;
  }
  function solveBudget(s) {
    var validation = validateScenario(s);
    var output = {status: 'invalid', errors: validation.errors, missing: [], reason: '', monthlyShortfall: null, cashShortfall: null, price: null, scenario: null, result: null, monthlyHeadroom: null, cashHeadroom: null, nextCentFails: null};
    if (!validation.valid) return output;
    function known(f) { return (f.status === 'entered' || f.status === 'illustrative') && f.value !== ''; }
    if (!known(s.budget.monthly)) output.missing.push({path: 'budget.monthly', message: 'Enter a monthly boating budget.'});
    if (!known(s.budget.cash)) output.missing.push({path: 'budget.cash', message: 'Enter available upfront cash.'});
    if (output.missing.length) { output.status = 'incomplete'; return output; }
    var b = parseMoney(s.budget.monthly.value, 1000000).value;
    var a = parseMoney(s.budget.cash.value, 20000000).value;
    var base = cloneScenario(s); base.direction = 'price';
    var minimum = 100;
    if (s.purchase.method === 'financed' && s.purchase.down.mode === 'amount' && known(s.purchase.down.input)) minimum = Math.max(100, parseMoney(s.purchase.down.input.value).cents);
    function candidate(cents) { var test = cloneScenario(base); test.purchase.price = field(cents / 100, 'entered'); return {scenario: test, result: calculate(test, {skipInsights: true})}; }
    var first = candidate(minimum);
    if (!first.result.valid) { output.errors = first.result.errors; return output; }
    if (!first.result.readiness.complete) { output.status = 'incomplete'; output.missing = first.result.missing; output.result = first.result; return output; }
    var baseline = first.result.operations.monthly + first.result.monthly.repairSavings;
    if (baseline > b) { output.status = 'no-feasible'; output.reason = 'Operating costs and repair savings exceed the monthly budget.'; output.monthlyShortfall = baseline - b; return output; }
    if (first.result.upfront.planningCash > a) { output.status = 'no-feasible'; output.reason = 'Available upfront cash cannot fund the lowest valid boat price with these assumptions.'; output.cashShortfall = first.result.upfront.planningCash - a; return output; }
    if (first.result.monthly.budget > b) { output.status = 'no-feasible'; output.reason = 'The lowest valid price exceeds the monthly budget.'; output.monthlyShortfall = first.result.monthly.budget - b; return output; }
    function feasible(value) { return value.result.valid && value.result.readiness.complete && value.result.monthly.budget <= b && value.result.upfront.planningCash <= a; }
    var low = minimum, high = MAX_PRICE_CENTS;
    var max = candidate(high);
    if (!max.result.valid) { output.errors = max.result.errors; return output; }
    if (!max.result.readiness.complete) { output.status = 'incomplete'; output.missing = max.result.missing; output.result = max.result; return output; }
    var atMaximum = feasible(max);
    if (atMaximum) low = high;
    else while (low < high) { var mid = Math.floor((low + high + 1) / 2); if (feasible(candidate(mid))) low = mid; else high = mid - 1; }
    var final = candidate(low); final.result = calculate(final.scenario);
    if (!feasible(final)) { output.status = 'invalid'; output.reason = 'Budget solution failed forward validation.'; return output; }
    output.status = atMaximum ? 'maximum' : 'solved'; output.reason = atMaximum ? 'At least the supported maximum under these assumptions.' : 'Boat price that fits these assumptions'; output.price = low / 100; output.scenario = final.scenario; output.result = final.result; output.monthlyHeadroom = b - final.result.monthly.budget; output.cashHeadroom = a - final.result.upfront.planningCash; output.nextCentFails = low === MAX_PRICE_CENTS ? null : !feasible(candidate(low + 1));
    return output;
  }
  return {VERSION: VERSION, CONFIG_VERSION: '2026-09-19.v1', REFERENCE_YEAR: REFERENCE_YEAR, STATES: STATES.slice(), STATUSES: STATUSES.slice(), PREP_TYPES: PREP_TYPES.slice(), OTHER_TYPES: OTHER_TYPES.slice(), createScenario: createScenario, field: field, example: example, cloneScenario: cloneScenario, validateScenario: validateScenario, calculate: calculate, solveBudget: solveBudget, loanSchedule: loanSchedule, parseMoney: parseMoney, parseNumber: parseNumber, roundHalfUp: roundHalfUp, displayRound: displayRound};
}));
