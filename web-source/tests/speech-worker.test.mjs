import test from 'node:test';
import assert from 'node:assert/strict';
import { build } from 'esbuild';
import { Miniflare } from 'miniflare';

test('Azure Speech runs in workerd and never forwards its key through redirects', async()=>{
  const bundle=await build({stdin:{contents:`import {independentSpeech,speechFailure} from './lib/speech-providers';
export default {async fetch(req){const audio=await independentSpeech(await req.text(),'exercise');return audio || Response.json(speechFailure(),{status:503});}};`,resolveDir:process.cwd()},bundle:true,write:false,format:'esm',platform:'browser',external:['cloudflare:workers']});
  let requests=0;
  const mf=new Miniflare({modules:true,compatibilityDate:'2026-04-01',script:bundle.outputFiles[0].text,
    bindings:{AZURE_SPEECH_KEY:'test-only-key',AZURE_SPEECH_REGION:'germanywestcentral'},
    outboundService:async req=>{
      requests++;
      assert.equal(new URL(req.url).hostname,'germanywestcentral.tts.speech.microsoft.com');
      assert.equal(req.headers.get('Ocp-Apim-Subscription-Key'),'test-only-key');
      assert.equal(req.headers.get('User-Agent'),'Fluent');
      assert.equal(req.headers.get('Content-Type'),'application/ssml+xml');
      assert.equal(req.headers.get('X-Microsoft-OutputFormat'),'audio-24khz-48kbitrate-mono-mp3');
      const body=await req.text();
      if(body.includes('redirect-case')) return new Response(null,{status:302,headers:{Location:'https://untrusted.invalid/'}});
      assert.ok(body.includes('<break time="900ms"/>'));
      return new Response(new Uint8Array([73,68,51,1]),{headers:{'Content-Type':'audio/mpeg'}});
    },
  });
  try {
    const audio=await mf.dispatchFetch('https://test.invalid/',{method:'POST',body:'Please [[gap]] the window.'});
    assert.equal(audio.status,200);
    assert.equal(audio.headers.get('X-Speech-Provider'),'azure');
    assert.equal((await audio.arrayBuffer()).byteLength,4);
    assert.equal(requests,1);
    const blocked=await mf.dispatchFetch('https://test.invalid/',{method:'POST',body:'redirect-case'});
    assert.equal(blocked.status,503);
    assert.equal((await blocked.json()).code,'AZURE_HTTP_302');
    assert.equal(requests,2,'a redirect must not make another outbound request');
  } finally {await mf.dispose();}
});

test('v41: actual workerd stores binary audio in R2 and reads it after Worker restart',async()=>{
 const {mkdtemp,rm}=await import('node:fs/promises');const {tmpdir}=await import('node:os');const {join}=await import('node:path');
 const path=await mkdtemp(join(tmpdir(),'fluent-speech-r2-'));
 const bundle=await build({stdin:{contents:`import {readSpeechFile,saveSpeechFile} from './lib/speech-files';
 export default {async fetch(req){if(req.method==='POST'){await saveSpeechFile('test-hash',new Response(new Uint8Array([73,68,51,9]),{headers:{'Content-Type':'audio/mpeg','X-Speech-Provider':'azure'}}));return new Response('saved');}return await readSpeechFile('test-hash') || new Response('missing',{status:404});}};`,resolveDir:process.cwd()},bundle:true,write:false,format:'esm',platform:'browser',external:['cloudflare:workers']});
 const options={modules:true,compatibilityDate:'2026-04-01',script:bundle.outputFiles[0].text,r2Buckets:['AUDIO'],r2Persist:path};
 let mf=new Miniflare(options);
 try{
  assert.equal((await mf.dispatchFetch('https://test.invalid/',{method:'POST'})).status,200);
  await mf.dispose();mf=new Miniflare(options);
  const stored=await mf.dispatchFetch('https://test.invalid/');
  assert.equal(stored.status,200);assert.equal(stored.headers.get('X-Speech-Cache'),'file');
  assert.equal(stored.headers.get('X-Speech-Provider'),'azure');
  assert.deepEqual([...new Uint8Array(await stored.arrayBuffer())],[73,68,51,9]);
 }finally{await mf.dispose();await rm(path,{recursive:true,force:true});}
});
