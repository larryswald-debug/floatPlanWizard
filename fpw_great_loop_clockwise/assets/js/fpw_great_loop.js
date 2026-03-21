(function(){
  'use strict';

  const $ = (sel, root=document)=> root.querySelector(sel);
  const $$ = (sel, root=document)=> Array.from(root.querySelectorAll(sel));

  const sections = $$('.section');
  const search = $('#search');
  const expandAllBtn = $('#expandAll');
  const collapseAllBtn = $('#collapseAll');
  const clearBtn = $('#clearSearch');
  const visibleCount = $('#visibleCount');
  const totalCount = $('#totalCount');

  function setOpen(section, open){
    section.dataset.open = open ? 'true' : 'false';
  }

  sections.forEach(sec=>{
    const header = $('.sectionHeader', sec);
    header.addEventListener('click', (e)=>{
      // Don't toggle when user clicks a link/button inside header (none today, but future-safe).
      if (e.target && (e.target.closest('button') || e.target.closest('a'))) return;
      setOpen(sec, sec.dataset.open !== 'true');
    });
  });

  function applySearch(){
    const q = (search.value || '').trim().toLowerCase();
    let shown = 0;

    sections.forEach(sec=>{
      let sectionHasHit = false;
      const legs = $$('.legCard', sec);

      legs.forEach(card=>{
        const text = card.getAttribute('data-search') || '';
        const hit = !q || text.includes(q);
        card.style.display = hit ? '' : 'none';
        if (hit) sectionHasHit = true;
      });

      sec.style.display = sectionHasHit ? '' : 'none';
      if (sectionHasHit) shown += $$('.legCard', sec).filter(c=>c.style.display !== 'none').length;

      // If searching, auto-open matching sections for usability
      if (q && sectionHasHit) setOpen(sec, true);
    });

    visibleCount.textContent = shown.toString();
  }

  function countTotals(){
    const total = $$('.legCard').length;
    totalCount.textContent = total.toString();
    visibleCount.textContent = total.toString();
  }

  search.addEventListener('input', applySearch);
  clearBtn.addEventListener('click', ()=>{
    search.value = '';
    applySearch();
    search.focus();
  });

  expandAllBtn.addEventListener('click', ()=>{
    sections.forEach(sec=>{ if (sec.style.display !== 'none') setOpen(sec,true); });
  });

  collapseAllBtn.addEventListener('click', ()=>{
    sections.forEach(sec=>setOpen(sec,false));
  });

  // Default: open the first 2 sections for quick scan
  sections.forEach((sec, i)=> setOpen(sec, i < 2));

  countTotals();
})();
