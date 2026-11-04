/* Interface copy. English is the default; state.ui.strings overrides any key in the user's language. */
window.DashboardComponents=window.DashboardComponents||{};
(function(C){
'use strict';
C.defaultStrings={
'app.name':'Work map',
'app.footer':'Scope and progress come from the main agent. Select a map stage to jump to its details.',
'app.untitled':'Preparing the dashboard',
'app.renderError':'The session view could not render. Showing the standard view.',
'connection.connecting':'Connecting…',
'connection.reconnecting':'Reconnecting…',
'connection.error':'No updates · retrying',
'connection.idle':'Live',
'connection.draft':'Agent is drafting the first view',
'connection.work':'Agent is making changes',
'connection.offline':'Offline snapshot',
'offline.footer':'Offline snapshot. Live updates are available in the live view.',
'status.todo':'Not started',
'status.doing':'In progress',
'status.done':'Done',
'status.blocked':'Blocked',
'status.unknown':'To confirm',
'map.label':'Stage map',
'map.waiting':'Waiting here',
'map.current':'You are here',
'map.stageAction':'{title} — {status}. Go to the stage evidence.',
'map.showDetails':'{title} — {status}. Show details.',
'map.empty':'Stages appear after the first update from the agent.',
'map.stageDone':'{done} of {total} done',
'map.left':'Left before {title}',
'map.scopeUnknown':'Scope to confirm: {title}',
'map.allDone':'All declared stages are complete.',
'map.blockedCount':'● {count} blocked',
'progress.label':'Work progress',
'proposal':'proposal',
'proposal.agent':'agent proposal',
'ledger.title':'Evidence by stage',
'ledger.count':'{done} of {total} tasks done',
'ledger.outside':'Outside stages',
'ledger.tasks':'Tasks',
'ledger.scopeUnset':'Scope not set',
'ledger.changed':'changed',
'ledger.blocker':'Blocker',
'ledger.evidence':'Evidence',
'ledger.notStarted':'Not started yet.',
'ledger.noDetails':'No details reported.',
'ledger.empty':'The main agent will report scope and progress here.',
'task.updated':'Updated',
'task.details':'Details',
'task.blockerLine':'Blocker: {text}',
'task.evidenceLine':'Evidence: {text}',
'decision.needed':'Your decision is needed',
'decision.open':'To decide',
'decision.title':'Decisions',
'decision.agentDefault':'Agent proposal (not an approval): {text}',
'decision.default':'Proposed default: {text}',
'decision.ask':'Reply in the chat. No reply does not mean approval.',
'decision.waiting':'Waiting for your decision.',
'decision.nonBlocking':'Does not block the current work.',
'now.title':'Now',
'now.badge':'In progress',
'now.waiting':'Waiting for an update.',
'next.title':'Next step',
'events.title':'Recent changes',
'milestone.progress':'{remaining} left · {done} of {total} done',
'milestone.unassigned':'Tasks have not been assigned yet.',
'milestone.meter':'Milestone completion'
};
C.ui={};
/** Applies state.ui: the page language and translated strings. */
C.setUi=function(ui){C.ui=ui&&typeof ui==='object'?ui:{};document.documentElement.lang=C.ui.lang||'en';};
/** Returns the localized string for key, with {name} placeholders replaced by vars. */
C.t=function(key,vars){
const custom=C.ui.strings,text=custom&&typeof custom[key]==='string'?custom[key]:C.defaultStrings[key]??key;
return vars?text.replace(/\{(\w+)\}/g,(match,name)=>Object.hasOwn(vars,name)?String(vars[name]):match):text;
};
/** The page language for dates and numbers; undefined uses the browser default. */
C.locale=function(){return C.ui.lang||undefined;};
})(window.DashboardComponents);
