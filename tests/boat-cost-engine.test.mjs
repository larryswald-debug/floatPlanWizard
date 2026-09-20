import test from 'node:test';
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
const require = createRequire(import.meta.url);
const E = require('../assets/js/boat-cost-engine.js');
const entered = (value) => E.field(value, 'entered');
const unknown = () => E.field();
const excluded = () => E.field('', 'excluded');
const close = (actual, expected, message) => assert.ok(Math.abs(actual - expected) <= 0.01000001, `${message || ''}: ${actual} != ${expected}`);
function zeroCosts() {
  const s = E.createScenario();
  s.purchase.price = entered(12000); s.purchase.down.input = entered(0); s.purchase.rate = entered(0); s.purchase.term = entered(12); s.purchase.tax.input = entered(0);
  s.purchase.fees.forEach(row => { row.input = entered(0); });
  s.operating.fuel.annual = entered(0); s.operating.storage.total = entered(0);
  for (const key of ['insurance', 'maintenance', 'registration', 'seasonal']) s.operating[key] = entered(0);
  s.operating.other.total = entered(0); s.preparation.total = entered(0); s.reserves.initial = entered(0); s.reserves.annual = entered(0);
  return s;
}
function fixtureF() {
  const s = zeroCosts(); s.direction = 'budget'; s.purchase.price = unknown(); s.purchase.down.input = entered(10000); s.purchase.term = entered(120); s.operating.fuel.annual = entered(6000); s.reserves.annual = entered(1200); s.budget.monthly = entered(1000); s.budget.cash = entered(10000); return s;
}

test('Fixture A: zero interest and full payoff', () => {
  const r = E.calculate(zeroCosts());
  assert.equal(r.readiness.complete, true); assert.equal(r.loan.principal, 12000); assert.equal(r.loan.payment, 1000); assert.equal(r.loan.totalInterest, 0); assert.equal(r.loan.schedule.at(-1).balance, 0);
});

test('Fixture B: every purchase, annual, first-year and horizon value', () => {
  const s = E.example('B'); s.resale.five.value = entered(30000); s.resale.five.selling.input = entered(1500);
  const r = E.calculate(s);
  assert.deepEqual(r.errors, []); assert.equal(r.readiness.complete, true); assert.equal(r.readiness.resaleFive, true);
  const expected = [[r.loan.principal,40000],[r.loan.payment,485.31],[r.loan.totalInterest,18237.25],[r.operations.annual,10000],[r.monthly.expectedExpenses,1318.64],[r.monthly.repairSavings,100],[r.monthly.budget,1418.64],[r.upfront.purchaseCash,13500],[r.upfront.planningCash,17000],[r.firstYear.loanPayments,5823.72],[r.firstYear.spending,30823.72],[r.firstYear.funding,34023.72],[r.horizons.five.cashSpent,94118.62],[r.horizons.five.loanBalance,23934.75],[r.horizons.five.reserveAllocations,8000],[r.horizons.ten.cashSpent,173237.25],[r.horizons.ten.loanBalance,0],[r.horizons.ten.reserveAllocations,14000],[r.horizons.five.netOwnershipCost,89553.37]];
  expected.forEach(([actual,wanted])=>close(actual,wanted));
  const interestFive = r.loan.schedule.slice(0,60).reduce((sum,row)=>sum+row.interest,0);
  close(r.horizons.five.netOwnershipCost, 50000+3500+1500+5*10000+interestFive+1500-30000, 'Independent principal identity');
});

test('Fixture C: financed extras count only once', () => {
  const s = E.example('B'); s.purchase.tax.treatment = 'financed'; s.purchase.fees.forEach(row=>{row.treatment='financed';});
  const r = E.calculate(s); assert.equal(r.loan.principal,43500); assert.equal(r.upfront.purchaseCash,10000); close(r.loan.payment,527.78); assert.equal(r.accounting.Fc,0); assert.equal(r.accounting.Ff,3500);
});

test('Fixture D: combined propulsion GPH never multiplies by engine count', () => {
  const s = E.example('B'); s.profile.engineCount=2; s.operating.fuel.gph=entered(16);
  assert.equal(E.calculate(s).operations.breakdown[0].annual,8000);
  s.operating.fuel.generator={status:'entered',hours:entered(50),gph:entered(1),price:entered(5)};
  assert.equal(E.calculate(s).operations.breakdown[0].annual,8250);
  s.profile.engineCount=6; assert.equal(E.calculate(s).operations.breakdown[0].annual,8250);
});

test('Fixture E: seasonal storage annualizes each row exactly once', () => {
  const s = zeroCosts(); s.profile.length=28; s.profile.season='seasonal';
  s.operating.storage={mode:'details',total:unknown(),rows:[{type:'slip',basis:'perFoot',input:entered(20),months:6,billableFeet:30,startMonth:5},{type:'land',basis:'annual',input:entered(1200),months:'',billableFeet:'',startMonth:''}]};
  const r=E.calculate(s); assert.equal(r.operations.breakdown[1].annual,4800); assert.equal(r.operations.breakdown[1].monthly,400); assert.ok(r.warnings.some(w=>w.code==='storage-overlap'));
});

test('Fixture F: reverse monthly boundary and no feasible cash', () => {
  const s=fixtureF(); const r=E.solveBudget(s);
  assert.equal(r.status,'solved'); assert.equal(r.price,58000); assert.equal(r.nextCentFails,true); assert.equal(r.result.monthly.budget,1000); assert.equal(r.result.upfront.planningCash,10000); assert.equal(r.monthlyHeadroom,0);
  const next=E.cloneScenario(r.scenario);next.purchase.price=entered(58000.01);assert.ok(E.calculate(next).monthly.budget>1000);
  s.budget.cash=entered(5000);const bad=E.solveBudget(s);assert.equal(bad.status,'no-feasible');assert.equal(bad.cashShortfall,5000);
});

test('Fixture G: cash purchase bounded by cash with percentage tax', () => {
  const s=fixtureF();s.purchase.method='cash';s.purchase.rate=unknown();s.purchase.term=unknown();s.purchase.tax.mode='percent';s.purchase.tax.input=entered(6);s.preparation.total=entered(1000);s.reserves.initial=entered(2000);s.budget.cash=entered(25000);
  const r=E.solveBudget(s);assert.equal(r.status,'solved');assert.equal(r.price,20754.72);assert.equal(r.result.accounting.Fc,1245.28);assert.equal(r.result.upfront.planningCash,25000);assert.equal(r.result.monthly.budget,600);assert.equal(r.nextCentFails,true);
});

test('Fixtures H and I and public example B are complete illustrative packs', () => {
  const cases={H:[5250,242.66,730.16,18561.86,1000],B:[10000,485.31,1418.64,34023.72,1500],I:[27000,764.52,3264.52,76174.26,5000]};
  for(const [key,expected]of Object.entries(cases)){
    const s=E.example(key),r=E.calculate(s);assert.equal(r.readiness.complete,true);assert.equal(s.origin,'example');assert.ok(r.illustrativePaths.length>10);assert.ok(r.exclusions.some(x=>x.path==='operating.other.total'));
    [r.operations.annual,r.loan.payment,r.monthly.budget,r.firstYear.funding,r.upfront.preparation].forEach((value,i)=>close(value,expected[i]));
    assert.equal(r.horizons.five.netOwnershipCost,null);assert.equal(r.horizons.ten.netOwnershipCost,null);
  }
});

test('Blank startup never returns a fabricated complete zero',()=>{
  const s=E.createScenario(),r=E.calculate(s);assert.equal(r.valid,true);assert.equal(r.readiness.complete,false);assert.equal(r.monthly.budget,null);assert.equal(r.monthly.label,'Known monthly costs so far');assert.ok(r.missing.length>0);
});

test('Unknown, entered zero, illustrative, and excluded remain distinct',()=>{
  const s=zeroCosts();s.operating.insurance=unknown();s.operating.maintenance=excluded();s.operating.registration=E.field(0,'illustrative');
  const r=E.calculate(s);assert.equal(r.readiness.loan,true);assert.equal(r.readiness.operations,false);assert.equal(r.monthly.budget,null);assert.equal(r.operations.breakdown.find(x=>x.key==='insurance').annual,null);assert.equal(r.operations.breakdown.find(x=>x.key==='maintenance').annual,0);assert.ok(r.exclusions.some(x=>x.path==='operating.maintenance'));assert.ok(r.illustrativePaths.includes('operating.registration'));
  s.operating.insurance=entered(0);assert.equal(E.calculate(s).readiness.complete,true);
  s.operating.insurance=E.field(10000,'unknown');assert.equal(E.calculate(s).operations.knownAnnual,0);
  s.operating.insurance=entered('');assert.equal(E.calculate(s).readiness.operations,false);
});

test('Unknown financed extras block loan; unknown cash extras only block acquisition',()=>{
  const s=E.example('B');s.purchase.tax.input=unknown();let r=E.calculate(s);assert.equal(r.readiness.loan,true);assert.equal(r.readiness.monthly,true);assert.equal(r.readiness.purchaseCash,false);assert.equal(r.readiness.firstYear,false);
  s.purchase.tax.treatment='financed';r=E.calculate(s);assert.equal(r.readiness.loan,false);assert.equal(r.loan.principal,null);assert.equal(r.readiness.purchaseCash,true);
});

test('Cash ignores financing flags and makes all extras cash-paid',()=>{
  const s=E.example('B');s.purchase.method='cash';s.purchase.tax.treatment='financed';s.purchase.fees.forEach(row=>{row.treatment='financed';});s.purchase.rate=unknown();s.purchase.term=unknown();
  const r=E.calculate(s);assert.equal(r.loan.payment,0);assert.equal(r.loan.principal,0);assert.equal(r.upfront.purchaseCash,53500);assert.equal(r.accounting.Ff,0);assert.equal(r.horizons.five.loanBalance,0);
});

test('100% down needs no rate/term unless purchase extras financed',()=>{
  const s=E.example('B');s.purchase.down.mode='percent';s.purchase.down.input=entered(100);s.purchase.rate=unknown();s.purchase.term=unknown();let r=E.calculate(s);assert.equal(r.loan.payment,0);assert.equal(r.readiness.loan,true);
  s.purchase.tax.treatment='financed';r=E.calculate(s);assert.equal(r.loan.principal,3000);assert.equal(r.readiness.loan,false);
});

test('Zero hours permits unknown GPH/price without a hidden engine multiplier',()=>{
  const s=E.example('B');s.operating.fuel.hours=entered(0);s.operating.fuel.gph=unknown();s.operating.fuel.price=unknown();const r=E.calculate(s);assert.equal(r.readiness.operations,true);assert.equal(r.operations.breakdown[0].annual,0);
});

test('Fuel modes ignore inactive values and preserve original raw state',()=>{
  const s=E.example('B');s.operating.fuel.annual=entered(1200);const before=JSON.stringify(s);assert.equal(E.calculate(s).operations.breakdown[0].annual,4000);assert.equal(JSON.stringify(s),before);
  s.operating.fuel.mode='annual';assert.equal(E.calculate(s).operations.breakdown[0].annual,1200);s.operating.fuel.mode='usage';assert.equal(E.calculate(s).operations.breakdown[0].annual,4000);
});

test('Preparation included elsewhere is counted once and disclosed',()=>{
  const s=E.example('B');s.preparation.rows[0].includedElsewhere=true;const r=E.calculate(s);assert.equal(r.upfront.preparation,900);assert.ok(r.exclusions.some(x=>x.label.includes('already included elsewhere')));
});

test('Loan payoff caps horizon payments and full precision preserves interest',()=>{
  const s=E.example('B');s.purchase.term=entered(12);const r=E.calculate(s);assert.equal(r.horizons.five.loanBalance,0);assert.equal(r.horizons.ten.loanBalance,0);close(r.firstYear.loanPayments,r.loan.totalPayments);close(r.horizons.ten.cashSpent-r.horizons.five.cashSpent,5*r.operations.annual);assert.ok(Math.abs(E.displayRound(r.loan.payment)*12-r.loan.totalPayments)>0.001);
});

test('Tiny positive rate is stable and tends continuously to zero interest',()=>{
  const exact=E.loanSchedule(12000,0,120);for(const rate of [1e-12,1e-10,0.000001]){const r=E.loanSchedule(12000,rate,120);assert.ok(Number.isFinite(r.payment));assert.ok(r.payment>=exact.payment);assert.ok(r.totalInterest>=0);close(r.payment,100);assert.equal(r.schedule.at(-1).balance,0);}
});

test('Principal, rate, fuel and down-payment monotonicity',()=>{
  for(let i=1;i<=20;i++){
    const principal=i*1234.56;const base=E.loanSchedule(principal,8,120),higher=E.loanSchedule(principal+100,8,120),rate=E.loanSchedule(principal,9,120),short=E.loanSchedule(principal,8,60);
    assert.ok(higher.payment>base.payment);assert.ok(rate.payment>base.payment);assert.ok(short.payment>base.payment);assert.ok(short.totalInterest<base.totalInterest);assert.equal(base.schedule.at(-1).balance,0);close(base.schedule.reduce((sum,row)=>sum+row.principal,0),principal);
  }
  const s=E.example('B'),base=E.calculate(s);s.purchase.down.input=entered(11000);const down=E.calculate(s);assert.ok(down.loan.payment<base.loan.payment);assert.ok(down.loan.totalInterest<base.loan.totalInterest);s.operating.fuel.hours=entered(110);assert.ok(E.calculate(s).operations.annual>base.operations.annual);
});

test('Half-up normalization for percentage down, tax, storage and selling charges',()=>{
  const s=zeroCosts();s.purchase.price=entered(1);s.purchase.down={mode:'percent',input:entered(0.5)};s.purchase.tax={mode:'percent',input:entered(0.5),treatment:'cash'};
  s.profile.length=1;s.operating.storage={mode:'details',total:unknown(),rows:[{type:'slip',basis:'perFoot',input:entered(0.01),months:1,billableFeet:1.5,startMonth:1}]};s.resale.five.value=entered(1);s.resale.five.selling={mode:'percent',input:entered(0.5)};
  const r=E.calculate(s);assert.equal(r.accounting.D,0.01);assert.equal(r.accounting.Fc,0.01);assert.equal(r.loan.principal,0.99);assert.equal(r.operations.annual,0.02);assert.equal(r.horizons.five.sellingCosts,0.01);
});

test('Annual and monthly storage equivalents match and seasonal profile changes no prices',()=>{
  const s=zeroCosts();s.operating.storage={mode:'details',total:unknown(),rows:[{type:'slip',basis:'monthly',input:entered(123.45),months:12,billableFeet:'',startMonth:1}]};const before=E.calculate(s);assert.equal(before.operations.annual,1481.4);s.profile.season='seasonal';assert.equal(E.calculate(s).operations.annual,1481.4);s.operating.storage.rows[0].basis='annual';s.operating.storage.rows[0].input=entered(1481.4);assert.equal(E.calculate(s).operations.annual,1481.4);
});

test('Per-foot storage requires physical and billable lengths',()=>{
  const s=zeroCosts();s.operating.storage={mode:'details',total:unknown(),rows:[{type:'slip',basis:'perFoot',input:entered(20),months:6,billableFeet:30,startMonth:''}]};let r=E.calculate(s);assert.equal(r.readiness.operations,false);assert.ok(r.missing.some(x=>x.path==='profile.length'));s.profile.length=28;s.operating.storage.rows[0].billableFeet='';r=E.calculate(s);assert.equal(r.readiness.operations,false);assert.ok(r.missing.some(x=>x.path.endsWith('billableFeet')));
});

test('No feasible monthly budget reports recurring shortfall',()=>{
  const s=fixtureF();s.budget.monthly=entered(599.99);const r=E.solveBudget(s);assert.equal(r.status,'no-feasible');close(r.monthlyShortfall,0.01);
});

test('Reverse unknowns block completeness and missing future rate cannot masquerade as ceiling',()=>{
  const s=fixtureF();s.operating.insurance=unknown();assert.equal(E.solveBudget(s).status,'incomplete');s.operating.insurance=entered(0);s.purchase.rate=unknown();s.purchase.term=unknown();const r=E.solveBudget(s);assert.equal(r.status,'incomplete');assert.ok(r.missing.some(x=>x.path==='purchase.rate'));assert.equal(r.price,null);
});

test('Reverse supported maximum is explicitly open ended',()=>{
  const s=zeroCosts();s.direction='budget';s.purchase.method='cash';s.budget.monthly=entered(1000000);s.budget.cash=entered(20000000);const r=E.solveBudget(s);assert.equal(r.status,'maximum');assert.equal(r.price,5000000);assert.equal(r.nextCentFails,null);
});

test('Reverse percent down and tax forward-validate at every returned cent boundary',()=>{
  for(const down of [0,5,20,100]){
    const s=fixtureF();s.purchase.down={mode:'percent',input:entered(down)};s.purchase.rate=entered(8);s.purchase.tax={mode:'percent',input:entered(6.125),treatment:'cash'};s.budget.cash=entered(12000);s.budget.monthly=entered(1600);
    const r=E.solveBudget(s);assert.equal(r.status,'solved');assert.ok(r.result.monthly.budget<=1600);assert.ok(r.result.upfront.planningCash<=12000);assert.equal(r.nextCentFails,true);
  }
});

test('Resale needs explicit selling costs and reserves never enter economic cost',()=>{
  const s=E.example('B');s.resale.five.value=entered(30000);s.resale.five.selling.input=excluded();let r=E.calculate(s);assert.equal(r.horizons.five.netOwnershipCost,null);s.resale.five.selling.input=entered(0);r=E.calculate(s);assert.equal(r.readiness.resaleFive,true);const net=r.horizons.five.netOwnershipCost;s.reserves.initial=entered(50000);s.reserves.annual=entered(100000);assert.equal(E.calculate(s).horizons.five.netOwnershipCost,net);s.resale.five.value=entered(10000000);assert.ok(E.calculate(s).warnings.some(x=>x.code==='negative-net-cost'));
});

test('Insight percentages suppress zero denominator and used warning preserves fuel/term insights',()=>{
  const s=zeroCosts();s.purchase.method='cash';const r=E.calculate(s);assert.equal(r.insights.some(x=>x.type==='largest'),false);assert.ok(r.insights.every(x=>!Number.isNaN(x.share)));
  const b=E.example('B');b.reserves.initial=entered(0);b.reserves.annual=entered(0);const x=E.calculate(b);assert.ok(x.warnings.some(w=>w.code==='used-boat'));assert.deepEqual(x.insights.map(i=>i.type),['terms','largest','fuel']);assert.equal(x.insights.find(i=>i.type==='fuel').annualIncrease,1000);
});

test('Strict parsing accepts grouped dollar paste and rejects hostile/malformed inputs',()=>{
  assert.equal(E.parseMoney(' $1,234,567.89 ').cents,123456789);assert.equal(E.parseMoney('0').cents,0);
  for(const value of ['1,23.45','1.234','$-1','-1','NaN','Infinity','1e999','<script>alert(1)</script>','12 dollars','1.00.00',NaN,Infinity,-1,{},[],null]) assert.ok(E.parseMoney(value).error,String(value));
});

test('Numeric bounds, enums, object allowlists and row count limits reject imports',()=>{
  const cases=[s=>s.purchase.price.value=5000000.01,s=>s.purchase.price.value=0.99,s=>s.purchase.down.input.value=13000,s=>s.purchase.rate.value=40.00001,s=>s.purchase.term.value=11,s=>s.purchase.term.value=240.5,s=>s.purchase.tax={mode:'percent',input:entered(30.01),treatment:'cash'},s=>s.profile.length=200.01,s=>s.profile.engineCount=7,s=>s.profile.year=1899,s=>s.operating.fuel.gph.value=500.1,s=>s.operating.fuel.hours.value=8761,s=>s.operating.fuel.price.value=50.01,s=>s.operating.insurance.value=5000000.01,s=>s.reserves.initial.value=-1,s=>s.budget.monthly.value=1000000.01,s=>s.budget.cash.value=20000000.01,s=>s.resale.five.value.value=10000000.01,s=>s.label='<img src=x onerror=alert(1)>',s=>s.label='a'.repeat(61),s=>s.purchase.state='test@example.com',s=>s.extra=1,s=>s.purchase.rate.extra=1,s=>s.version=2,s=>s.view='unsupported',s=>s.purchase.method='lease',s=>s.purchase.fees.push(s.purchase.fees[0]),s=>s.preparation.rows.pop(),s=>s.operating.other.rows=[{type:'other',input:entered(1)},{type:'other',input:entered(2)}]];
  for(const mutate of cases){const s=zeroCosts();mutate(s);assert.equal(E.validateScenario(s).valid,false,mutate.toString());assert.equal(E.calculate(s).valid,false);}
  for(const bad of [null,[],{},'bad',Object.assign(E.createScenario(),{purchase:null})])assert.equal(E.validateScenario(bad).valid,false);
});

test('All exact supported boundaries validate',()=>{
  const s=zeroCosts();s.purchase.price=entered(5000000);s.purchase.down={mode:'percent',input:entered(100)};s.purchase.rate=entered(40);s.purchase.term=entered(240);s.purchase.tax={mode:'percent',input:entered(30),treatment:'cash'};s.profile.year=2028;s.profile.length=200;s.profile.engineCount=6;s.purchase.state='FL';s.budget.monthly=entered(1000000);s.budget.cash=entered(20000000);s.resale.five.value=entered(10000000);s.resale.five.selling={mode:'percent',input:entered(100)};assert.equal(E.validateScenario(s,{referenceYear:2026}).valid,true);s.profile.year=2029;assert.equal(E.validateScenario(s,{referenceYear:2026}).valid,false);assert.equal(E.validateScenario(s,{referenceYear:2027}).valid,true);
});

test('Derived annual storage and fuel overflow are explicit errors',()=>{
  const s=zeroCosts();s.operating.fuel.mode='usage';s.operating.fuel.hours=entered(8760);s.operating.fuel.gph=entered(500);s.operating.fuel.price=entered(50);let r=E.calculate(s);assert.equal(r.valid,false);assert.ok(r.errors.some(e=>e.code==='annual-cost-limit'));
  s.operating.fuel.mode='annual';s.operating.storage={mode:'details',total:unknown(),rows:[{type:'slip',basis:'monthly',input:entered(5000000),months:12,billableFeet:'',startMonth:1}]};r=E.calculate(s);assert.equal(r.valid,false);assert.ok(r.errors.some(e=>e.code==='annual-cost-limit'));
});

test('Cloning and pure calculation never mutate shared or example scenarios',()=>{
  const s=E.example('B');const before=JSON.stringify(s);const clone=E.cloneScenario(s);clone.purchase.price.value=12345;clone.preparation.rows[0].input.value=0;assert.equal(JSON.stringify(s),before);E.calculate(s);assert.equal(JSON.stringify(s),before);assert.equal(E.example('B').purchase.price.value,50000);
});

test('Display reconciliation retains the model and balances tiny and partial rows',()=>{
  const s=zeroCosts();s.purchase.method='cash';s.operating.fuel.annual=entered(0.05);s.operating.storage.total=entered(0.05);s.operating.insurance=entered(0.05);s.operating.maintenance=entered(0.05);s.operating.registration=entered(0.05);s.operating.seasonal=entered(0.05);s.operating.other.total=entered(0.05);s.reserves.annual=entered(0.05);
  function assertReconciles(r) {
    const rows=r.operations.breakdown.reduce((sum,row)=>sum+E.displayRound(row.knownAnnual/12),0)+E.displayRound(r.loan.payment||0)+E.displayRound(r.monthly.repairSavings||0)+r.monthly.roundingAdjustment;
    close(rows,E.displayRound(r.monthly.knownCosts));assert.equal(E.displayRound(rows),E.displayRound(r.monthly.knownCosts));
  }
  let r=E.calculate(s);assert.equal(r.monthly.roundingAdjustment,0.03);assertReconciles(r);
  s.operating.storage={mode:'details',total:unknown(),rows:[{type:'land',basis:'annual',input:entered(0.05),months:'',billableFeet:'',startMonth:''},{type:'slip',basis:'annual',input:unknown(),months:'',billableFeet:'',startMonth:''}]};r=E.calculate(s);assert.equal(r.readiness.monthly,false);assertReconciles(r);
});

test('Upfront cent accounting does not lose a feasible cash boundary to binary floating error',()=>{
  const s=zeroCosts();s.direction='budget';s.purchase.method='cash';s.purchase.tax.input=entered(0.1);s.preparation.total=entered(0.2);s.budget.cash=entered(1.3);s.budget.monthly=entered(0);const r=E.solveBudget(s);assert.equal(r.status,'solved');assert.equal(r.price,1);assert.equal(r.result.upfront.planningCash,1.3);assert.equal(r.nextCentFails,true);
});

test('Subnormal positive interest and penny principal do not underflow the payment',()=>{
  for(const rate of [Number.MIN_VALUE,1e-320,1e-300,1e-20]) {
    const r=E.loanSchedule(0.01,rate,120);assert.ok(r.payment>0);assert.ok(Number.isFinite(r.payment));assert.ok(Math.abs(r.payment-0.01/120)<1e-14);assert.equal(r.schedule.at(-1).balance,0);close(r.totalPayments,0.01);
  }
});

test('Generator group illustrative status propagates even with entered numeric subfields',()=>{
  const s=zeroCosts();s.operating.fuel.mode='usage';s.operating.fuel.hours=entered(0);s.operating.fuel.generator={status:'illustrative',hours:entered(50),gph:entered(1),price:entered(5)};
  let r=E.calculate(s);assert.equal(r.operations.breakdown[0].annual,250);assert.equal(r.operations.breakdown[0].status,'illustrative');assert.ok(r.illustrativePaths.includes('operating.fuel.generator'));
  s.operating.fuel.generator.hours=entered(0);r=E.calculate(s);assert.equal(r.operations.breakdown[0].annual,0);assert.equal(r.operations.breakdown[0].status,'illustrative');assert.ok(r.illustrativePaths.includes('operating.fuel.generator'));
});

test('Other purchase fee exclusions are separate from other operating costs',()=>{
  const r=E.calculate(E.example('B'));assert.equal(r.exclusions.find(x=>x.path==='purchase.fees.3.input').label,'Other purchase fee');assert.equal(r.exclusions.find(x=>x.path==='operating.other.total').label,'other operating costs');
});
