'use strict';
function validate(config) {
 if(config?.schema!==1 || !Array.isArray(config.polls)) throw new Error('Invalid poll schedule');
 const ids=new Set();
 const polls=[...config.polls].sort((a,b)=>Date.parse(a.opensAt)-Date.parse(b.opensAt));
 for(let i=0;i<polls.length;i++) {
  const p=polls[i],open=Date.parse(p.opensAt),release=Date.parse(p.releaseAt);
  if(!/^[a-z0-9_]{1,80}$/.test(p.id)||ids.has(p.id)||typeof p.question!=='string'||!Number.isFinite(open)||!Number.isFinite(release)||open>=release||!Array.isArray(p.options)||p.options.length<2||p.options.length>10)throw new Error('Invalid poll');
  if(p.options.some(o=>!(/^[A-Z]{2}$/).test(o.code)||typeof o.label!=='string')||new Set(p.options.map(o=>o.code)).size!==p.options.length)throw new Error('Invalid choices');
  if(i && open<Date.parse(polls[i-1].releaseAt))throw new Error('Overlapping polls');
  ids.add(p.id);
 }
 return polls;
}
function active(polls,now){return polls.find(p=>now>=Date.parse(p.opensAt)&&now<Date.parse(p.releaseAt))||null;}
function view(poll,ownVote,now,counts){
 const released=now>=Date.parse(poll.releaseAt);
 // displayCounts (set in the schedule) is shown instead of the tallied votes.
 const {displayCounts,...rest}=poll,shown=displayCounts||counts;
 return {...rest,released,choice:ownVote||null,...(released?{counts:Object.fromEntries(poll.options.map(o=>[o.code,shown?.[o.code]||0]))}:{})};
}
// A remote schedule without displayCounts inherits them from the bundled one.
function withDisplayCounts(polls,bundled){
 const byId=new Map(bundled.filter(p=>p.displayCounts).map(p=>[p.id,p.displayCounts]));
 return polls.map(p=>p.displayCounts||!byId.has(p.id)?p:{...p,displayCounts:byId.get(p.id)});
}
module.exports={validate,active,view,withDisplayCounts};
