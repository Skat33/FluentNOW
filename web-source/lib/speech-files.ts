import {env} from 'cloudflare:workers';
// Durable binary objects, separate from evictable edge/device caches. The hash
// includes exact spoken text, gap state, accent/model and pronunciation version.
const key=(hash:string)=>`speech/v3/${hash}`;
export async function readSpeechFile(hash:string):Promise<Response|undefined> {
 if(!env.AUDIO)return;
 try {
  const object=await env.AUDIO.get(key(hash));
  if(!object)return;
  const headers=new Headers();object.writeHttpMetadata(headers);
  headers.set('ETag',`"${hash}"`);
  headers.set('Content-Length',String(object.size));
  headers.set('X-Speech-Cache','file');
  if(object.customMetadata?.provider)headers.set('X-Speech-Provider',object.customMetadata.provider);
  if(object.customMetadata?.credit)headers.set('X-Speech-Credit',object.customMetadata.credit);
  return new Response(object.body,{headers});
 } catch {console.warn('Speech file read unavailable');}
}
export async function saveSpeechFile(hash:string,response:Response) {
 if(!env.AUDIO || !response.ok)return;
 try {
  const mime=response.headers.get('Content-Type')||'';
  if(!/^audio\//.test(mime))return;
  const bytes=await response.arrayBuffer();
  if(!bytes.byteLength || bytes.byteLength>8*1024*1024)return;
  await env.AUDIO.put(key(hash),bytes,{
   httpMetadata:{contentType:mime,cacheControl:'public, max-age=31536000, immutable'},
   customMetadata:{provider:response.headers.get('X-Speech-Provider')||'unknown',credit:response.headers.get('X-Speech-Credit')||''},
  });
 } catch {console.warn('Speech file write unavailable');}
}
