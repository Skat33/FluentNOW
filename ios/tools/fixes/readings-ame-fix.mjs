// Amerykańskie odpowiedniki brytyjskich zwrotów w tekstach czytanek (zgłoszenie english-qa-readings).
// Idempotentny. Kolejność po eksporcie: english-qa-banks-fix.mjs (2×) → ten skrypt →
// apply-reading-glossary.mjs → build-index.mjs → validate-content.mjs.
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { stringify } from '../export-web-content.mjs';

const file = fileURLToPath(new URL('../../FluentNOW/Resources/Content/readings.json', import.meta.url));
const REPLACEMENTS = [
  ['at short notice', 'on short notice'],
  ['At short notice', 'On short notice'],
  ['waste her journey', 'waste her trip'],
  ['free entry', 'free admission'],
  ['Free entry', 'Free admission'],
];

function fix(value, log, path) {
  if (typeof value === 'string') {
    let next = value;
    for (const [from, to] of REPLACEMENTS) next = next.split(from).join(to);
    if (next !== value) log.push(path);
    return next;
  }
  if (Array.isArray(value)) return value.map((item, index) => fix(item, log, `${path}[${index}]`));
  if (value && typeof value === 'object') {
    const out = {};
    for (const [key, item] of Object.entries(value)) {
      // Słowniczek ma własne źródło prawdy (tools/data/reading-glossary.json) — nie ruszamy go tutaj.
      out[key] = key === 'glossary' ? item : fix(item, log, `${path}.${key}`);
    }
    return out;
  }
  return value;
}

const data = JSON.parse(fs.readFileSync(file, 'utf8'));
const log = [];
const fixed = fix(data, log, 'readings');
if (log.length) fs.writeFileSync(file, stringify(fixed) + '\n');
console.log(`readings-ame-fix: zmienionych pól ${log.length}`);
for (const path of log) console.log('  ' + path);
