import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import worker,{canonicalInstagram,metadata,captionEntities,kakaoPlaces,exactMatch} from '../worker/index.js';

assert.equal(canonicalInstagram('https://www.instagram.com/reel/DF7oYUjB3jw/?utm_source=test'),'https://www.instagram.com/reel/DF7oYUjB3jw/');
for(const s of ['http://www.instagram.com/reel/DF7oYUjB3jw/','https://instagram.com.evil.test/reel/DF7oYUjB3jw/','https://instagram.com@evil.test/reel/DF7oYUjB3jw/','https://www.instagram.com/username/','https://127.0.0.1/reel/DF7oYUjB3jw/','https://www.instagram.com:444/reel/DF7oYUjB3jw/'])assert.throws(()=>canonicalInstagram(s));
assert.equal(metadata('<meta content="식당 &amp; 주소 &#xAC00;" property="og:description">').caption,'식당 & 주소 가');
const numbered='1.식당A @account\n📍망원동 398-2\n추천\n2.식당B\n📍마포구 토정로35길 6\n3.샤워기 (유료광고)\n📍@brand';
assert.deepEqual(captionEntities(numbered).map(e=>e.name),['식당A','식당B']);
assert.equal(captionEntities('📍#산와쇼텐\n📍서울 마포구 토정로35길 6 1층 3호')[0].name,'산와쇼텐');
const docs=[{id:'123',place_name:'산와쇼텐',road_address_name:'서울 마포구 토정로35길 6',address_name:'서울 마포구 용강동 10',x:'126.94',y:'37.54',category_group_code:'FD6',category_name:'음식점 > 일식'}, {id:'456',category_group_code:'MT1'}];
const places=kakaoPlaces(docs);assert.equal(places.length,1);assert.equal(places[0].lng,126.94);
assert(exactMatch({name:'산와쇼텐',address:'서울 마포구 토정로35길 6 1층 3호'},places[0]));
assert(!exactMatch({name:'산와쇼텐',address:'서울 마포구 토정로35길 60'},places[0]));
assert(!exactMatch({name:'산와쇼텐',address:''},places[0]));
assert(!exactMatch({name:'산와쇼텐',address:'토정로35길 6'},{...places[0],address:'토정로35길 60',lotAddress:''}));
assert(!exactMatch({name:'산와쇼텐 강남점',address:'서울 마포구 토정로35길 6'},places[0]));
assert(!exactMatch({name:'산와쇼텐',address:'부산 해운대구 토정로35길 6'},places[0]));
assert(!exactMatch({name:'산와쇼텐',address:'서울 해운대구 토정로35길 6'},places[0]));
assert(exactMatch({name:'산와쇼텐',address:'토정로35길 6'},{...places[0],address:'토정로35길 6 1층'}));
const req=(path,body,headers={})=>new Request('https://test.example'+path,{method:'POST',headers:{'Content-Type':'application/json',...headers},body:JSON.stringify(body)});
let r=await worker.fetch(req('/api/analyze',{url:'https://evil.test/x'}),{});assert.equal(r.status,400);
r=await worker.fetch(req('/api/analyze',{text:'📍#산와쇼텐\n📍서울 마포구 토정로35길 6'}),{});assert.equal(r.status,200);let b=await r.json();assert.equal(b.status,'needs_input');assert.equal(b.groups[0].places.length,0);assert.equal(b.mediaAnalyzed,false);
r=await worker.fetch(req('/api/analyze',{text:'hello'},{Origin:'https://evil.test'}),{});assert.equal(r.status,403);
r=await worker.fetch(req('/api/search',{query:'식당'}),{DEMO_ACCESS_CODE:'secret'});assert.equal(r.status,401);
r=await worker.fetch(req('/api/analyze',{media:{mime:'video/mp4',data:'a'.repeat(18000000)}}),{});assert.equal(r.status,413);
r=await worker.fetch(req('/api/analyze',{media:{mime:'text/html',data:'aGVsbG8='}}),{});assert.equal(r.status,400);
r=await worker.fetch(req('/api/analyze',{}),{});assert.equal((await r.json()).status,'needs_input');
// Integration with stubbed external services: confirms exact matching and disambiguation behavior.
const actualFetch=globalThis.fetch;
try {
 globalThis.fetch=async (url,options)=>{assert.equal(options.redirect,'manual');assert(String(url).startsWith('https://dapi.kakao.com/'));return Response.json({documents:docs});};
 r=await worker.fetch(req('/api/analyze',{text:'📍#산와쇼텐\n📍서울 마포구 토정로35길 6'}),{KAKAO_REST_API_KEY:'stub'});
 b=await r.json();assert.equal(b.status,'auto_save');assert.equal(b.groups[0].matchedID,'kakao:123');
 globalThis.fetch=async()=>Response.json({documents:[...docs,{...docs[0],id:'789'}]});
 r=await worker.fetch(req('/api/analyze',{text:'📍#산와쇼텐\n📍서울 마포구 토정로35길 6'}),{KAKAO_REST_API_KEY:'stub'});
 assert.equal((await r.json()).status,'choose');

 globalThis.fetch=async url=>String(url).includes('generativelanguage.googleapis.com')?Response.json({error:{message:'credits exhausted'}},{status:402}):Response.json({documents:docs});
 r=await worker.fetch(req('/api/analyze',{text:'📍#산와쇼텐\n📍서울 마포구 토정로35길 6',media:{mime:'video/mp4',data:'aGVsbG8='}}),{KAKAO_REST_API_KEY:'stub',GEMINI_API_KEY:'stub'});
 b=await r.json();assert.equal(b.status,'auto_save');assert.equal(b.method,'caption_rules');assert.equal(b.mediaAnalyzed,false);assert(b.warnings.some(w=>w.includes('크레딧')));
 globalThis.fetch=async url=>String(url).includes('generativelanguage.googleapis.com')?Response.json({candidates:[{content:{parts:[{text:JSON.stringify({restaurants:[{name:'산와쇼텐',address:'토정로35길 6',evidence:'산와쇼텐',evidenceSource:'caption'}]})}]}}]}):Response.json({documents:docs});
 r=await worker.fetch(req('/api/analyze',{text:'산와쇼텐이 좋다'}),{KAKAO_REST_API_KEY:'stub',GEMINI_API_KEY:'stub'});
 b=await r.json();assert.equal(b.status,'choose');assert.equal(b.groups[0].entity.address,'');

 const redirectCalls=[];
 globalThis.fetch=async (url,options)=>{assert.equal(options.redirect,'manual');redirectCalls.push(String(url));if(String(url).includes('instagram.com/reel/'))return new Response(null,{status:302,headers:{Location:'https://www.instagram.com/parkyeny/reel/DF7oYUjB3jw/'}});if(String(url).includes('instagram.com/parkyeny/'))return new Response('<meta property="og:description" content="📍#산와쇼텐\n📍서울 마포구 토정로35길 6">');return Response.json({documents:docs});};
 r=await worker.fetch(req('/api/analyze',{url:'https://www.instagram.com/reel/DF7oYUjB3jw/'}),{KAKAO_REST_API_KEY:'stub'});
 assert.equal((await r.json()).status,'auto_save');assert.equal(redirectCalls.length,3);
 let attempts=0;globalThis.fetch=async()=>{attempts++;return new Response(null,{status:302,headers:{Location:'https://127.0.0.1/private'}});};
 r=await worker.fetch(req('/api/analyze',{url:'https://www.instagram.com/reel/DF7oYUjB3jw/'}),{});
 assert.equal((await r.json()).status,'needs_input');assert.equal(attempts,2);
} finally {globalThis.fetch=actualFetch;}
console.log('Core checks passed: URL boundaries, caption extraction, non-food exclusion, exact/ambiguous locations, input limits, origin, access code, API failure handling.');
