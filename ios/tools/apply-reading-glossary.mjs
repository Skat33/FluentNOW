#!/usr/bin/env node
// FluentNOW — scala słowniczki kontekstowe czytanek (ios/tools/data/reading-glossary.json) z readings.json,
// bez ponownego eksportu banków strony. Idempotentny.
//
// Użycie: node ios/tools/apply-reading-glossary.mjs [--check] [--root <katalog treści>]
//   --check  nic nie zapisuje; kod wyjścia 1, gdy readings.json ma nieaktualne słowniczki.
//
// Kolejność po ponownym eksporcie banków (export-web-content.mjs scala słowniczki sam, ale poprawki english-qa
// zmieniają akapity — forma ze słowniczka musi pasować do tekstu PO poprawkach):
//   node ios/tools/export-web-content.mjs
//   node ios/tools/fixes/english-qa-banks-fix.mjs   (dwukrotnie)
//   node ios/tools/apply-reading-glossary.mjs
//   node ios/tools/build-index.mjs && node ios/tools/validate-content.mjs

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DEFAULT_ROOT } from './validate-content.mjs';
import { stringify } from './export-web-content.mjs';
import { loadGlossarySource, mergeGlossary, staleGlossaries, formOccurs, GLOSSARY_SOURCE } from './lib/reading-glossary.mjs';

export function applyGlossary(root = DEFAULT_ROOT, { check = false } = {}) {
  const file = path.join(root, 'readings.json');
  const data = JSON.parse(fs.readFileSync(file, 'utf8'));
  const source = loadGlossarySource();
  const stale = staleGlossaries(data.readings, source);
  const { readings, merged, unknown } = mergeGlossary(data.readings, source);
  const missingForms = [];
  for (const r of readings) {
    for (const e of r.glossary ?? []) if (!formOccurs(r.paragraphs, e.form)) missingForms.push(`${r.id}: „${e.form}”`);
  }
  if (!check && stale.length) fs.writeFileSync(file, stringify({ ...data, readings }) + '\n', 'utf8');
  return { stale, merged, unknown, missingForms, total: readings.length };
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  let root = DEFAULT_ROOT;
  let check = false;
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--root' && argv[i + 1]) root = path.resolve(argv[++i]);
    else if (argv[i] === '--check') check = true;
  }
  const result = applyGlossary(root, { check });
  console.log(`Źródło: ${path.relative(process.cwd(), GLOSSARY_SOURCE)}`);
  console.log(`Czytanki: ${result.total}, ze słowniczkiem: ${result.merged}, nieaktualne w readings.json: ${result.stale.length}`);
  for (const id of result.unknown) console.log(`  OSTRZEŻENIE: słowniczek dla nieznanej czytanki "${id}"`);
  for (const m of result.missingForms) console.log(`  BŁĄD: forma nie występuje w tekście — ${m}`);
  if (check) {
    if (result.stale.length) { console.log(`Nieaktualne: ${result.stale.join(', ')} — uruchom bez --check.`); process.exitCode = 1; }
    else console.log('OK: readings.json zgodny ze źródłem słowniczków.');
  } else {
    console.log(result.stale.length ? 'Zapisano readings.json.' : 'Bez zmian.');
  }
  if (result.missingForms.length) process.exitCode = 1;
}
