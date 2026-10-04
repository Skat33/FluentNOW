// Reproduce the A4 comparison with the exact published v31 source.
// Run from the project root: node scripts/session-simulation.mjs
import { build } from "esbuild";
import { execFileSync } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import path from "node:path";

const directory = path.resolve(".sites-runtime/simulation");
mkdirSync(directory, {recursive:true});
const baseline = execFileSync("git", ["show", "ac55b3455f5e9a6061b3a13808ce20d0a930ab1a:lib/learning.ts"], {encoding:"utf8"});
await build({stdin:{contents:baseline,loader:"ts",resolveDir:path.resolve("lib")},bundle:true,platform:"node",format:"esm",outfile:path.join(directory,"baseline.mjs")});
await build({entryPoints:["lib/learning.ts","lib/production.ts"],bundle:true,platform:"node",format:"esm",outdir:directory,outExtension:{".js":".mjs"}});
const previous = await import(pathToFileURL(path.join(directory,"baseline.mjs")));
const current = await import(pathToFileURL(path.join(directory,"learning.mjs")));
const production = await import(pathToFileURL(path.join(directory,"production.mjs")));
const originalNow = Date.now;
Date.now = () => 1789691000000;
function simulate(lib) {
  let state = {...lib.seed(),words:[],reviews:[],collections:[],session:null,demo:false};
  const template = lib.seed().words[0];
  state.words = Array.from({length:40},(_,i)=>({...template,id:`w${i}`,en:`term${i}`,created:1,hard:false,important:false,archived:false,meanings:[{...template.meanings[0],id:`m-w${i}`,translation:`sens ${i}`,examples:[`I use term${i} every day.`],scores:{}}]}));
  let x=17;
  const random=()=>((x=(x*1664525+1013904223)>>>0)/4294967296);
  const result=[];
  for(let round=0;round<5;round++) {
    const session=lib.makeSession(state,10,"mixed",undefined,random);
    const types=session.tasks.map(task=>task.type);
    result.push({session:round+1,types,count:types.length,seconds:types.reduce((sum,type)=>sum+lib.taskSeconds[type],0),counts:[0,1,2,3,4].map(type=>types.filter(t=>t===type).length)});
    state.session=session;
    for(const task of session.tasks) state=lib.recordAnswer(state,task,true,3,3,false,true);
  }
  return result;
}
try {
  const result={before:simulate(previous),after:simulate(current),productionTenBytes:Buffer.byteLength(JSON.stringify({...production.starterProduction("B2"),items:Array.from({length:10},(_,i)=>production.starterProduction("B2").items[i%4])}))};
  writeFileSync(path.join(directory,"result.json"),JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
} finally { Date.now=originalNow; }
