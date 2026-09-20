/* Boat ownership calculator UI. All displayed values use safe DOM text operations. */
(function () {
  'use strict';
  var E = window.FPWBoatCost, S = window.FPWBoatCostState;
  var mount = document.getElementById('boat-cost-app');
  if (!mount || !E || !S) return;
  var scenarios = [E.createScenario()], active = 0, baseline = 0, records = [], edited = [false];
  var started = false, timer = null, compareOpen = false, message = '', errorNodes = {};
  var money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
  var labels = { title:'Title / documentation fee', dealer:'Dealer fee', lender:'Lender fee', other:'Other', survey:'Survey', haulout:'Inspection haul-out', engineInspection:'Engine inspection', delivery:'Delivery', repairs:'Known immediate repairs', batteries:'Batteries', electronics:'Electronics', safety:'Safety equipment', bottom:'Initial bottom work', trailer:'Trailer', utilities:'Marina electricity / water', pumpouts:'Pump-outs', towing:'Towing fuel', launch:'Launch fees', subscriptions:'Subscriptions' };
  var disclaimer = 'Planning estimate, not a loan, insurance, tax, or repair quote. Results depend on the assumptions shown. Actual costs and lender terms may differ. Repair savings are money set aside, not a prediction of repair bills. Confirm costs with lenders, insurers, marinas, tax authorities, and qualified marine professionals before buying.';
  mount.classList.add('boat-cost');
  function node(tag, text, attrs) { var n = document.createElement(tag); if (text !== undefined && text !== null) n.textContent = text; Object.keys(attrs || {}).forEach(function (k) { n.setAttribute(k, attrs[k]); }); return n; }
  function clear(n) { while (n.firstChild) n.removeChild(n.firstChild); }
  function append(parent) { Array.prototype.slice.call(arguments, 1).forEach(function (c) { if (c) parent.appendChild(c); }); return parent; }
  function button(text, fn, cls) { var b = node('button', text, {type:'button'}); if (cls) b.className = cls; b.addEventListener('click', fn); return b; }
  function para(text, cls) { var p = node('p', text); if (cls) p.className = cls; return p; }
  function fmt(v) { return typeof v === 'number' && Number.isFinite(v) ? money.format(v) : 'Incomplete'; }
  function delta(v, b) { return typeof v === 'number' && typeof b === 'number' ? (v >= b ? '+' : '−') + fmt(Math.abs(v - b)) : 'Incomplete'; }
  function get(path, source) { return path.split('.').reduce(function (o, k) { return o[k]; }, source || scenarios[active]); }
  function set(path, value) { var parts = path.split('.'), last = parts.pop(); var obj = parts.reduce(function (o, k) { return o[k]; }, scenarios[active]); obj[last] = value; }
  function id(path) { return 'bc-' + path.replace(/\./g, '-'); }
  function announce(text) { message = text; if (live) live.textContent = text; }
  function meta(extra) { var s = scenarios[active], rec = records[active]; return Object.assign({direction:s.direction,view:s.view,purchase_mode:s.purchase.method,completeness:rec && rec.result && rec.result.readiness.complete ? 'complete' : 'partial',origin:s.origin,scenario_count:scenarios.length}, extra || {}); }
  function track(event, extra) { S.track(event, meta(extra)); }
  function touched() { edited[active] = true; scenarios[active].origin = 'user'; if (!started) { started = true; track('boat_cost_start'); } if (records[active]) records[active].stale = true; clearTimeout(timer); renderResults(); timer = setTimeout(function () { if (records[active]) calculate(false); }, 300); }
  function mutate(fn, rerender) { fn(); touched(); if (rerender) renderForm(); }
  function options(parent, items, value) { items.forEach(function (item) { var pair = Array.isArray(item) ? item : [item,item]; var option = node('option', pair[1], {value:pair[0]}); option.selected = String(value) === pair[0]; parent.appendChild(option); }); }
  function selectField(path, label, items, help, after) { var box = node('div', null, {class:'bc-field'}), select = node('select', null, {id:id(path)}); options(select, items, get(path)); select.addEventListener('change', function () {
      var previous = get(path), next = select.value;
      if (path === 'view') { set(path,next); renderForm(); return; }
      var replacing = /(?:purchase\.(?:down|tax)|resale\.(?:five|ten)\.selling)\.mode$/.test(path) || /^operating\.storage\.rows\.\d+\.basis$/.test(path);
      var inputPath = path.replace(/\.(mode|basis)$/,'.input');
      if (replacing && get(inputPath).value !== '') {
        if (!window.confirm('Changing this basis clears the amount so it cannot be interpreted in different units. Continue?')) { select.value = previous; return; }
      }
      mutate(function () { set(path,next); if (replacing) set(inputPath,{value:'',status:'unknown'}); if (after) after(next); },true);
      var replacement = document.getElementById(id(path)); if (replacement) replacement.focus();
    }); append(box,node('label', label, {for:id(path)}),select); if (help) box.appendChild(para(help,'bc-help')); errorNodes[path] = select; return box; }
  function textField(path, label, help, maxLength) { var box = node('div', null, {class:'bc-field'}), input = node('input', null, {id:id(path),type:'text',autocomplete:'off'}); input.value = get(path); if (maxLength) input.maxLength = maxLength; input.addEventListener('input', function () { set(path,input.value); if (path === 'label') { edited[active] = true; renderToolbar(); renderResults(); } else touched(); }); append(box,node('label',label,{for:id(path)}),input); if (help) box.appendChild(para(help,'bc-help')); errorNodes[path] = input; return box; }
  function numberField(path, label, help, allowExcluded) {
    var field = get(path), box = node('div', null, {class:'bc-cost'}), controls = node('div',null,{class:allowExcluded ? 'bc-cost-controls' : 'bc-field'});

    var inputBox = node('div',null,{class:'bc-field'}), input = node('input',null,{id:id(path),type:'text',inputmode:'decimal',autocomplete:'off'});
    input.value = field.value === null || field.value === undefined ? '' : field.value;
    input.disabled = field.status === 'excluded'; input.setAttribute('aria-describedby',id(path) + '-help');
    append(inputBox,node('label', label,{for:id(path)}),input);
    input.addEventListener('input',function () { field.value = input.value; field.status = input.value.trim() ? 'entered' : 'unknown'; if (status) status.value = field.status; touched(); });
    controls.appendChild(inputBox); var status;
    if (allowExcluded) { var statusBox = node('div',null,{class:'bc-field'}); status = node('select',null,{id:id(path)+ '-status','aria-label':label+' status'}); options(status,[['unknown','Not reviewed'],['entered','Entered'],['illustrative','Illustrative'],['excluded','Excluded']],field.status); status.addEventListener('change',function () { field.status = status.value; input.disabled = field.status === 'excluded'; touched(); }); append(statusBox,node('label','Status',{for:id(path)+'-status'}),status); controls.appendChild(statusBox); }
    box.appendChild(controls); box.appendChild(para(help || 'USD. A blank is unknown. Enter 0 deliberately or explicitly exclude this item.','bc-help')); box.lastChild.id = id(path)+'-help'; errorNodes[path] = input; errorNodes[path+'.value'] = input; return box;
  }
  function section(title) { var f = node('fieldset'); f.appendChild(node('legend',title)); return f; }
  function grouped(parent, children) { var grid = node('div',null,{class:'bc-fields'}); children.forEach(function(c) { grid.appendChild(c); }); parent.appendChild(grid); }
  function cost(path,label,help) { return numberField(path,label,help,true); }
  function link(text,url,destination) { var a = node('a',text,{href:url}); a.addEventListener('click',function () { track('boat_cost_cta',{destination:destination}); }); return a; }
  function actionError(code, text) { track('boat_cost_error',{error_code:code}); announce(text); }
  var toolbar = node('div',null,{class:'bc-toolbar'}), live = node('p','',{class:'bc-live',role:'status','aria-live':'polite','aria-atomic':'true'});
  var grid = node('div',null,{class:'bc-grid'}), formPanel = node('div',null,{class:'bc-panel'}), form = node('form',null,{class:'bc-form',novalidate:'novalidate'}), results = node('section',null,{id:'bc-results','aria-label':'Calculator results'}), comparison = node('section',null,{class:'bc-panel bc-comparison','aria-label':'Scenario comparison'});
  form.addEventListener('submit',function (event) { event.preventDefault(); calculate(true); }); formPanel.appendChild(form); append(grid,formPanel,results); append(mount,toolbar,live,grid,comparison);
  // Native sticky handles scrolling; only size changes need measurement.
  var stickyPanel = null;
  var stickyFrame = 0;
  var stickyInset = '';
  var stickyHeader = document.querySelector('[data-fpw-nav]');
  var singleColumn = window.matchMedia('(max-width: 950px)');
  var stickyObserver = typeof window.ResizeObserver === 'function'
    ? new window.ResizeObserver(scheduleStickyMeasurement) : null;

  function scheduleStickyMeasurement() {
    if (!stickyFrame) stickyFrame = window.requestAnimationFrame(measureStickyPanel);
  }

  function stickyHeaderBottom() {
    var headerBottom = 0;
    if (stickyHeader) {
      var headerStyle = window.getComputedStyle(stickyHeader);
      var headerRect = stickyHeader.getBoundingClientRect();
      var headerTop = parseFloat(headerStyle.top);
      if (headerStyle.position === 'fixed') headerBottom = Math.max(0, headerRect.bottom);
      else if (headerStyle.position === 'sticky' && Number.isFinite(headerTop)) {
        headerBottom = Math.max(0, headerTop + headerRect.height);
      }
    }
    return headerBottom;
  }

  function measureStickyPanel() {
    stickyFrame = 0;
    if (!stickyPanel || singleColumn.matches || document.body.classList.contains('boat-cost-printing')) return;
    var panelHeight = stickyPanel.getBoundingClientRect().height;
    var top = Math.min(stickyHeaderBottom() + 16, document.documentElement.clientHeight - 16 - panelHeight);
    var inset = top + 'px';
    if (inset !== stickyInset) {
      results.style.setProperty('--bc-results-sticky-top', inset);
      stickyInset = inset;
      revealStickyFocus(document.activeElement);
    }
  }

  function observeStickyPanel(panel) {
    if (stickyObserver && stickyPanel) stickyObserver.unobserve(stickyPanel);
    stickyPanel = panel;
    if (stickyObserver) stickyObserver.observe(panel, {box:'border-box'});
    scheduleStickyMeasurement();
  }

  if (stickyObserver && stickyHeader) stickyObserver.observe(stickyHeader, {box:'border-box'});
  window.addEventListener('resize', scheduleStickyMeasurement);
  // Also covers visual viewport changes that do not resize the header.
  if (window.visualViewport) window.visualViewport.addEventListener('resize', scheduleStickyMeasurement);
  results.addEventListener('toggle', scheduleStickyMeasurement, true);
  window.addEventListener('afterprint', scheduleStickyMeasurement);

  // Native focus scrolling can miss controls above a tall card's sticky inset.
  // Reveal only the focused control, without changing sticky positioning.
  function revealStickyFocus(target) {
    if (!stickyPanel || !stickyPanel.contains(target)) return;
    window.requestAnimationFrame(function () {
      if (!stickyPanel || !stickyPanel.contains(target) || document.activeElement !== target || singleColumn.matches || document.body.classList.contains('boat-cost-printing')) return;
      var targetRect = target.getBoundingClientRect();
      var panelRect = stickyPanel.getBoundingClientRect();
      var visibleTop = stickyHeaderBottom() + 16;
      var visibleBottom = document.documentElement.clientHeight - 16;
      var availableHeight = visibleBottom - visibleTop;
      if (availableHeight <= 0 || (targetRect.top >= visibleTop && targetRect.top + Math.min(targetRect.height, availableHeight) <= visibleBottom)) return;
      var desiredTop = targetRect.top < visibleTop || targetRect.height > availableHeight ? visibleTop : visibleBottom - targetRect.height;
      var desiredPanelTop = desiredTop - (targetRect.top - panelRect.top);
      var panelStyle = window.getComputedStyle(stickyPanel);
      var wrapperRect = results.getBoundingClientRect();
      var scrollTop = desiredPanelTop >= parseFloat(panelStyle.top)
        ? window.scrollY + wrapperRect.top - desiredPanelTop
        : window.scrollY + wrapperRect.bottom - panelRect.height - parseFloat(panelStyle.marginBottom) - desiredPanelTop;
      window.scrollTo({top:Math.max(0, scrollTop), behavior:'instant'});
    });
  }
  results.addEventListener('focusin', function (event) { revealStickyFocus(event.target); });

  function renderToolbar() {
    clear(toolbar); var scenarioSelect = node('select',null,{id:'bc-active-scenario'}); options(scenarioSelect,scenarios.map(function(s,i) { return [String(i),s.label || 'Scenario '+(i+1)]; }),String(active));
    scenarioSelect.addEventListener('change',function () { clearTimeout(timer); active = Number(scenarioSelect.value); render(); }); append(toolbar,node('label','Active estimate',{for:'bc-active-scenario'}),scenarioSelect);
    var clone = button('Duplicate scenario',function () { if (scenarios.length >= 3) return; scenarios.push(E.cloneScenario(scenarios[active])); scenarios[scenarios.length-1].label = ''; edited.push(edited[active]); var rec = records[active]; records[scenarios.length-1] = rec ? {result:rec.result,solution:rec.solution,stale:rec.stale,date:rec.date} : undefined; active = scenarios.length-1; render(); announce('Scenario duplicated. Its inputs can be edited independently.'); }); clone.disabled = scenarios.length >= 3; toolbar.appendChild(clone);
    var remove = button('Remove scenario',function () { if (scenarios.length < 2) return; if (window.confirm('Remove this scenario from the current comparison? Saved browser estimates are unchanged until you save again.')) { scenarios.splice(active,1); records.splice(active,1); edited.splice(active,1); if (baseline === active) baseline = 0; else if (baseline > active) baseline--; active = Math.max(0,active-1); render(); announce('Scenario removed.'); } }); remove.disabled = scenarios.length === 1; toolbar.appendChild(remove);
    toolbar.appendChild(button(compareOpen ? 'Hide comparison' : 'Compare scenarios',function () { compareOpen = !compareOpen; if (compareOpen && scenarios.length >= 2) { var good = scenarios.filter(function(s) { var r = evaluate(s); return r.result && r.result.valid && r.result.readiness.monthly; }); if (good.length >= 2) track('boat_cost_compare'); } renderToolbar(); renderComparison(); }));
    toolbar.appendChild(button('Try an example',function () { document.getElementById('bc-examples').hidden = !document.getElementById('bc-examples').hidden; }));
  }
  function examplePicker() { var box = node('div',null,{id:'bc-examples',class:'bc-panel'}); box.hidden = true; box.appendChild(para('Illustrative inputs, not market averages or recommended spending levels.'));
    var actions = node('div',null,{class:'bc-toolbar'}); [['H','$25,000 trailer-kept powerboat'],['B','$50,000 slip-kept cruiser'],['I','$100,000 larger cruiser']].forEach(function(p) { actions.appendChild(button(p[1],function () { loadExample(p[0]); })); }); box.appendChild(actions); return box; }
  function loadExample(key) { if (edited[active] && !window.confirm('Replace this edited scenario with the illustrative example?')) return; scenarios[active] = E.example(key); records[active] = undefined; edited[active] = false; render(); calculate(true); announce('Illustrative example loaded. All amounts are example assumptions.'); }
  function restoreControlFocus(controlId) {
    var control = controlId && document.getElementById(controlId);
    if (control && controlId.indexOf('bc-') === 0 && !control.disabled) control.focus({preventScroll:true});
  }
  function renderForm() {
    var focusedId = document.activeElement && document.activeElement.id;
    errorNodes = {}; clear(form); form.appendChild(node('h2','Build your boating budget')); form.appendChild(examplePicker());
    grouped(form,[selectField('direction','Start with',[['price','I know the boat price'],['budget','I know my monthly budget']]),selectField('view','Input view',[['quick','Quick view'],['detailed','Detailed view']])]);
    form.appendChild(textField('label','Scenario label (optional)','Up to 60 characters. Kept in this browser; omitted from share links.',60));
    var s = scenarios[active], purchase = section('Purchase and financing'); purchase.appendChild(selectField('purchase.method','Purchase method',[['financed','Financed purchase'],['cash','Cash purchase']],'Cash purchases treat all tax and fees as cash-paid.'));
    if (s.direction === 'price') purchase.appendChild(numberField('purchase.price','Boat price (USD)','$1 to $5,000,000. Required for a known-price estimate.',false));
    else { purchase.appendChild(numberField('budget.monthly','Monthly boating budget (USD)','Includes payments, recurring costs, and annual repair savings. $0 to $1,000,000.',false)); purchase.appendChild(numberField('budget.cash','Available upfront cash (USD)','Required. Covers purchase, all preparation, and initial repair reserve. $0 to $20,000,000.',false)); purchase.appendChild(para('The budget result holds your operating assumptions fixed. A different boat may have different costs.','bc-note')); }
    if (s.purchase.method === 'financed') {
      purchase.appendChild(selectField('purchase.down.mode','Down payment basis',[['amount','Dollars applied to boat price'],['percent','Percent of boat price']]));
      purchase.appendChild(numberField('purchase.down.input','Down payment ('+(s.purchase.down.mode === 'percent' ? '%' : 'USD')+')','Down payment applies to boat price. Financed fees can still create a loan with 100% down.',false));
      purchase.appendChild(numberField('purchase.rate','Annual contract interest rate (%)','0–40%. Use the loan contract interest rate, not APR: APR includes additional borrowing costs. This is an estimate or lender quote, never a live rate.',false));
      purchase.appendChild(numberField('purchase.term','Loan term (months)','Whole months, 12–240. No rate or term is required when principal is zero.',false));
      var terms = node('div',null,{class:'bc-toolbar'}); [5,10,15,20].forEach(function(y) { terms.appendChild(button(y+' years',function () { mutate(function () { s.purchase.term = {value:String(y*12),status:'entered'}; },true); })); }); purchase.appendChild(terms);
    }
    purchase.appendChild(selectField('purchase.tax.mode','Purchase tax basis',[['amount','Total tax amount (USD)'],['percent','Percent of boat price']])); purchase.appendChild(cost('purchase.tax.input','Purchase tax ('+(s.purchase.tax.mode === 'percent' ? '%' : 'USD')+')','Blank tax is unknown. Percentage arithmetic covers boat price only, excluding taxable fees, exemptions, credits, local/use taxes, and caps. Enter a total amount for those cases.'));
    if (s.purchase.method === 'financed') purchase.appendChild(selectField('purchase.tax.treatment','Tax payment',[['cash','Cash-paid'],['financed','Financed']]));
    s.purchase.fees.forEach(function(f,i) { purchase.appendChild(cost('purchase.fees.'+i+'.input',labels[f.type]+' (USD)')); if (s.purchase.method === 'financed') purchase.appendChild(selectField('purchase.fees.'+i+'.treatment',labels[f.type]+' payment',[['cash','Cash-paid'],['financed','Financed']])); });
    if (s.view === 'detailed') purchase.appendChild(selectField('purchase.state','State (optional context)',[''].concat('AL AK AZ AR CA CO CT DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WV WI WY DC'.split(' ')),'Does not set or validate a tax rate.'));
    form.appendChild(purchase);
    if (s.view === 'detailed') renderProfile(form); else { var profileNote = para('Used-boat checks and boat profile are available in Detailed view. Switching views preserves all inputs.','bc-help'); form.appendChild(profileNote); }
    renderOperations(form); renderPreparation(form);
    var reserves = section('Repair savings'); append(reserves,cost('reserves.annual','Annual repair reserve contribution (USD)','Money you choose to save each year, not a bill or a forecast of repair costs.'),cost('reserves.initial','Initial repair reserve (USD)','Cash you want available at purchase, separate from known immediate work and new annual savings.')); form.appendChild(reserves);
    if (s.view === 'detailed') renderResale(form);
    var submit = node('button','Calculate my boating budget',{type:'submit',class:'bc-primary'}); form.appendChild(submit); form.appendChild(para('USD · US gallons · feet. Planning estimates only.','bc-note'));
    restoreControlFocus(focusedId);
  }
  function renderProfile(parent) {
    var p = section('Boat profile and checklist guidance');
    grouped(p,[selectField('profile.boatType','Boat type',[['powerboat','Powerboat / cruiser'],['fishing','Fishing boat'],['pontoon','Pontoon'],['sailboat','Sailboat'],['trawler','Trawler'],['pwc','Personal watercraft'],['other','Other']]),selectField('profile.condition','Condition',[['used','Used'],['new','New']])]);
    grouped(p,[textField('profile.year','Model year (optional)','1900 through current year + 2.'),textField('profile.length','Physical length (feet, optional)','1–200 feet. Marina billable length can be different.')]);
    grouped(p,[selectField('profile.engineType','Engine type',[['','Unspecified'],['outboard','Outboard'],['sterndrive','Sterndrive'],['gasInboard','Gas inboard'],['dieselInboard','Diesel inboard'],['electricOther','Electric / other']]),textField('profile.engineCount','Engine count (optional)','0–6. Never multiplies the combined GPH input.')]);
    grouped(p,[selectField('profile.water','Water',[['','Unspecified'],['fresh','Fresh'],['salt','Salt'],['mixed','Mixed']]),selectField('profile.season','Use season',[['','Unspecified'],['seasonal','Seasonal'],['yearRound','Year-round']])]); p.appendChild(para('Profile changes adjust checklist guidance only; they never overwrite costs or apply a hidden multiplier.','bc-note')); parent.appendChild(p);
  }
  function groupMode(parent,path,label,renderDetails) {
    var group = get(path), s = scenarios[active];
    if (s.view === 'quick' && group.mode === 'details') {
      var detailResult = E.calculate(s);
      var detailRow = detailResult.operations.breakdown.find(function(row) { return row.key === path.split('.').pop(); });
      var detailAmount = path === 'preparation' ? detailResult.upfront.preparation : detailRow ? detailRow.annual : null;
      var detailPeriod = path === 'preparation' ? ' initial / first-year' : ' per year';
      var detailStatus = detailRow ? detailRow.status : group.rows.some(function(row) { return !row.includedElsewhere && row.input.status === 'illustrative'; }) ? 'illustrative' : 'reviewed';
      parent.appendChild(node('h3',label+' from detailed inputs'));
      parent.appendChild(para(detailAmount !== null ? fmt(detailAmount)+detailPeriod+' · '+detailStatus : detailRow && detailRow.knownAnnual > 0 ? fmt(detailRow.knownAnnual)+' known annual costs so far — incomplete' : 'Incomplete — review the itemized assumptions.',detailAmount !== null ? 'bc-result-label' : 'bc-warning'));
      parent.appendChild(para('All itemized inputs are preserved.','bc-note')); parent.appendChild(button('Edit '+label.toLowerCase()+' details',function () { s.view = 'detailed'; renderForm(); })); parent.appendChild(button('Replace '+label.toLowerCase()+' with a total',function () { if (window.confirm('Use a single '+label.toLowerCase()+' total instead of the detailed rows? The rows will be preserved, but only the new total will be counted.')) mutate(function () { group.mode = 'total'; group.total = {value:'',status:'unknown'}; },true); })); }
    else if (group.mode === 'total') { parent.appendChild(cost(path+'.total',label+(path === 'preparation' ? ' — initial and first-year total (USD)' : ' — annual total (USD)'))); if (s.view === 'detailed') parent.appendChild(button('Use itemized '+label.toLowerCase(),function () { mutate(function () { group.mode = 'details'; },true); })); }
    else { renderDetails(parent); parent.appendChild(button('Use a single '+label.toLowerCase()+' total',function () { if (window.confirm('Replace active details with a grouped total? The existing rows will be kept and can be selected again.')) mutate(function () { group.mode = 'total'; },true); })); }
  }
  function renderOperations(parent) {
    var s = scenarios[active], op = section('Recurring ownership costs');
    op.appendChild(para('Review every group. A deliberate zero is valid; an exclusion means not included, not necessarily free. Annual and seasonal bills are spread over 12 months.','bc-note'));
    if (!(s.view === 'quick' && s.operating.fuel.mode === 'usage')) op.appendChild(selectField('operating.fuel.mode','Fuel input basis',[['annual','Direct annual fuel cost'],['usage','Running hours × total GPH × fuel price']],'Only the selected fuel basis is counted. Switching keeps both sets of inputs.',function(mode) { if (mode === 'usage') s.view = 'detailed'; }));
    if (s.operating.fuel.mode === 'annual') op.appendChild(cost('operating.fuel.annual','Annual liquid fuel cost (USD)','Include consumed fuel only. For electric propulsion, enter annual energy spending under other costs and explicitly exclude liquid fuel.'));
    else if (s.view === 'quick') {
      var fuelResult = E.calculate(s);
      var fuelRow = fuelResult.operations.breakdown.find(function(row) { return row.key === 'fuel'; });
      var fuelSummary = node('div',null,{class:'bc-cost'});
      fuelSummary.appendChild(node('h3','Annual fuel from detailed inputs'));
      if (fuelRow && fuelRow.annual !== null) fuelSummary.appendChild(para(fmt(fuelRow.annual)+' per year · '+fuelRow.status,'bc-result-label'));
      else fuelSummary.appendChild(para(fuelRow && fuelRow.knownAnnual > 0 ? fmt(fuelRow.knownAnnual)+' known annual fuel costs so far — incomplete' : 'Incomplete fuel estimate — review the detailed assumptions.','bc-warning'));
      fuelSummary.appendChild(para('Includes the selected propulsion and generator assumptions. Usage inputs remain preserved.','bc-note'));
      var fuelActions = node('div',null,{class:'bc-toolbar'});
      fuelActions.appendChild(button('Edit fuel details',function () { s.view = 'detailed'; renderForm(); var target = document.getElementById('bc-operating-fuel-hours'); if (target) target.focus(); }));
      fuelActions.appendChild(button('Replace fuel with annual total',function () {
        if (window.confirm('Use your direct annual fuel amount instead of the detailed usage calculation? Existing annual and usage inputs will be preserved; only the annual amount will count.')) mutate(function () { s.operating.fuel.mode = 'annual'; },true);
      }));
      fuelSummary.appendChild(fuelActions); op.appendChild(fuelSummary);
    }
    else { append(op,cost('operating.fuel.hours','Annual boat running hours','0–8,760 boat running hours; do not add engine-meter hours across engines.'),cost('operating.fuel.gph','Total GPH for all propulsion engines','0–500 US gallons/hour. Two engines burning 8 GPH each means entering 16.'),cost('operating.fuel.price','Fuel price (USD / US gallon)','0–50 USD per US gallon. Explicit zero hours needs no GPH or price.'));
      if (s.view === 'detailed') { op.appendChild(selectField('operating.fuel.generator.status','Generator fuel',[['excluded','Excluded'],['unknown','Not reviewed'],['entered','Include generator fuel'],['illustrative','Illustrative generator fuel']])); if (s.operating.fuel.generator.status !== 'excluded') append(op,cost('operating.fuel.generator.hours','Annual generator hours','Separate from propulsion hours.'),cost('operating.fuel.generator.gph','Generator GPH','Combined generator fuel use; never multiplied by propulsion engine count.'),cost('operating.fuel.generator.price','Generator fuel price (USD / gallon)')); }
    }
    op.appendChild(link('How to find actual fuel burn and check trip fuel costs',mount.dataset.fuelUrl || '/boat-fuel-calculator/','fuel'));
    groupMode(op,'operating.storage','Storage',renderStorage);
    append(op,cost('operating.insurance','Insurance — annual premium (USD)'),cost('operating.maintenance','Routine maintenance — annual (USD)','Scheduled service and consumables. Exclude separately counted seasonal or first-year catch-up work.'),cost('operating.registration','Registration / recurring taxes — annual (USD)','Separate from one-time title fees and purchase tax.'),cost('operating.seasonal','Seasonal services — annual (USD)','Winterization, commissioning, shrink-wrap, routine haul-out, or bottom work. Do not repeat costs already included in maintenance or storage.'));
    groupMode(op,'operating.other','Other operations',renderOther); parent.appendChild(op);
  }
  function renderStorage(parent) {
    var rows = scenarios[active].operating.storage.rows; parent.appendChild(para('Up to four charges. Overlapping periods can be legitimate; check for duplicate charges. Billable feet may exceed physical boat length.','bc-note'));
    rows.forEach(function(row,i) { var box = node('div',null,{class:'bc-panel'}), path = 'operating.storage.rows.'+i; box.appendChild(node('h4','Storage row '+(i+1))); grouped(box,[selectField(path+'.type','Storage type',[['slip','Slip'],['dryStack','Dry stack'],['land','Land storage'],['trailer','Trailer storage']]),selectField(path+'.basis','Charge basis',[['annual','Annual amount'],['monthly','Monthly rate × paid months'],['perFoot','Rate per foot / month × feet × months']])]); box.appendChild(cost(path+'.input',row.basis === 'annual' ? 'Annual storage amount (USD)' : row.basis === 'monthly' ? 'Monthly storage rate (USD)' : 'Rate per billable foot per month (USD)')); if (row.basis !== 'annual') { box.appendChild(textField(path+'.months','Paid months','Whole months, 0–12; not the boating season multiplier.')); box.appendChild(selectField(path+'.startMonth','Start month (optional overlap check)',[''].concat(Array.from({length:12},function(_,m) { return String(m+1); })))); } if (row.basis === 'perFoot') box.appendChild(textField(path+'.billableFeet','Billable length (feet)','Enter the marina minimum if it exceeds physical boat length.')); box.appendChild(button('Remove storage row',function () { if (window.confirm('Remove this storage charge?')) mutate(function () { rows.splice(i,1); },true); })); parent.appendChild(box); });
    var add = button('Add storage row',function () { mutate(function () { rows.push({type:'slip',basis:'annual',input:{value:'',status:'unknown'},months:'',billableFeet:'',startMonth:''}); },true); }); add.disabled = rows.length >= 4; parent.appendChild(add);
  }
  function renderOther(parent) {
    var rows = scenarios[active].operating.other.rows;
    if (!rows.length) { ['utilities','pumpouts','trailer','towing','launch','subscriptions','other'].forEach(function(type) { rows.push({type:type,input:{value:'',status:'unknown'}}); }); }
    rows.forEach(function(row,i) { parent.appendChild(cost('operating.other.rows.'+i+'.input',(row.type === 'trailer' ? 'Trailer maintenance' : labels[row.type])+' — annual (USD)')); });
  }
  function renderPreparation(parent) {
    var s = scenarios[active], prep = section('Other initial and first-year costs'); prep.appendChild(para('All preparation is cash-paid. Some work occurs before closing or later in year one. Upfront planning assumes all of it must be fundable from available cash.','bc-note'));
    groupMode(prep,'preparation','Preparation',function(box) { s.preparation.rows.forEach(function(row,i) { var path = 'preparation.rows.'+i; box.appendChild(cost(path+'.input',labels[row.type]+' (USD)')); var check = node('input',null,{type:'checkbox',id:id(path)+ '-included'}); check.checked = row.includedElsewhere; check.style.width = 'auto'; check.addEventListener('change',function () { row.includedElsewhere = check.checked; touched(); }); var label = node('label',null,{for:id(path)+'-included'}); append(label,check,document.createTextNode(' Already included in boat price or another category — do not add again')); box.appendChild(label); }); });
    var guidance = node('ul',null,{class:'bc-guidance'}); if (s.profile.condition === 'used') guidance.appendChild(node('li','Used boat: review survey, inspection haul-out, engine inspection, catch-up work, and cash for unplanned repairs. A reserve does not establish mechanical safety.'));
    if (s.profile.boatType === 'sailboat') guidance.appendChild(node('li','Sailboat: consider rigging and sail work in maintenance or preparation.'));
    if (s.operating.storage.rows.some(function(r) { return r.type === 'slip'; })) guidance.appendChild(node('li','In-water storage: review bottom work, haul-out, and marina utilities.'));
    if (s.operating.storage.rows.some(function(r) { return r.type === 'trailer'; })) guidance.appendChild(node('li','Trailer storage: review trailer maintenance, towing fuel, and launch fees.'));
    if (s.profile.season === 'seasonal') guidance.appendChild(node('li','Seasonal use: review winter storage, winterization, and spring commissioning. Loan, insurance, and storage do not automatically shrink with the season.'));
    if (Number(s.profile.engineCount) > 1) guidance.appendChild(node('li','Multiple engines: enter total-vessel GPH and include service costs for every engine.')); prep.appendChild(guidance); parent.appendChild(prep);
  }
  function renderResale(parent) { var resale = section('Optional resale assumptions'); resale.appendChild(para('No resale value is assumed. Enter both a resale value and an explicit selling cost, including zero, for each desired horizon.','bc-note')); ['five','ten'].forEach(function(h,i) { var path = 'resale.'+h; resale.appendChild(cost(path+'.value','Expected resale at year '+(i ? 10 : 5)+' (USD)')); resale.appendChild(selectField(path+'.selling.mode','Selling cost basis — year '+(i ? 10 : 5),[['amount','Dollar amount'],['percent','Percent of resale value']])); resale.appendChild(cost(path+'.selling.input','Selling costs — year '+(i ? 10 : 5)+' ('+(get(path+'.selling.mode') === 'percent' ? '%' : 'USD')+')')); }); parent.appendChild(resale); }
  function evaluate(s) { if (s.direction === 'budget') { var solution = E.solveBudget(s); return {result:solution.status === 'solved' || solution.status === 'maximum' ? solution.result : null,solution:solution}; } return {result:E.calculate(s),solution:null}; }
  function calculate(explicit) {
    clearTimeout(timer); var evaluated = evaluate(scenarios[active]), result = evaluated.result, solution = evaluated.solution;
    var errors = result ? result.errors : (solution && solution.errors || []), complete = result && result.valid && result.readiness.complete && !result.missing.length;
    if (!explicit && (!complete || errors.length)) { if (records[active]) records[active].stale = true; renderResults(); renderComparison(); return; }
    records[active] = {result:result,solution:solution,stale:false,date:new Date()}; renderResults(); renderComparison();
    if (explicit) {
      var previousErrors = form.querySelector('.bc-errors'); if (previousErrors) previousErrors.remove(); form.querySelectorAll('[aria-invalid]').forEach(function(n) { n.removeAttribute('aria-invalid'); });
      if (errors.length || (solution && !result)) { showErrors(errors,solution); track('boat_cost_error',{error_code:errors.length ? 'validation' : solution && solution.status === 'no-feasible' ? 'no_feasible_budget' : 'incomplete'}); announce('Review the calculation messages and required assumptions.'); }
      else { track('boat_cost_calculate'); announce(complete ? 'Estimate updated.' : 'Known subtotal calculated. Review the incomplete assumptions.'); results.focus(); }
    }
  }
  function showErrors(errors,solution) {
    var old = form.querySelector('.bc-errors'); if (old) old.remove(); form.querySelectorAll('[aria-invalid]').forEach(function(n) { n.removeAttribute('aria-invalid'); });
    var box = node('div',null,{class:'bc-errors',tabindex:'-1',role:'alert'}); box.appendChild(node('h3',errors.length ? 'Check these inputs' : 'Complete the required assumptions'));
    var list = node('ul'); (errors.length ? errors : solution && solution.missing || []).forEach(function(error) { var li = node('li'), input = errorNodes[error.path]; if (input) { input.setAttribute('aria-invalid','true'); var a = node('a',error.message,{href:'#'+input.id}); a.addEventListener('click',function(e) { e.preventDefault(); input.focus(); }); li.appendChild(a); } else li.textContent = error.message; list.appendChild(li); }); box.appendChild(list); if (solution && solution.reason) box.appendChild(para(solution.reason)); form.insertBefore(box,form.firstChild); box.focus(); }
  function summary(parent, pairs) { var dl = node('dl',null,{class:'bc-summary'}); pairs.forEach(function(pair) { append(dl,node('dt',pair[0]),node('dd',typeof pair[1] === 'string' ? pair[1] : fmt(pair[1]))); }); parent.appendChild(dl); }
  function table(headers, rows, caption) { var wrap = node('div',null,{class:'bc-table-wrap',tabindex:'0',role:'region','aria-label':caption}), t = node('table'); t.appendChild(node('caption',caption)); var head = node('thead'), tr = node('tr'); headers.forEach(function(h) { tr.appendChild(node('th',h,{scope:'col'})); }); head.appendChild(tr); t.appendChild(head); var body = node('tbody'); rows.forEach(function(row) { var r = node('tr'); row.forEach(function(value,i) { r.appendChild(node(i === 0 ? 'th' : 'td',value,i === 0 ? {scope:'row'} : {})); }); body.appendChild(r); }); t.appendChild(body); wrap.appendChild(t); return wrap; }
  function renderTripCta(parent) {
    var box = node('section',null,{class:'bc-panel bc-trip-cta bc-no-print','aria-labelledby':'bc-results-trip-title'});
    append(box,node('h3','What would an actual trip cost?',{id:'bc-results-trip-title'}),para('Map your route and estimate fuel, distance, and travel time with FPW’s free Trip Planner.'),node('a','Plan a Trip Free',{href:mount.dataset.plannerUrl,class:'bc-cta-button','data-boat-cost-placement':'right_results'}),para(mount.dataset.plannerNote,'bc-note bc-cta-note'));
    parent.appendChild(box);
  }
  function renderResults() {
    clear(results); results.tabIndex = -1; var panel = node('div',null,{class:'bc-panel'}); results.appendChild(panel); observeStickyPanel(panel); panel.appendChild(node('h1','Boat Loan and Ownership Cost Calculator',{class:'bc-print-only'})); panel.appendChild(node('h2','Your boating budget')); var rec = records[active], s = scenarios[active];
    if (!rec) { panel.appendChild(para('Enter your assumptions and select “Calculate my boating budget,” or try a labeled example. No estimate has been calculated.','bc-note')); renderTripCta(panel); renderSaveControls(panel); return; }
    if (rec.stale) panel.appendChild(para('Needs recalculation — the previous result does not include your latest complete, valid inputs. Sharing and printing are disabled.','bc-warning'));
    var r = rec.result, solution = rec.solution;
    if (solution && !r) { panel.appendChild(para(solution.reason || 'Complete the assumptions before solving for a boat price.','bc-warning')); if (solution.monthlyShortfall != null) summary(panel,[['Monthly budget shortfall',solution.monthlyShortfall]]); if (solution.cashShortfall != null) summary(panel,[['Upfront cash shortfall',solution.cashShortfall]]); if (solution.missing && solution.missing.length) { var missing = node('ul'); solution.missing.forEach(function(m) { missing.appendChild(node('li',m.message)); }); panel.appendChild(missing); } renderTripCta(panel); renderSaveControls(panel); return; }
    if (!r) { renderTripCta(panel); return; }
    if (!r.valid) { panel.appendChild(para('The estimate could not be calculated. Review the invalid inputs shown in the form.','bc-warning')); renderTripCta(panel); renderSaveControls(panel); return; }
    if (solution) { panel.appendChild(para(solution.status === 'maximum' ? 'At least the supported maximum under these assumptions' : 'Boat price that fits these assumptions','bc-result-label')); panel.appendChild(node('div',fmt(solution.price),{class:'bc-price-value'})); summary(panel,[['Monthly headroom',solution.monthlyHeadroom],['Upfront cash headroom',solution.cashHeadroom]]); panel.appendChild(para('The budget result holds your operating assumptions fixed. A different boat may have different costs.','bc-note')); }
    panel.appendChild(para(r.readiness.monthly ? 'Estimated monthly boating budget' : 'Known monthly costs so far','bc-result-label')); panel.appendChild(node('div',fmt(r.readiness.monthly ? r.monthly.budget : r.monthly.knownCosts),{class:'bc-hero-value'}));
    panel.appendChild(para('Monthly figures spread annual and seasonal costs across 12 months; actual bill timing varies.','bc-note'));
    if (r.illustrativePaths.length) panel.appendChild(node('span','Includes illustrative assumptions',{class:'bc-status'}));
    [['loan','Loan'],['operations','Operating budget'],['purchaseCash','Purchase cash'],['preparation','Preparation'],['reserves','Repair savings'],['firstYear','First year'],['resaleFive','Year 5 resale'],['resaleTen','Year 10 resale']].forEach(function(pair) { panel.appendChild(node('span',pair[1]+': '+(r.readiness[pair[0]] ? 'reviewed' : 'incomplete'),{class:'bc-status'})); });
    renderTripCta(panel);
    var rows = r.operations.breakdown.map(function(b) { return [b.label,b.monthly == null && b.knownAnnual > 0 ? fmt(b.knownAnnual/12)+' known' : fmt(b.monthly),b.annual == null && b.knownAnnual > 0 ? fmt(b.knownAnnual)+' known' : fmt(b.annual),(b.basis || '')+' · '+b.status+(b.annual == null ? ' (incomplete)' : '')]; });
    rows.unshift(['Loan payment',fmt(r.loan.payment),r.firstYear && r.firstYear.loanPayments != null ? fmt(r.firstYear.loanPayments) : 'Incomplete',r.readiness.loan ? 'Scheduled first-year payments' : 'Incomplete']);
    rows.push(['Repair savings contribution',fmt(r.monthly.repairSavings),r.monthly.repairSavings == null ? 'Incomplete' : fmt(r.monthly.repairSavings*12),s.reserves.annual.status+' · savings, not spending']);
    if (r.monthly.roundingAdjustment) rows.push(['Display rounding adjustment',fmt(r.monthly.roundingAdjustment),'—','Displayed rows reconcile to the headline; calculation keeps full precision']);
    panel.appendChild(table(['Category','Monthly equivalent','Annual amount','Basis / status'],rows,'Monthly and annual breakdown'));
    summary(panel,[['Expected monthly expenses, excluding repair savings',r.monthly.expectedExpenses],['Monthly repair savings',r.monthly.repairSavings],['Loan principal',r.loan.principal],['Lifetime loan interest',r.loan.totalInterest]]);
    panel.appendChild(node('h3','Purchase cash and first year')); summary(panel,[['Cash for purchase',r.upfront.purchaseCash],['Other initial and first-year costs',r.upfront.preparation],['Initial repair reserve',r.upfront.initialReserve],['Upfront planning cash',r.upfront.planningCash],['First-year expected spending',r.firstYear.spending],['First-year funding target, including both reserve allocations',r.firstYear.funding]]);
    panel.appendChild(para('Upfront planning cash assumes all initial and first-year work is fundable at purchase, even if paid later. Initial reserve and annual savings are separate allocations.','bc-note'));
    var horizons = ['five','ten'].map(function(h,i) { var value = r.horizons[h]; return [i ? '10 years' : '5 years',fmt(value.cashSpent),fmt(value.reserveAllocations),fmt(value.loanBalance),value.netOwnershipCost == null ? 'No complete resale assumption' : fmt(value.netOwnershipCost)]; }); panel.appendChild(table(['Horizon','Cash spent','Repair savings allocated','Loan balance','Net ownership cost if sold'],horizons,'Long-term cash, savings, and debt'));
    panel.appendChild(para('Long-term projections hold operating costs constant and exclude inflation and unplanned repairs not entered here. Repair allocations are savings, not forecast ending bank balances. No resale value is assumed unless you enter one.','bc-note'));
    if (r.missing.length) { var details = node('details'); details.open = true; details.appendChild(node('summary','Assumptions still needed ('+r.missing.length+')')); var ml = node('ul'); r.missing.forEach(function(m) { ml.appendChild(node('li',m.message)); }); details.appendChild(ml); panel.appendChild(details); }
    if (r.exclusions.length) { var excluded = node('div'); excluded.appendChild(node('h3','Explicit exclusions')); excluded.appendChild(para(r.exclusions.map(function(e) { return e.label; }).join('; ')+'. Excluded does not necessarily mean free.','bc-note')); panel.appendChild(excluded); }
    r.warnings.forEach(function(w) { panel.appendChild(para(w.message,'bc-warning')); });
    if (r.insights.length) { var insights = node('div',null,{class:'bc-no-print'}); insights.appendChild(node('h3','What changes this estimate')); r.insights.slice(0,3).forEach(function(i) {
      insights.appendChild(para(i.text));
      if (i.terms) insights.appendChild(table(['Term','Payment / month','Lifetime interest','Payment difference','Interest difference'],i.terms.map(function(t) { return [String(t.months/12)+' years',fmt(t.payment),fmt(t.totalInterest),(t.paymentDifference >= 0 ? '+' : '−')+fmt(Math.abs(t.paymentDifference)),(t.interestDifference >= 0 ? '+' : '−')+fmt(Math.abs(t.interestDifference))]; }),'Term sensitivity — differences from this estimate'));
      if (typeof i.share === 'number') insights.appendChild(para((i.share*100).toFixed(1)+'% of '+fmt(i.denominator)+' in annual expected expenses.'));
      if (typeof i.monthlyIncrease === 'number') insights.appendChild(para('Monthly budget increases by '+fmt(i.monthlyIncrease)+'; annual fuel increases by '+fmt(i.annualIncrease)+'.'));
    }); panel.appendChild(insights); }
    renderAmortization(panel,r);
    var displayedAssumptions = s;
    if (solution && solution.scenario) {
      displayedAssumptions = E.cloneScenario(solution.scenario);
      displayedAssumptions.direction = s.direction;
      displayedAssumptions.budget = E.cloneScenario(s.budget);
    }
    renderAssumptions(panel,displayedAssumptions,rec.date);
    panel.appendChild(para('Financing terms shown here do not mean this vessel or borrower qualifies for a loan. Actual payment schedules may differ slightly because of dates and rounding.','bc-note')); panel.appendChild(para(disclaimer,'bc-note'));
    renderSaveControls(panel);
  }
  function renderAmortization(parent,r) {
    if (!r.readiness.loan || !r.loan.schedule || !r.loan.schedule.length) return; var details = node('details',null,{class:'bc-no-print'}); details.appendChild(node('summary','Loan amortization schedule'));
    var annual = r.loan.annualSummaries || []; details.appendChild(table(['Year','Payments','Principal','Interest','Remaining balance'],annual.map(function(y) { return [String(y.year),fmt(y.payment == null ? y.payments : y.payment),fmt(y.principal),fmt(y.interest),fmt(y.balance)]; }),'Annual loan summary'));
    var full = node('details'); full.appendChild(node('summary','Show monthly schedule')); full.appendChild(table(['Month','Payment','Principal','Interest','Remaining balance'],r.loan.schedule.map(function(m) { return [String(m.month),fmt(m.payment),fmt(m.principal),fmt(m.interest),fmt(m.balance)]; }),'Monthly loan schedule')); details.appendChild(full); parent.appendChild(details);
  }
  function renderAssumptions(parent,s,date) {
    var d = node('details',null,{class:'bc-assumptions bc-no-print'}); d.appendChild(node('summary','Assumptions and calculation date')); var content = node('div'); content.appendChild(para((s.label || 'Active scenario')+' · '+date.toLocaleDateString('en-US')+' · '+s.direction+' direction · '+s.purchase.method+' purchase.')); var list = node('ul');
    function field(label,f,suffix) { if (!f) return; list.appendChild(node('li',label+': '+(f.status === 'excluded' ? 'excluded' : f.status === 'unknown' ? 'unknown' : String(f.value)+(suffix || ''))+' ['+f.status+']')); }
    field('Boat price',s.purchase.price,' USD'); if (s.purchase.method === 'financed') { field('Down payment',s.purchase.down.input,s.purchase.down.mode === 'percent' ? '%' : ' USD'); field('Annual contract interest rate',s.purchase.rate,'%'); field('Loan term',s.purchase.term,' months'); }
    field('Purchase tax, '+(s.purchase.method === 'cash' ? 'cash-paid' : s.purchase.tax.treatment),s.purchase.tax.input,s.purchase.tax.mode === 'percent' ? '%' : ' USD'); s.purchase.fees.forEach(function(f) { field(labels[f.type]+', '+(s.purchase.method === 'cash' ? 'cash-paid' : f.treatment),f.input,' USD'); });
    if (s.direction === 'budget') { field('Monthly spending limit',s.budget.monthly,' USD'); field('Available upfront cash',s.budget.cash,' USD'); }
    list.appendChild(node('li','Boat profile: '+[s.profile.boatType,s.profile.condition,s.profile.year,s.profile.length ? s.profile.length+' ft' : '',s.profile.engineType,s.profile.engineCount ? s.profile.engineCount+' engines' : '',s.profile.water,s.profile.season].filter(Boolean).join(', ')+'.'));
    if (s.operating.fuel.mode === 'annual') field('Annual liquid fuel',s.operating.fuel.annual,' USD'); else { field('Annual boat running hours',s.operating.fuel.hours,' hours'); field('Total propulsion GPH',s.operating.fuel.gph,' GPH'); field('Fuel price',s.operating.fuel.price,' USD / gallon'); if (s.operating.fuel.generator.status !== 'excluded') { field('Generator hours',s.operating.fuel.generator.hours,' hours'); field('Generator GPH',s.operating.fuel.generator.gph,' GPH'); field('Generator fuel price',s.operating.fuel.generator.price,' USD / gallon'); } else list.appendChild(node('li','Generator fuel: excluded.')); }
    if (s.operating.storage.mode === 'total') field('Annual storage',s.operating.storage.total,' USD'); else s.operating.storage.rows.forEach(function(row) { field('Storage '+row.type+' / '+row.basis+(row.months !== '' ? ' / '+row.months+' months' : '')+(row.billableFeet !== '' ? ' / '+row.billableFeet+' billable ft' : ''),row.input,' USD'); });
    [['insurance','Annual insurance'],['maintenance','Annual routine maintenance'],['registration','Annual registration / taxes'],['seasonal','Annual seasonal services']].forEach(function(pair) { field(pair[1],s.operating[pair[0]],' USD'); });
    if (s.operating.other.mode === 'total') field('Other annual operations',s.operating.other.total,' USD'); else s.operating.other.rows.forEach(function(row) { field('Annual '+labels[row.type],row.input,' USD'); });
    if (s.preparation.mode === 'total') field('Other initial and first-year costs',s.preparation.total,' USD'); else s.preparation.rows.forEach(function(row) { field(labels[row.type]+(row.includedElsewhere ? ' (included elsewhere, counted once)' : ''),row.input,' USD'); }); field('Initial repair reserve',s.reserves.initial,' USD'); field('Annual repair savings',s.reserves.annual,' USD');
    ['five','ten'].forEach(function(h,i) { field('Year '+(i ? 10 : 5)+' resale',s.resale[h].value,' USD'); field('Year '+(i ? 10 : 5)+' selling costs',s.resale[h].selling.input,s.resale[h].selling.mode === 'percent' ? '%' : ' USD'); });
    content.appendChild(list); d.appendChild(content); parent.appendChild(d); var print = content.cloneNode(true); print.className = 'bc-print-only bc-assumptions'; print.insertBefore(node('h3','Assumptions'),print.firstChild); parent.appendChild(print);
  }
  function shareAllowed() { var carrier = document.getElementById('boat-cost-calculator') || mount; return carrier.getAttribute('data-share-verified') === 'true' && window.FPWBoatCostBootstrap && window.FPWBoatCostBootstrap.clean === true; }
  function renderSaveControls(parent) {
    var box = node('div',null,{class:'bc-no-print'}), actions = node('div',null,{class:'bc-toolbar'}), rec = records[active];
    actions.appendChild(button('Save in this browser',function () { var out = S.save(scenarios); if (out.ok) { track('boat_cost_save'); announce('Saved in this browser. Estimates expire after 180 days.'); } else actionError(out.error || 'invalid_state',storageError(out.error)); }));
    actions.appendChild(button('Restore saved estimates',function () { var out = S.restore(); if (!out.ok) { actionError(out.error,storageError(out.error)); return; } if (edited.some(Boolean) && !window.confirm('Replace current scenarios with the saved browser estimates?')) return; scenarios = out.scenarios; active = 0; baseline = 0; records = []; edited = scenarios.map(function() { return false; }); scenarios.forEach(function(s,i) { var r = evaluate(s); records[i] = {result:r.result,solution:r.solution,stale:false,date:new Date()}; }); render(); announce('Saved estimates restored and recalculated.'); }));
    actions.appendChild(button('Delete saved estimates',function () { if (window.confirm('Delete only this calculator’s saved estimates from this browser?')) { var out = S.remove(); if (out.ok) announce('Saved boat-cost estimates deleted. Current inputs remain available.'); else actionError(out.error,storageError(out.error)); } }));
    var share = button('Share active scenario',function () { if (!shareAllowed()) return; if (!window.confirm('Anyone with this link can view these figures. The link is not private and cannot be revoked. Encoding is not encryption. Copy the link?')) return; var out = S.share(scenarios[active],mount.dataset.canonicalUrl || (document.querySelector('link[rel="canonical"]') ? document.querySelector('link[rel="canonical"]').href : window.location.origin + window.location.pathname)); if (!out.ok) { actionError(out.error,out.error === 'oversize' ? 'This scenario is too large for a share link. Print or save in this browser instead.' : 'This scenario cannot be shared. Review its inputs.'); return; } if (!navigator.clipboard || !navigator.clipboard.writeText) { actionError('clipboard_unavailable','Clipboard unavailable. Use browser save or print.'); return; } navigator.clipboard.writeText(out.url).then(function () { track('boat_cost_share'); announce('Share link copied. Anyone with it can view these figures.'); },function () { actionError('clipboard_unavailable','The browser could not copy the link. Use browser save or print.'); }); }); share.disabled = !rec || rec.stale || !rec.result || !rec.result.valid || !shareAllowed(); actions.appendChild(share);
    var print = button('Print or save as PDF',function () { document.body.classList.add('boat-cost-printing'); track('boat_cost_print'); window.print(); }); print.disabled = !rec || rec.stale || !rec.result || !rec.result.valid; actions.appendChild(print); box.appendChild(actions);
    box.appendChild(para('Browser saving stays on this device, is not an account backup, may disappear when browser data is cleared, and expires after 180 days. Nothing is saved until you choose Save.','bc-note'));
    box.appendChild(para('Anyone with a share link can view its figures. The link is not private and cannot be revoked. Scenario labels are omitted.','bc-note')); if (!shareAllowed()) box.appendChild(para('Sharing is unavailable until this page’s privacy checks are verified. Browser saving and printing remain available.','bc-note')); parent.appendChild(box);
  }
  function storageError(code) { return {missing:'No saved boat-cost estimates were found.',expired:'Saved estimates expired after 180 days. Enter or save a fresh estimate.',storage_unavailable:'Browser storage is blocked or full. Calculation still works; use print instead.',invalid_state:'Saved estimates could not be validated and were not loaded.'}[code] || 'This action could not be completed. Your current inputs are still available.'; }
  function renderComparison() {
    clear(comparison); comparison.hidden = !compareOpen; if (!compareOpen) return; comparison.appendChild(node('h2','Compare your scenarios')); if (scenarios.length < 2) { comparison.appendChild(para('Duplicate a scenario to compare up to three independently edited estimates.')); return; }
    var select = node('select',null,{id:'bc-baseline'}); options(select,scenarios.map(function(s,i) { return [String(i),s.label || 'Scenario '+(i+1)]; }),String(baseline)); select.addEventListener('change',function () { baseline = Number(select.value); renderComparison(); }); append(comparison,node('label','Comparison baseline',{for:'bc-baseline'}),select);
    var evaluated = scenarios.map(function(s) { var evaluation = evaluate(s); if (evaluation.result && !evaluation.result.valid) evaluation.result = null; return evaluation; }), headers = ['Measure'].concat(scenarios.map(function(s,i) { return s.label || 'Scenario '+(i+1); }));
    var metrics = [['Monthly boating budget',function(r) { return r.readiness.monthly ? r.monthly.budget : null; }],['Upfront planning cash',function(r) { return r.upfront.planningCash; }],['First-year funding target',function(r) { return r.firstYear.funding; }],['Five-year cash spent',function(r) { return r.horizons.five ? r.horizons.five.cashSpent : null; }],['Lifetime loan interest',function(r) { return r.loan.totalInterest; }]];
    var rows = [['Readiness'].concat(evaluated.map(function(v) { return v.result && v.result.valid && v.result.readiness.monthly ? 'Monthly assumptions reviewed' : 'Incomplete — do not rank as cheaper'; }))];
    metrics.forEach(function(m) { var baseResult = evaluated[baseline].result, baseVal = baseResult ? m[1](baseResult) : null; rows.push([m[0]].concat(evaluated.map(function(v,i) { var val = v.result ? m[1](v.result) : null; return fmt(val)+(i === baseline ? ' (baseline)' : ' · '+delta(val,baseVal)+' vs baseline'); }))); });
    ['five','ten'].forEach(function(h,i) { if (evaluated.every(function(v) { return v.result && v.result.horizons[h] && v.result.horizons[h].netOwnershipCost != null; })) { rows.push(['Year '+(i ? 10 : 5)+' net ownership cost'].concat(evaluated.map(function(v) { return fmt(v.result.horizons[h].netOwnershipCost)+'; resale '+fmt(v.result.horizons[h].resaleValue)+'; selling '+fmt(v.result.horizons[h].sellingCosts); }))); } }); comparison.appendChild(table(headers,rows,'Scenario values and differences from your selected baseline')); comparison.appendChild(para('Each scenario retains its own inputs. Excluded costs and illustrative assumptions can differ. No scenario is ranked or recommended.','bc-note'));
  }
  function render() { var focusedId = document.activeElement && document.activeElement.id; renderToolbar(); renderForm(); renderResults(); renderComparison(); live.textContent = message; restoreControlFocus(focusedId); }
  window.addEventListener('beforeprint',function () {
    document.body.classList.add('boat-cost-printing');
    var rec = records[active];
    if (!rec || rec.stale || !rec.result || !rec.result.valid) {
      clear(results); var p = node('div',null,{class:'bc-panel'}); p.appendChild(node('h2','Estimate needs calculation')); p.appendChild(para('Calculate the active scenario with valid inputs before printing. No stale financial result is included.')); results.appendChild(p);
    }
  });
  window.addEventListener('afterprint',function () { document.body.classList.remove('boat-cost-printing'); renderResults(); });
  // Fixed placement metadata only; reuse the existing privacy/consent-aware helper.
  var ctaDestinations = {right_results:'trip_planner',fuel_help:'fuel_calculator',after_faq:'trip_planner'};
  document.addEventListener('click', function (event) {
    var target = event.target && event.target.closest ? event.target.closest('a[data-boat-cost-placement]') : null;
    if (!target) return;
    var placement = target.getAttribute('data-boat-cost-placement');
    if (Object.prototype.hasOwnProperty.call(ctaDestinations, placement)) {
      S.track('boat_cost_cta', {placement:placement,destination:ctaDestinations[placement]});
    }
  });
  document.querySelectorAll('[data-boat-cost-example]').forEach(function(b) { b.addEventListener('click',function () { loadExample(b.getAttribute('data-boat-cost-example')); mount.scrollIntoView({block:'start',behavior:'smooth'}); }); });
  function applyShared(fragment, initial) {
    var imported = S.parse(fragment);
    if (!imported.ok) { announce('The share link could not be validated. No figures were imported.'); if (!initial) track('boat_cost_error',{error_code:imported.error || 'invalid_share'}); return; }
    if (!initial && edited[active] && !window.confirm('Replace the edited active scenario with the shared figures? Browser-saved estimates will be unchanged.')) { announce('Shared figures were not applied. Current inputs are unchanged.'); return; }
    scenarios[active] = imported.scenario; edited[active] = false; var next = evaluate(scenarios[active]); records[active] = {result:next.result,solution:next.solution,stale:false,date:new Date()}; message = 'Shared scenario loaded. It has not replaced browser-saved estimates.';
  }
  function consumeUrlState() {
    var fragment = window.location.hash || '';
    if (!fragment && !window.location.search) return;
    clearTimeout(timer);
    try { window.history.replaceState(null,'',window.location.pathname); if (window.location.hash || window.location.search) throw new Error('URL cleanup failed'); }
    catch (error) { if (window.FPWBoatCostBootstrap) window.FPWBoatCostBootstrap.clean = false; window.FPWBoatCostAnalyticsReady = false; announce('The link could not be cleared from the address bar. Sharing and analytics are disabled.'); renderResults(); return; }
    if (fragment) applyShared(fragment,false);
    render();
  }
  window.addEventListener('hashchange',consumeUrlState);
  window.addEventListener('popstate',consumeUrlState);
  var boot = window.FPWBoatCostBootstrap;
  if (boot && boot.fragment) { var captured = boot.fragment; boot.fragment = ''; applyShared(captured,true); }
  render();
}());
