// Run with explicit owned fixture root and exact original generated engine.
// Fixtures are intentionally retained; no test deletes files.
import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {randomUUID} from 'node:crypto';
import {loadPolicy,replacementDefinitions,transformSource,expectedReceipt,applyFreshExport,verifyExport,hash} from './web_gl_handles.mjs';
const policy=loadPolicy();
const dir=path.dirname(fileURLToPath(import.meta.url));
const locked=Object.fromEntries(policy.lock.anchors.map(a=>[a.name,a.before]));
const support=Object.fromEntries(policy.lock.support_anchors.map(a=>[a.name,a.source]));
function fixture(options={}){
 const events=[],errors=[],GL={counter:1,buffers:[],textures:[],vaos:[],syncs:[],programs:[],shaders:[],queries:[],currentContext:{handle:1},recordError:e=>errors.push(e)};
 let sequence=0,failCreate=false,failDelete=false;
 const make=kind=>failCreate?null:{kind,serial:++sequence};
 const remove=(kind,obj)=>{events.push({kind,obj,name:obj?.name});if(failDelete)throw Error('original delete failure');};
 const GLctx={currentPixelPackBufferBinding:0,currentPixelUnpackBufferBinding:0,
 createBuffer:()=>make('buffer'),createTexture:()=>make('texture'),createVertexArray:()=>make('vao'),fenceSync:()=>make('sync'),
 deleteBuffer:o=>remove('buffer',o),deleteTexture:o=>remove('texture',o),deleteVertexArray:o=>remove('vao',o),deleteSync:o=>remove('sync',o)};
 const HEAP32=new Int32Array(4096),sandbox={GL,GLctx,HEAP32,Set:options.Set??Set};vm.createContext(sandbox);
 const replacements=replacementDefinitions(policy);
 let source='GL.getNewId='+replacements.allocator.slice('getNewId:'.length)+';GL.genObject='+support.genObject.slice('genObject:'.length)+';';
 source+=['delete_buffers','delete_textures','delete_vaos','delete_syncs'].map(k=>replacements[k]+';').join('');
 source+=policy.lock.support_anchors.filter(a=>a.name!=='genObject').map(a=>a.source+';').join('');
 const symbols=['_emscripten_glGenBuffers','_glGenBuffers','_emscripten_glDeleteBuffers','_glDeleteBuffers','_emscripten_glGenTextures','_glGenTextures','_emscripten_glDeleteTextures','_glDeleteTextures','_emscripten_glGenVertexArrays','_glGenVertexArrays','_emscripten_glGenVertexArraysOES','_glGenVertexArraysOES','_emscripten_glDeleteVertexArrays','_glDeleteVertexArrays','_emscripten_glDeleteVertexArraysOES','_glDeleteVertexArraysOES','_emscripten_glFenceSync','_glFenceSync','_emscripten_glDeleteSync','_glDeleteSync'];
 source+='globalThis.imports={'+symbols.map(s=>s+':'+s).join(',')+'};globalThis.Module={'+symbols.map(s=>s+':'+s).join(',')+'};';
 // Use actual original lexical alias definitions; captures precede Module mutation.
 vm.runInContext(source,sandbox);
 const gen=(name='_glGenBuffers')=>{sandbox.imports[name](1,0);return HEAP32[0];};
 const del=(id,name='_glDeleteBuffers')=>{HEAP32[0]=id;sandbox.imports[name](1,0);};
 return{GL,GLctx,HEAP32,events,errors,imports:sandbox.imports,Module:sandbox.Module,gen,del,setFailCreate:v=>failCreate=v,setFailDelete:v=>failDelete=v};
}
function healthy(f){assert.equal(f.GL.__bthGlHandles.fault,'');assert.equal(f.GL.__bthGlHandles.disabled,false);for(const p of Object.values(f.GL.__bthGlHandles.pools))assert.equal(p.fallback_allocations,0);}
test('four typed pools reuse only their own deleted IDs; new peak retains original global counter',()=>{
 const f=fixture(),a=f.gen(),b=f.gen(),t=f.gen('_glGenTextures');assert.equal(new Set([a,b,t]).size,3);
 f.del(a);const peak=f.GL.counter;assert.equal(f.gen(),a);assert.equal(f.GL.counter,peak);assert.equal(f.GL.buffers[b].name,b);assert.equal(f.GL.textures[t].name,t);
 assert.notEqual(f.gen('_glGenTextures'),a);healthy(f);
});
test('buffer and texture deletion retains .name ordering and PBO cache resets',()=>{
 const f=fixture(),id=f.gen(),obj=f.GL.buffers[id];f.GLctx.currentPixelPackBufferBinding=id;f.GLctx.currentPixelUnpackBufferBinding=id;f.del(id);
 assert.equal(f.events[0].name,id);assert.equal(obj.name,0);assert.equal(f.GLctx.currentPixelPackBufferBinding,0);assert.equal(f.GLctx.currentPixelUnpackBufferBinding,0);
 const t=f.gen('_glGenTextures'),tex=f.GL.textures[t];f.del(t,'_emscripten_glDeleteTextures');assert.equal(tex.name,0);assert.equal(f.gen('_glGenTextures'),t);healthy(f);
});
test('all captured core/prefixed/OES aliases reuse despite later Module alias overwrite',()=>{
 const f=fixture();for(const k of Object.keys(f.Module))f.Module[k]=()=>{throw Error('wrong alias');};
 for(const [g,d] of [['_glGenBuffers','_emscripten_glDeleteBuffers'],['_emscripten_glGenBuffers','_glDeleteBuffers'],['_emscripten_glGenTextures','_glDeleteTextures'],['_glGenVertexArrays','_emscripten_glDeleteVertexArraysOES'],['_emscripten_glGenVertexArraysOES','_glDeleteVertexArrays'],['_glGenVertexArraysOES','_emscripten_glDeleteVertexArrays']]){const id=f.gen(g);f.del(id,d);assert.equal(f.gen(g),id);}healthy(f);
});
test('duplicate/zero deletes preserve original behavior and never duplicate free IDs',()=>{
 const f=fixture(),a=f.gen();f.del(a);f.del(a);f.del(0);assert.equal(f.GL.__bthGlHandles.pools.buffers.free_count,1);assert.equal(f.gen(),a);assert.notEqual(f.gen(),a);
 const v=f.gen('_glGenVertexArrays'),obj=f.GL.vaos[v];f.del(v,'_glDeleteVertexArraysOES');f.del(v,'_glDeleteVertexArrays');assert.equal(obj.name,v);assert.equal(f.GL.__bthGlHandles.pools.vaos.free_count,1);healthy(f);
});
test('sync null/zero/invalid paths and multiple live fences preserve errors',()=>{
 const f=fixture(),a=f.imports._glFenceSync(0,0),b=f.imports._emscripten_glFenceSync(0,0);assert.notEqual(a,b);
 f.imports._glDeleteSync(a);f.imports._glDeleteSync(a);f.imports._glDeleteSync(0);assert.deepEqual(f.errors,[1281]);assert.equal(f.imports._glFenceSync(0,0),a);assert.equal(f.GL.syncs[b].name,b);
 f.setFailCreate(true);assert.equal(f.imports._glFenceSync(0,0),0);healthy(f);
});
test('failed creation bypasses allocator; original exceptions are preserved',()=>{
 const f=fixture();f.setFailCreate(true);assert.equal(f.gen(),0);assert.equal(f.GL.counter,1);assert.deepEqual(f.errors,[1282]);assert.equal(f.GL.__bthGlHandles,undefined);
 f.setFailCreate(false);const id=f.gen();f.setFailDelete(true);assert.throws(()=>f.del(id),/original delete failure/);assert.equal(f.GL.buffers[id].name,id);assert.equal(f.GL.__bthGlHandles.pools.buffers.free_count,0);healthy(f);
});
test('excluded namespaces still allocate from original global shared namespace',()=>{
 const f=fixture();const a=f.GL.getNewId(f.GL.programs);f.GL.programs[a]={};const b=f.GL.getNewId(f.GL.shaders);f.GL.shaders[b]={};assert.equal(a,1);assert.equal(b,2);assert.equal(f.gen(),3);healthy(f);
});
test('nonfresh tables latch fallback without scanning/seeding holes',()=>{
 const f=fixture();f.GL.textures[5]=null;const a=f.gen();assert.equal(a,1);assert.equal(f.GL.__bthGlHandles.fault,'nonfresh_initial_tables');assert.equal(f.GL.__bthGlHandles.disabled,true);f.del(a);assert.equal(f.gen(),2);
});
test('65536 ownership cap latches globally and does not reuse after fallback',()=>{
 const f=fixture();let first;for(let i=0;i<65536;i++){const id=f.gen();if(i===0)first=id;}assert.equal(f.GL.__bthGlHandles.pools.buffers.owned_count,65536);const next=f.gen();assert.equal(next,65537);assert.equal(f.GL.__bthGlHandles.fault,'tracking_cap');f.del(first);assert.equal(f.gen(),65538);assert.equal(f.GL.__bthGlHandles.pools.buffers.reuses,0);
});
test('bookkeeping throw after original allocation returns that reserved ID exactly once',()=>{
 class BadSet extends Set{add(){throw Error('injected metadata fault');}}
 const f=fixture({Set:BadSet});assert.equal(f.gen(),1);assert.equal(f.GL.counter,2);assert.equal(f.GL.__bthGlHandles.fault,'bookkeeping_after_original');assert.equal(f.gen(),2);
});
test('release metadata throw never escapes deletion or corrupts live resource',()=>{
 let adds=0;class BadSet extends Set{add(x){if(++adds===2)throw Error('release metadata');return super.add(x);}}
 const f=fixture({Set:BadSet}),a=f.gen();assert.doesNotThrow(()=>f.del(a));assert.equal(f.GL.buffers[a],null);assert.equal(f.GL.__bthGlHandles.fault,'release_bookkeeping_fault');assert.equal(f.gen(),2);
});
test('original allocator exception is propagated once, never caught and retried',()=>{
 const f=fixture();let calls=0;Object.defineProperty(f.GL,'counter',{get(){calls++;throw Error('original allocator failure');}});assert.throws(()=>f.gen(),/original allocator failure/);assert.equal(calls,1);
});
const enginePath=process.env.BTH_WEB_GL_ENGINE_FIXTURE;
const fixtureRoot=process.env.BTH_WEB_GL_TEST_ROOT;
test('full pinned engine transform, deterministic output, alias preservation and unknown-engine rejection',()=>{
 assert.ok(enginePath,'set BTH_WEB_GL_ENGINE_FIXTURE to locked original engine');const original=fs.readFileSync(enginePath),out=transformSource(original);assert.equal(hash(out),policy.lock.output_sha256);assert.equal(hash(transformSource(original)),hash(out));
 for(const a of policy.lock.support_anchors)assert.equal(out.toString().split(a.source).length-1,1,a.name);
 assert.throws(()=>transformSource(Buffer.concat([original,Buffer.from('// Debug/changed')])),/unsupported generated Web engine SHA256/);assert.throws(()=>transformSource(out),/unsupported generated Web engine SHA256/);
});
test('fresh apply archives original, immutable verification fails closed on forged receipt, WASM and policy changes',async()=>{
 assert.ok(enginePath&&fixtureRoot,'explicit fixture paths required');const parent=fs.realpathSync(fixtureRoot);assert.equal(parent.toLowerCase(),path.resolve(fixtureRoot).toLowerCase());const own=path.join(parent,'web-gl-'+randomUUID()),stage=path.join(own,'stage');fs.mkdirSync(stage,{recursive:true});
 for(const n of ['index.js','index.wasm','index.side.wasm'])fs.copyFileSync(path.join(path.dirname(enginePath),n),path.join(stage,n),fs.constants.COPYFILE_EXCL);
 const before=fs.readFileSync(path.join(stage,'index.js'));assert.throws(()=>verifyExport(stage));applyFreshExport(stage,own);assert.deepEqual(fs.readFileSync(path.join(own,'web-gl-handles-original','index.original.js')),before);
 const receipt=path.join(stage,'web-gl-handles.json'),js=path.join(stage,'index.js'),valid=fs.readFileSync(js),validReceipt=fs.readFileSync(receipt);const first=JSON.stringify(verifyExport(stage));assert.equal(JSON.stringify(verifyExport(stage)),first);assert.throws(()=>applyFreshExport(stage,own),/existing mitigation receipt/);
 fs.copyFileSync(js,path.join(own,'valid-patched.js'),fs.constants.COPYFILE_EXCL);fs.copyFileSync(receipt,path.join(own,'valid-receipt.json'),fs.constants.COPYFILE_EXCL);
 fs.writeFileSync(js,before);const forged=JSON.parse(validReceipt);forged.output_sha256=hash(before);fs.writeFileSync(receipt,JSON.stringify(forged));assert.throws(()=>verifyExport(stage),/locked EXPECTED patched output/);fs.copyFileSync(receipt,path.join(own,'forged-receipt.json'),fs.constants.COPYFILE_EXCL);fs.writeFileSync(js,valid);fs.writeFileSync(receipt,validReceipt);
 const wasm=path.join(stage,'index.side.wasm');fs.renameSync(wasm,path.join(own,'preserved.side.wasm'));fs.writeFileSync(wasm,'wrong engine');assert.throws(()=>verifyExport(stage),/actual Web engine WASM/);
 const mini=path.join(own,'policy-repo'),tools=path.join(mini,'tools'),native=path.join(mini,'native','coin_pusher');fs.mkdirSync(tools,{recursive:true});fs.mkdirSync(native,{recursive:true});for(const n of ['web_gl_handles.mjs','web_gl_handles.lock.json','web_gl_handles_allocator.txt'])fs.copyFileSync(path.join(dir,n),path.join(tools,n),fs.constants.COPYFILE_EXCL);for(const n of ['toolchain.lock.json','godot_web_release_build_profile.json'])fs.copyFileSync(path.join(dir,'..','native','coin_pusher',n),path.join(native,n),fs.constants.COPYFILE_EXCL);
 const isolated=await import(pathToFileURL(path.join(tools,'web_gl_handles.mjs')).href);isolated.loadPolicy();fs.appendFileSync(path.join(native,'godot_web_release_build_profile.json'),' ');assert.throws(()=>isolated.loadPolicy(),/current repository Godot\/Web toolchain or release build profile/);
 const changedLock={...policy.lock,output_sha256:'0'.repeat(64)};assert.throws(()=>transformSource(before,{...policy,lock:changedLock}),/locked EXPECTED output/);
 assert.throws(()=>applyFreshExport(path.dirname(stage),own),/fresh direct stage child/);assert.equal(expectedReceipt().output_sha256,policy.lock.output_sha256);
});
