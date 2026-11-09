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
 return {...poll,released,choice:ownVote||null,...(released?{counts:Object.fromEntries(poll.options.map(o=>[o.code,counts?.[o.code]||0]))}:{})};
}
module.exports={validate,active,view};
