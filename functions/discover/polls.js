'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const {onDocumentCreated}=require('firebase-functions/v2/firestore');
const admin=require('firebase-admin');
const model=require('./poll_model');
const fallback=require('./polls.json');
const opts={maxInstances:2,timeoutSeconds:60};
let cached=null,expires=0;
async function schedule(){
 if(cached&&Date.now()<expires)return cached;
 try{const [data]=await admin.storage().bucket().file('config/travelog_polls.json').download();cached=model.withDisplayCounts(model.validate(JSON.parse(data.toString('utf8').replace(/^\uFEFF/,''))),fallback.polls);}
 catch(error){console.warn('Using bundled poll schedule:',error.code||error.name);cached=model.validate(fallback);}
 expires=Date.now()+60000;return cached;
}
function user(r){if(!r.auth)throw new HttpsError('unauthenticated','Please sign in to vote.');return r.auth.uid;}
async function archive(poll,uid,vote){
 await admin.storage().bucket().file(`private/travelog-polls/${poll}/${uid}.json`).save(JSON.stringify({choice:vote.choice,pollId:poll,votedAt:vote.votedAt.toDate().toISOString()}),{resumable:false,contentType:'application/json',metadata:{cacheControl:'private, no-store'}});
}
async function releasedResult(db,poll,uid,now){
 const base=db.collection('travelog_poll_votes').doc(poll.id).collection('votes');
 const [vote,...totals]=await Promise.all([base.doc(uid).get(),...poll.options.map(o=>base.where('choice','==',o.code).count().get())]);
 const counts=Object.fromEntries(poll.options.map((o,i)=>[o.code,totals[i].data().count]));
 await admin.storage().bucket().file(`private/travelog-polls/${poll.id}/results.json`).save(JSON.stringify({counts,releasedAt:poll.releaseAt}),{resumable:false,contentType:'application/json',metadata:{cacheControl:'private, no-store'}});
 return model.view(poll,vote.data()?.choice,now,counts);
}
exports.travelogPoll=onCall(opts,async r=>{
 const uid=user(r),db=admin.firestore(),polls=await schedule(),now=Date.now(),poll=model.active(polls,now);
 const own=poll?await db.doc(`travelog_poll_votes/${poll.id}/votes/${uid}`).get():null;
 const previous=await Promise.all(polls.filter(p=>now>=Date.parse(p.releaseAt)).map(p=>releasedResult(db,p,uid,now)));
 return {serverNow:new Date(now).toISOString(),active:poll?model.view(poll,own?.data()?.choice,now):null,previous};
});
exports.travelogVote=onCall(opts,async r=>{
 const uid=user(r),polls=await schedule(),poll=polls.find(p=>p.id===r.data?.pollId),choice=r.data?.choice;
 if(!poll||!poll.options.some(o=>o.code===choice))throw new HttpsError('invalid-argument','Choose one country.');
 const db=admin.firestore(),ref=db.doc(`travelog_poll_votes/${poll.id}/votes/${uid}`);
 const vote=await db.runTransaction(async tx=>{
  const existing=await tx.get(ref);
  if(existing.exists){if(existing.data().choice!==choice)throw new HttpsError('already-exists','Your vote is already saved.');return existing.data();}
  const now=Date.now();
  if(now<Date.parse(poll.opensAt)||now>=Date.parse(poll.releaseAt))throw new HttpsError('failed-precondition','Voting is closed.');
  const payload={choice,votedAt:admin.firestore.Timestamp.now(),pollId:poll.id};tx.create(ref,payload);return payload;
 });
 await archive(poll.id,uid,vote);
 return {choice:vote.choice,recorded:true};
});
exports.archiveTravelogVote=onDocumentCreated({document:'travelog_poll_votes/{poll}/votes/{uid}',retry:true,maxInstances:2},async event=>{
 if(!event.data)return;
 await archive(event.params.poll,event.params.uid,event.data.data());
});
