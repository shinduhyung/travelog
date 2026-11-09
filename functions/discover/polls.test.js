'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const model=require('./poll_model');
const polls=model.validate(require('./polls.json'));
test('UTC boundary reveals food and switches to East Asia at exactly Nov 9 00:00',()=>{
 const instant=Date.parse('2026-11-09T00:00:00Z');
 assert.equal(model.active(polls,instant-1).id,'best_food_20261109');
 assert.equal(model.active(polls,instant).id,'east_asia_20261116');
 assert.equal(model.view(polls[0],null,instant-1,{FR:99}).counts,undefined);
 assert.equal(model.view(polls[0],null,instant,{FR:99}).counts.FR,99);
});
test('unreleased response never contains results or voter counts',()=>{
 const result=model.view(polls[0],'JP',Date.parse('2026-11-02T12:00:00Z'),{JP:12345});
 assert.equal(result.choice,'JP');assert.equal(result.released,false);
 assert.equal(JSON.stringify(result).includes('12345'),false);
 assert.equal(Object.hasOwn(result,'counts'),false);assert.equal(Object.hasOwn(result,'total'),false);
});
test('schedule rejects duplicate choices and overlapping dates',()=>{
 const clone=()=>JSON.parse(JSON.stringify({schema:1,polls}));
 let bad=clone();bad.polls[1].opensAt='2026-11-08T00:00:00Z';assert.throws(()=>model.validate(bad));
 bad=clone();bad.polls[0].options[1].code='FR';assert.throws(()=>model.validate(bad));
});
const twin=require('./twin_model');
test('country-only soulmate ignores city and landmark differences',()=>{
 const rows=[{uid:'a',countries:['FR'],cities:[],landmarks:[]},{uid:'b',countries:['FR','JP'],cities:['Paris'],landmarks:['Louvre']}];
 assert.equal(twin.closest(['FR'],rows,'self').best.row.uid,'a');
});
test('traveler type follows highest saved score and respects sharing',()=>{
 const raw={ai_analysis_result:JSON.stringify({summary:{persona_scores:[{label:'Culture Decoder',score:70},{label:'Joy Collector',score:80}]}})};
 assert.equal(twin.travelerType(raw,{}),'Joy Collector');
 assert.equal(twin.travelerType(raw,{privacy:{dna:false}}),null);
});
