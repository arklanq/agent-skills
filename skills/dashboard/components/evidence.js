/* Evidence-first layout extracted from real dashboard use. No project data. */
window.DashboardComponents=window.DashboardComponents||{};
(function(C){
'use strict';
const el=(...args)=>C.element(...args), t=(...args)=>C.t(...args);
function context(state){
  const tasks = state.tasks || [], ms = state.milestones || [], changed = state.changedIds || [];
  const byId = id => tasks.find(t => t.id === id);
  const labels = Object.fromEntries(['todo', 'doing', 'done', 'blocked', 'unknown'].map(s => [s, t('status.' + s)]));
  const norm = s => Object.hasOwn(labels, s) ? s : 'unknown';
  const changedSet = new Set(changed);
  const showChanged = tasks.some(t => changedSet.has(t.id)) && tasks.some(t => !changedSet.has(t.id));
  const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
  function stageStatus(ids) {
    const rows = ids.map(byId);
    if (!rows.length) return 'unknown';
    if (rows.every(t => t?.status === 'done')) return 'done';
    if (rows.some(t => t?.status === 'doing')) return 'doing';
    if (rows.some(t => t?.status === 'blocked')) return 'blocked';
    if (rows.some(t => t?.status === 'done')) return 'doing';
    if (rows.some(t => !t || t.status === 'unknown')) return 'unknown';
    return 'todo';
  }
  const fmt = iso => { const d = new Date(iso); return isNaN(d) ? '' : d.toLocaleString(C.locale(), {day: '2-digit', month: '2-digit', hour: '2-digit', minute: '2-digit'}); };

  return {tasks,ms,changed,byId,labels,norm,showChanged,reduce,stageStatus,fmt};
}
C.evidenceMap=function(state){
const {tasks,ms,changed,byId,labels,norm,showChanged,reduce,stageStatus,fmt}=context(state);

  const stages = ms.length ? ms.map(m => ({...m, status: stageStatus(m.taskIds || [])}))
    : tasks.map(t => ({id: t.id, title: t.title, taskIds: [t.id], status: norm(t.status)}));
  const currentIdx = stages.findIndex(s => s.status !== 'done');
  const map = el('div', null, 'ad-map');
  const sec = el('section', null, 'roadmap-section'); sec.setAttribute('aria-label', t('map.label'));
  if (stages.length) {
    const list = el('ol', null, 'roadmap'); list.style.setProperty('--stages', stages.length);
    stages.forEach((st, i) => {
      const s = norm(st.status), ids = st.taskIds || [];
      const isCur = i === currentIdx && (s === 'doing' || s === 'blocked');
      const item = el('li', null, 'stage stage-' + s + (st.proposed ? ' stage-proposed' : '') + (isCur && s === 'doing' ? ' is-current' : '') + (isCur && s === 'blocked' ? ' is-waiting' : ''));
      if (isCur) {
        item.append(el('span', s === 'blocked' ? t('map.waiting') : t('map.current'), 'you-are-here' + (s === 'blocked' ? ' marker-blocked' : '')));
        item.setAttribute('aria-current', 'step');
      }
      const node = el('button', s === 'done' ? '✓' : s === 'blocked' ? '!' : '', 'stage-node'); node.type = 'button';
      node.disabled = !ids.some(id => byId(id));
      node.setAttribute('aria-label', t('map.stageAction', {title: st.title, status: labels[s]}));
      node.addEventListener('click', () => { const target = document.getElementById(ms.length ? 'ledger-stage-' + encodeURIComponent(st.id) : 'ledger-task-' + encodeURIComponent(st.id)); if (target) { target.scrollIntoView({behavior: reduce ? 'instant' : 'smooth', block: 'start'}); target.focus({preventScroll: true}); } });
      item.append(node, el('h2', st.title, 'stage-title'), el('p', labels[s] + (st.proposed ? ' · ' + t('proposal.agent') : ''), 'stage-status'));
      if (ids.length) item.append(el('p', t('map.stageDone', {done: ids.filter(id => byId(id)?.status === 'done').length, total: ids.length}), 'stage-count'));
      list.append(item);
    });
    sec.append(list);
  } else sec.append(el('p', t('map.empty'), 'empty'));
  map.append(sec);
  const nextMs = ms.find(m => !(m.taskIds || []).length || (m.taskIds || []).some(id => byId(id)?.status !== 'done'));
  if (nextMs) {
    const rem = (nextMs.taskIds || []).filter(id => byId(id)?.status !== 'done');
    const row = el('div', null, 'milestone-remaining'), lab = el('div', null, 'remaining-label');
    lab.append(el('strong', rem.length ? String(rem.length) : '—'), el('span', t(rem.length ? 'map.left' : 'map.scopeUnknown', {title: nextMs.title}) + (nextMs.proposed ? ' · ' + t('proposal') : '')));
    const chips = el('div', null, 'remaining-chips');
    rem.forEach(id => { const t = byId(id); chips.append(el('span', t?.title || id, 'task-chip chip-' + norm(t?.status))); });
    row.append(lab, chips); map.append(row);
  } else if (ms.length) map.append(el('p', t('map.allDone'), 'milestone-complete'));
  return map;

};
C.evidenceLedger=function(state){
const {tasks,ms,changed,byId,labels,norm,showChanged,reduce,stageStatus,fmt}=context(state);

  const board = el('section', null, 'main-column board-panel');
  const head = el('div', null, 'section-heading');
  head.append(el('h2', t('ledger.title'), 'eyebrow'));
  const cnt = el('span', null, 'section-count'); const [before, after = ''] = t('ledger.count', {total: tasks.length}).split('{done}'); cnt.append(before, el('strong', String(tasks.filter(task => task.status === 'done').length)), after);
  head.append(cnt); board.append(head);
  const groups = ms.map((m, i) => ({id: 'stage-' + encodeURIComponent(m.id), num: String(i + 1).padStart(2, '0'), title: m.title, proposed: m.proposed, rows: (m.taskIds || []).map(id => byId(id) || {id, title: id, status: 'unknown'})}));
  const used = new Set(ms.flatMap(m => m.taskIds || []));
  const loose = tasks.filter(t => !used.has(t.id));
  if (loose.length) groups.push({id: 'loose', num: '··', title: ms.length ? t('ledger.outside') : t('ledger.tasks'), rows: loose});
  const anchored = new Set();
  groups.forEach(g => {
    const s = el('section', null, 'ledger-stage'); s.id = 'ledger-' + g.id; s.dataset.key = 'stage:' + g.id; s.tabIndex = -1;
    const h = el('div', null, 'ledger-head');
    h.append(el('span', g.num, 'ledger-num'), el('h3', g.title));
    if (g.proposed) h.append(el('span', t('proposal'), 'tag'));
    const done = g.rows.filter(row => row.status === 'done').length;
    h.append(el('span', g.rows.length ? t('map.stageDone', {done, total: g.rows.length}) : t('ledger.scopeUnset'), 'ledger-count' + (g.rows.length && done === g.rows.length ? ' all-done' : '')));
    s.append(h);
    const ul = el('ul', null, 'ledger-rows');
    g.rows.forEach(task => {
      const st = norm(task.status), ch = showChanged && changed.includes(task.id);
      const li = el('li', null, 'lrow r-' + st + (ch ? ' is-changed' : '')); li.dataset.key = 'task:' + task.id; if(!anchored.has(task.id)) li.id = 'ledger-task-' + encodeURIComponent(task.id); anchored.add(task.id); li.tabIndex = -1;
      const icon = el('span', st === 'done' ? '✓' : st === 'blocked' ? '!' : st === 'doing' ? '…' : '', 'licon'); icon.setAttribute('aria-hidden', 'true');
      const top = el('div', null, 'ltop');
      top.append(el('span', task.title, 'ltitle'), el('span', labels[st], 'status status-' + st));
      if (task.panel) top.append(el('span', task.panel, 'lpanel'));
      if (ch) top.append(el('span', t('ledger.changed'), 'lchanged'));
      li.append(icon, top);
      if (task.blocker && st !== 'done') { const p = el('p', null, 'lnote blocker'); p.append(el('span', t('ledger.blocker'), 'k'), task.blocker); li.append(p); }
      if (task.evidence) { const p = el('p', null, 'lnote'); p.append(el('span', t('ledger.evidence'), 'k'), task.evidence); li.append(p); }
      if (!(task.blocker && st !== 'done') && !task.evidence) li.append(el('p', st === 'todo' ? t('ledger.notStarted') : t('ledger.noDetails'), 'lnote none'));
      ul.append(li);
    });
    s.append(ul); board.append(s);
  });
  if (!groups.length) board.append(el('p', t('ledger.empty'), 'empty'));

  return board;
};
C.priorityPanels=function(state){
const {tasks,ms,changed,byId,labels,norm,showChanged,reduce,stageStatus,fmt}=context(state);

  const aside = el('aside', null, 'side-column');
  const decisions = [...(state.decisions || [])].sort((a, b) => (b.blocking ? 1 : 0) - (a.blocking ? 1 : 0));
  decisions.forEach(d => {
    const p = el('section', null, 'side-panel decision' + (d.blocking ? ' decision-blocking' : ''));
    p.append(el('h2', d.blocking ? t('decision.needed') : t('decision.open'), 'eyebrow'), el('h3', d.title, 'decision-title'));
    if (d.default) p.append(el('p', t('decision.agentDefault', {text: d.default})));
    p.append(el('p', d.blocking ? t('decision.ask') : t('decision.nonBlocking'), d.blocking ? 'decision-ask' : 'muted'));
    aside.append(p);
  });
  if (state.now || state.next) {
    const p = el('section', null, 'side-panel direction-panel');
    p.append(el('h2', t('now.title'), 'eyebrow'), el('p', state.now || t('now.waiting'), 'current-work'));
    if (state.next) { const n = el('div', null, 'next-step'); n.append(el('h3', t('next.title'), 'eyebrow'), el('p', state.next)); p.append(n); }
    aside.append(p);
  }
  if ((state.events || []).length) {
    const p = el('section', null, 'side-panel activity'); p.append(el('h2', t('events.title'), 'eyebrow'));
    const ol = el('ol');
    state.events.slice(-6).reverse().forEach(ev => { const li = el('li'); li.append(el('span', null, 'event-dot'), el('span', ev.text)); if (ev.at) { const tm = el('time', fmt(ev.at)); tm.dateTime = ev.at; li.append(tm); } ol.append(li); });
    p.append(ol); aside.append(p);
  }
  return aside;
};
})(window.DashboardComponents);
