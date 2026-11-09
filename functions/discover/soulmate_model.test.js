const test = require('node:test');
const assert = require('node:assert/strict');
const {closestTravel,travel} = require('./twin_model');
test('all four travel domains distinguish country-identical members',()=>{
 const mine={countries:['FR'],cities:['Paris'],landmarks:['Louvre'],unesco:['Seine']};
 const result=closestTravel(mine,[{uid:'a',countries:['FR'],cities:['Lyon'],landmarks:[],unesco:[]},{uid:'b',...mine},{uid:'self',...mine}], 'self');
 assert.equal(result.best.row.uid,'b');assert.equal(result.best.similarity,1);assert.equal(result.compared,2);
});
test('empty domains do not invent similarity and hidden cities never participate',()=>{
 const mine={countries:['FR'],cities:['Paris'],landmarks:[],unesco:[]};
 const hidden=travel({country_visits_v2:{France:{isVisited:true}},city_visit_details_v3:{Paris:{visitCount:1}}},{france:'FR'},{cities:false});
 assert.equal(hidden.cities,null);
 assert.equal(closestTravel(mine,[{uid:'x',...hidden}], 'self').best.similarity,1);
 assert.equal(closestTravel({countries:[],cities:[],landmarks:['Louvre'],unesco:[]},[{uid:'x',countries:[],cities:[],landmarks:['Louvre'],unesco:[]}],'self').best.similarity,1);
});
test('matching is deterministic and extra places lower overlap',()=>{
 const mine={countries:['FR'],cities:[],landmarks:[],unesco:[]};
 const rows=[{uid:'z',...mine},{uid:'a',...mine},{uid:'b',...mine,countries:['FR','JP']}];
 assert.equal(closestTravel(mine,rows,'self').best.row.uid,'a');
 assert.equal(closestTravel(mine,rows.reverse(),'self').best.row.uid,'a');
});
