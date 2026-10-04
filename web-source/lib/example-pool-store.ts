import { database } from "@/db/store";
import type { ExamplePair } from "./tutor-types";
export type PoolDescriptor = {term:string;translation:string;topic?:string;scene?:string;level:string};
type Batch = {examples:ExamplePair[]};
type PoolRow = {pool_key:string;scope:string;descriptor:string;payload:string;lease_token:string|null;lease_until:number};
const normalize=(s:string)=>s.normalize("NFKC").trim().toLowerCase().replace(/\s+/g," ");
async function digest(value:string) {
  const bytes=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,"0")).join("");
}
export async function poolIdentity(p:PoolDescriptor,owner:string) {
  const standardScene=p.topic ? `osoba w realnej sytuacji związanej z tematem „${p.topic}”` : "";
  // Only short lexical entries in generic/automatically-created scenes are shared.
  // User-authored scenes and longer sentences are isolated by account.
  const generic=(!p.scene || normalize(p.scene)===normalize(standardScene)) && p.term.trim().split(/\s+/).length<=5;
  const scope=generic ? "shared" : await digest(`owner:${owner}`);
  const key=await digest(JSON.stringify([scope,...[p.term,p.translation,p.topic || "",p.scene || ""].map(normalize)]));
  return {key,scope};
}
/** Returns a durable batch or a short pending response when another request owns the lease. */
export async function preparePoolBatch(p:PoolDescriptor,owner:string,round:number,kind:"affirmative"|"negative"|"question",create:(descriptor:PoolDescriptor,avoid:string[])=>Promise<Batch>) {
  const {key,scope}=await poolIdentity(p,owner),db=database();
  const slot=String(round*3+["affirmative","negative","question"].indexOf(kind));
  if (!Number.isInteger(round) || round<0 || round>5) throw new Error("INVALID_POOL_ROUND");
  await db.prepare("INSERT OR IGNORE INTO example_pools(pool_key,scope,descriptor,payload,updated) VALUES(?,?,?,?,?)").bind(key,scope,JSON.stringify({term:p.term,translation:p.translation,topic:p.topic,scene:p.scene,level:p.level}),"{}",Date.now()).run();
  const read=()=>db.prepare("SELECT * FROM example_pools WHERE pool_key=?").bind(key).first<PoolRow>();
  let row=(await read())!, batches=JSON.parse(row.payload) as Record<string,Batch>;
  if (batches[slot]) return {...batches[slot],cached:true};
  const token=crypto.randomUUID();
  const lock=await db.prepare("UPDATE example_pools SET lease_token=?,lease_until=? WHERE pool_key=? AND lease_until<?").bind(token,Date.now()+60000,key,Date.now()).run();
  if (!lock.meta.changes) return {pending:true};
  try {
    row=(await read())!;batches=JSON.parse(row.payload);
    if (batches[slot]) return {...batches[slot],cached:true};
    const avoid=Object.values(batches).flatMap(b=>b.examples.map(e=>e.en));
    const data=await create(JSON.parse(row.descriptor),avoid);
    const unique=new Set([...avoid,...data.examples.map(e=>e.en)].map(normalize));
    if (data.examples.length!==5 || unique.size!==avoid.length+5) throw new Error("INCOMPLETE");
    const result=await db.prepare("UPDATE example_pools SET payload=?,updated=? WHERE pool_key=? AND lease_token=? AND lease_until>?").bind(JSON.stringify({...batches,[slot]:data}),Date.now(),key,token,Date.now()).run();
    if (!result.meta.changes) return {pending:true}; // Expired work must never overwrite a newer owner.
    return {...data,cached:false};
  } finally {
    await db.prepare("UPDATE example_pools SET lease_token=NULL,lease_until=0 WHERE pool_key=? AND lease_token=?").bind(key,token).run();
  }
}
