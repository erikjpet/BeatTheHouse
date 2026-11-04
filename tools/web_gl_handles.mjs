// Deterministic Web-only build-time transform; no browser/global-template mutation.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import {fileURLToPath} from "node:url";
const here=path.dirname(fileURLToPath(import.meta.url));
export const RECEIPT_FILE="web-gl-handles.json";
const INPUT="8cf4a21cded9270718a67c6f1aab3d794eca91e3903ad866532c925565dd1fc4";
const PROFILE="godot-4.6-emscripten-4.0.20-dlink-nothreads-release";
export const hash=bytes=>crypto.createHash("sha256").update(bytes).digest("hex");
const sourceBytes=file=>Buffer.from(fs.readFileSync(file,"utf8").replace(/\r\n/g,"\n"),"utf8");
const count=(text,token)=>text.split(token).length-1;
export function loadPolicy(){
 const lockFile=path.join(here,"web_gl_handles.lock.json"),bytes=sourceBytes(lockFile),lock=JSON.parse(bytes);
 if(lock.schema!=="bth.web_gl_handles.lock/v1"||lock.policy_version!==1||lock.profile!==PROFILE||lock.input_sha256!==INPUT||lock.source_hash_format!=="utf8_lf_v1"||lock.tracking_cap!==65536||lock.receipt_file!==RECEIPT_FILE||JSON.stringify(lock.tables)!==JSON.stringify(["buffers","textures","vaos","syncs"])||!/^([0-9a-f]{64})$/.test(lock.output_sha256??""))throw Error("unsupported Web GL policy/version/profile");
 const repo=path.resolve(here,".."),actual=JSON.parse(sourceBytes(path.join(repo,"native","coin_pusher","toolchain.lock.json")));
 if(lock.godot_commit!=="89cea143987d564363e15d207438530651d943ac"||lock.emscripten_version!=="4.0.20"||lock.template_sha256!=="cf371f607aa9cb18e690bd595976c1baaf00c8cec24078e4a307fd515ad07913"||actual.godot?.commit!==lock.godot_commit||actual.web?.version!==lock.emscripten_version||actual.web?.template_sha256!==lock.template_sha256||actual.web?.commit!==lock.emscripten_commit||actual.web?.compiler_commit!==lock.compiler_commit||hash(sourceBytes(path.join(repo,"native","coin_pusher","godot_web_release_build_profile.json")))!==lock.build_profile_sha256)throw Error("current repository Godot/Web toolchain or release build profile differs from mitigation policy");
 if(JSON.stringify(Object.keys(lock.engine_assets??{}).sort())!==JSON.stringify(["index.side.wasm","index.wasm"])||Object.values(lock.engine_assets).some(v=>!/^([0-9a-f]{64})$/.test(v)))throw Error("locked engine WASM asset inventory required");
 const fragmentFile=path.join(here,"web_gl_handles_allocator.txt"),fragmentBytes=sourceBytes(fragmentFile);
 if(lock.allocator_file!==path.basename(fragmentFile)||hash(fragmentBytes)!==lock.allocator_sha256)throw Error("allocator source fragment does not match versioned lock");
 if(lock.anchors?.length!==5||lock.support_anchors?.length!==17)throw Error("exact anchor inventory required");
 for(const a of [...lock.anchors,...lock.support_anchors]){const v=a.before??a.source;if(typeof v!=="string"||Buffer.byteLength(v)!==a.bytes||hash(Buffer.from(v))!==a.sha256)throw Error("locked original definition/alias anchor corrupt");}
 return{lock,policy_sha256:hash(bytes),tool_sha256:hash(sourceBytes(fileURLToPath(import.meta.url))),allocator_sha256:hash(fragmentBytes),fragment:fragmentBytes.toString("utf8").trimEnd()};
}
export function replacementDefinitions(policy=loadPolicy()){
 const m=Object.fromEntries(policy.lock.anchors.map(a=>[a.name,a.before]));
 m.allocator="getNewId:"+policy.fragment;
 m.delete_buffers=m.delete_buffers.replace("GLctx.currentPixelUnpackBufferBinding=0}}","GLctx.currentPixelUnpackBufferBinding=0;GL.getNewId.release(GL.buffers,id,buffer)}}");
 m.delete_textures=m.delete_textures.replace("GL.textures[id]=null}}","GL.textures[id]=null;GL.getNewId.release(GL.textures,id,texture)}}");
 m.delete_vaos=m.delete_vaos.replace("GLctx.deleteVertexArray(GL.vaos[id]);GL.vaos[id]=null","var prior=GL.vaos[id];GLctx.deleteVertexArray(prior);GL.vaos[id]=null;GL.getNewId.release(GL.vaos,id,prior)");
 m.delete_syncs=m.delete_syncs.replace("GL.syncs[id]=null}","GL.syncs[id]=null;GL.getNewId.release(GL.syncs,id,sync)}");
 return m;
}
export function transformSource(input,policy=loadPolicy()){
 const bytes=Buffer.isBuffer(input)?input:Buffer.from(input);
 if(hash(bytes)!==policy.lock.input_sha256)throw Error("unsupported generated Web engine SHA256 "+hash(bytes)+"; only the locked release profile is qualified (Debug/new engines require a reviewed new policy version)");
 let text=bytes.toString("utf8");
 for(const a of policy.lock.support_anchors)if(count(text,a.source)!==1)throw Error("original creator/import alias anchor count mismatch: "+a.name);
 const replacements=replacementDefinitions(policy);
 for(const a of policy.lock.anchors){if(count(text,a.before)!==1)throw Error("original function anchor count mismatch: "+a.name);text=text.replace(a.before,replacements[a.name]);}
 const output=Buffer.from(text,"utf8");if(hash(output)!==policy.lock.output_sha256)throw Error("deterministic patched engine does not match locked EXPECTED output SHA256");return output;
}
export function expectedReceipt(policy=loadPolicy()){
 return{schema:"bth.web_gl_handles/v1",policy_version:policy.lock.policy_version,profile:policy.lock.profile,source_hash_format:"utf8_lf_v1",policy_sha256:policy.policy_sha256,tool_sha256:policy.tool_sha256,allocator_sha256:policy.allocator_sha256,godot_commit:policy.lock.godot_commit,emscripten_version:policy.lock.emscripten_version,template_sha256:policy.lock.template_sha256,build_profile_sha256:policy.lock.build_profile_sha256,engine_assets:policy.lock.engine_assets,input_sha256:policy.lock.input_sha256,output_sha256:policy.lock.output_sha256,tables:policy.lock.tables,rewrites:{allocator:1,delete_buffers:1,delete_textures:1,delete_vaos:1,delete_syncs:1}};
}
function exists(p){try{fs.lstatSync(p);return true;}catch(e){if(e.code==="ENOENT")return false;throw e;}}
function plainDir(p){const resolved=path.resolve(p);let q=resolved;while(true){const st=fs.lstatSync(q);if(!st.isDirectory()||st.isSymbolicLink()||fs.realpathSync(q).toLowerCase()!==q.toLowerCase())throw Error("plain non-aliased directory ancestors required");const n=path.dirname(q);if(n===q)break;q=n;}return resolved;}
function plainFile(p){const st=fs.lstatSync(p);if(!st.isFile()||st.isSymbolicLink()||fs.realpathSync(p).toLowerCase()!==path.resolve(p).toLowerCase())throw Error("plain non-aliased file required");return st;}
function inside(p,root){const rel=path.relative(root,p);return rel!==""&&!rel.startsWith(".."+path.sep)&&rel!==".."&&!path.isAbsolute(rel);}
function checkedRename(from,to,owned){plainDir(path.dirname(from));plainDir(path.dirname(to));plainFile(from);if(!inside(from,owned)||!inside(to,owned)||exists(to))throw Error("checked rename requires fresh destinations inside exact owned attempt root");fs.renameSync(from,to);}
function verifyEngineAssets(stage,policy){for(const[name,expected]of Object.entries(policy.lock.engine_assets)){const file=path.join(stage,name);plainFile(file);if(hash(fs.readFileSync(file))!==expected)throw Error("actual Web engine WASM differs from locked template profile: "+name);}}
export function verifyExport(stage,policy=loadPolicy()){
 stage=plainDir(stage);verifyEngineAssets(stage,policy);const js=path.join(stage,"index.js"),receipt=path.join(stage,RECEIPT_FILE);plainFile(js);plainFile(receipt);
 if(fs.statSync(receipt).size>16384)throw Error("bounded mitigation receipt required");
 // Independently pin actual JS to the lock, never to a receipt-controlled hash.
 if(hash(fs.readFileSync(js))!==policy.lock.output_sha256)throw Error("actual Web JS differs from locked EXPECTED patched output");
 const actual=JSON.parse(fs.readFileSync(receipt,"utf8")),expected=expectedReceipt(policy);
 if(JSON.stringify(actual)!==JSON.stringify(expected))throw Error("Web mitigation receipt/version/tool/policy differs from current source");return expected;
}
export function applyFreshExport(stage,ownedRoot,policy=loadPolicy()){
 const owned=plainDir(ownedRoot);stage=plainDir(stage);
 if(path.dirname(stage)!==owned||path.basename(stage)!=="stage")throw Error("apply requires a fresh direct stage child of exact owned attempt root");
 verifyEngineAssets(stage,policy);const js=path.join(stage,"index.js"),receipt=path.join(stage,RECEIPT_FILE);plainFile(js);
 if(exists(receipt))throw Error("fresh apply cannot mutate an existing mitigation receipt; verify immutable stage instead");
 const original=fs.readFileSync(js),output=transformSource(original,policy),record=expectedReceipt(policy);
 const archive=path.join(owned,"web-gl-handles-original"),temporary=path.join(owned,"index.patched.js"),temporaryReceipt=path.join(owned,"web-gl-handles.receipt.json");
 for(const v of[archive,temporary,temporaryReceipt])if(exists(v))throw Error("preserve prior/partial mitigation attempt");
 fs.mkdirSync(archive);plainDir(archive);fs.writeFileSync(temporary,output,{flag:"wx"});fs.writeFileSync(temporaryReceipt,JSON.stringify(record,null,2)+"\n",{flag:"wx"});
 checkedRename(js,path.join(archive,"index.original.js"),owned);checkedRename(temporary,js,owned);checkedRename(temporaryReceipt,receipt,owned);
 verifyExport(stage,policy);return record;
}
function parse(argv){const mode=argv.shift();if(!["apply","verify"].includes(mode))throw Error("mode must be apply or verify");const options={};while(argv.length){const k=argv.shift();if(!["--stage","--owned-root"].includes(k)||k in options||!argv.length)throw Error("known unique flags require explicit values");options[k]=argv.shift();}if(!options["--stage"]||(mode==="apply")!==Boolean(options["--owned-root"]))throw Error("apply needs --stage and --owned-root; verify only --stage");return{mode,options};}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 try{const{mode,options}=parse(process.argv.slice(2));const result=mode==="apply"?applyFreshExport(options["--stage"],options["--owned-root"]):verifyExport(options["--stage"]);console.log(JSON.stringify({status:"verified",mode,output_sha256:result.output_sha256,policy_version:result.policy_version}));}
 catch(e){console.error(String(e.message??e));process.exitCode=1;}
}
