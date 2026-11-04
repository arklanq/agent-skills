/* Reusable work views. All supplied content is rendered as text. */
window.DashboardComponents = window.DashboardComponents || {};
(function (C) {
  const STATUSES = ['todo', 'doing', 'done', 'blocked', 'unknown'];
  const t = (...args) => C.t(...args);
  const el = (tag, text, cls) => { const node = document.createElement(tag); if (text != null) node.textContent = String(text); if (cls) node.className = cls; return node; };
  C.element = el;
  C.status = function (status) { const known = STATUSES.includes(status) ? status : 'unknown'; return el('span', t('status.' + known), 'status status-' + known); };
  C.milestone = function (milestone, tasks) {
    const section = el('section', null, 'milestone');
    const matched = tasks.filter(task => milestone.taskIds.includes(task.id));
    const done = matched.filter(task => task.status === 'done').length;
    const remaining = milestone.taskIds.length - done;
    section.append(el('h2', milestone.title + (milestone.proposed ? ' · ' + t('proposal') : '')));
    section.append(el('p', milestone.taskIds.length ? t('milestone.progress', {remaining, done, total: milestone.taskIds.length}) : t('milestone.unassigned'), 'muted'));
    if (milestone.taskIds.length) { const meter = el('progress'); meter.max = milestone.taskIds.length; meter.value = done; meter.setAttribute('aria-label', t('milestone.meter')); section.append(meter); }
    return section;
  };
  C.taskList = function (tasks, changedIds = []) {
    const list = el('div', null, 'task-list');
    tasks.forEach(task => {
      const row = el('details', null, 'task' + (changedIds.includes(task.id) ? ' changed' : ''));
      row.dataset.key = 'task:' + task.id;
      const summary = el('summary');
      summary.append(C.status(task.status), el('span', task.title, 'task-title'));
      if (changedIds.includes(task.id)) summary.append(el('span', t('task.updated'), 'updated-mark'));
      row.append(summary);
      const body = el('div', null, 'task-body');
      if (task.blocker) body.append(el('p', t('task.blockerLine', {text: task.blocker}), 'blocker'));
      if (task.evidence) body.append(el('p', t('task.evidenceLine', {text: task.evidence})));
      if (!task.blocker && !task.evidence) body.append(el('p', t('ledger.noDetails'), 'muted'));
      row.append(body); list.append(row);
    });
    return list;
  };
  C.decisions = function (decisions) {
    const section = el('section', null, 'decisions'); section.append(el('h2', t('decision.title')));
    decisions.forEach(decision => {
      const item = el('div', null, 'decision');
      item.append(el('h3', decision.title));
      if (decision.default) item.append(el('p', t('decision.default', {text: decision.default})));
      item.append(el('p', decision.blocking ? t('decision.waiting') : t('decision.nonBlocking'), 'muted'));
      section.append(item);
    }); return section;
  };
  C.activity = function (events) {
    const section = el('section', null, 'activity'); section.append(el('h2', t('events.title')));
    const list = el('ol');
    events.slice(-8).reverse().forEach(event => { const item = el('li'); const time = el('time', event.at ? new Date(event.at).toLocaleTimeString(C.locale(), {hour:'2-digit', minute:'2-digit'}) : ''); if (event.at) time.dateTime = event.at; item.append(time, el('span', event.text)); list.append(item); });
    section.append(list); return section;
  };
})(window.DashboardComponents);
