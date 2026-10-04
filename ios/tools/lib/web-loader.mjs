// Ładowanie modułów TypeScript strony (web-source/lib) bezpośrednio w Node 24 — bez kopiowania i bez modyfikacji plików.
// - importy bez rozszerzeń → .ts / .tsx / index.ts
// - alias "@/..." → katalog web-source
// - import JSON → moduł ESM z `export default`
// - "zod" → atrapa (łańcuchowy Proxy), bo eksport nie wywołuje walidacji
// - typy usuwane przez module.stripTypeScriptTypes
// - opcjonalnie dopisuje w pamięci eksporty prywatnych stałych (EXTRA_EXPORTS), np. dane w tutor-local.ts.

import fs from 'node:fs';
import path from 'node:path';
import { pathToFileURL, fileURLToPath } from 'node:url';
import { registerHooks, stripTypeScriptTypes, builtinModules } from 'node:module';

export const WEB_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../../web-source');

const EXTRA_EXPORTS = {
  'lib/tutor-local.ts': 'export { STARTER as __STARTER, pairs as __pairs, aliases as __aliases, advancedCandidates as __advancedCandidates, readings as __readings, extraReadings as __extraReadings, grammarQuestions as __grammarQuestions, idiomQuestions as __idiomQuestions };',
  'lib/data/idiom-bank.ts': 'export { rows as __rows, translations as __translations };',
  'lib/production.ts': 'export { starters as __starters };',
};

const ZOD_STUB = `
const handler = { get(t, k) { if (k === Symbol.toPrimitive) return () => ''; if (k === 'then') return undefined; return proxy; }, apply() { return proxy; } };
const proxy = new Proxy(function () {}, handler);
export const z = proxy; export default proxy;`;

const EXT = ['.ts', '.tsx', '.mjs', '.js', '.json'];

function tryFile(p) {
  if (fs.existsSync(p) && fs.statSync(p).isFile()) return p;
  for (const e of EXT) if (fs.existsSync(p + e)) return p + e;
  for (const e of EXT) if (fs.existsSync(path.join(p, 'index' + e))) return path.join(p, 'index' + e);
  return null;
}

let registered = false;
export function registerWebLoader() {
  if (registered) return;
  registered = true;
  registerHooks({
    resolve(specifier, context, nextResolve) {
      if (specifier === 'zod') return { url: 'stub:zod', shortCircuit: true, format: 'module' };
      let target = null;
      if (specifier.startsWith('@/')) target = path.join(WEB_ROOT, specifier.slice(2));
      else if ((specifier.startsWith('./') || specifier.startsWith('../')) && context.parentURL?.startsWith('file:')) {
        target = path.resolve(path.dirname(fileURLToPath(context.parentURL)), specifier);
      }
      if (target && target.startsWith(WEB_ROOT)) {
        const found = tryFile(target);
        if (found) return { url: pathToFileURL(found).href, shortCircuit: true };
      }
      const bare = !specifier.startsWith('.') && !specifier.startsWith('/') && !specifier.startsWith('file:') && !specifier.startsWith('node:') && !builtinModules.includes(specifier);
      if (bare && context.parentURL && fileURLToPath(context.parentURL).startsWith(WEB_ROOT)) {
        throw new Error(`web-loader: nieobsługiwany import "${specifier}" w ${context.parentURL}`);
      }
      return nextResolve(specifier, context);
    },
    load(url, context, nextLoad) {
      if (url === 'stub:zod') return { format: 'module', source: ZOD_STUB, shortCircuit: true };
      if (url.startsWith('file:')) {
        const file = fileURLToPath(url);
        if (file.startsWith(WEB_ROOT)) {
          const rel = path.relative(WEB_ROOT, file).split(path.sep).join('/');
          if (file.endsWith('.json')) {
            return { format: 'module', source: `export default ${fs.readFileSync(file, 'utf8')};`, shortCircuit: true };
          }
          if (file.endsWith('.ts') || file.endsWith('.tsx')) {
            let src = fs.readFileSync(file, 'utf8');
            src = stripTypeScriptTypes(src, { mode: 'strip' });
            if (EXTRA_EXPORTS[rel]) src += '\n' + EXTRA_EXPORTS[rel] + '\n';
            return { format: 'module', source: src, shortCircuit: true };
          }
        }
      }
      return nextLoad(url, context);
    },
  });
}

export async function importWeb(relPath) {
  registerWebLoader();
  return import(pathToFileURL(path.join(WEB_ROOT, relPath)).href);
}
