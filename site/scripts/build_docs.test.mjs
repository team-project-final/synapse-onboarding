import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

const SCRIPTS = path.resolve(import.meta.dirname);
const OUTPUT = path.resolve(SCRIPTS, '../assets/docs');

test('build produces index.json with overview category entry', () => {
  execSync('node build_docs.mjs', { cwd: SCRIPTS });
  const index = JSON.parse(fs.readFileSync(path.join(OUTPUT, 'index.json'), 'utf-8'));
  assert.ok(Array.isArray(index));
  const entry = index.find((d) => d.slug === '01-what-is-synapse');
  assert.ok(entry, 'expected 01-what-is-synapse in index');
  assert.equal(entry.category, 'overview');
  assert.equal(entry.source, 'synapse-onboarding');
});

test('per-doc JSON has body and toc', () => {
  const doc = JSON.parse(
    fs.readFileSync(path.join(OUTPUT, 'overview', '01-what-is-synapse.json'), 'utf-8'),
  );
  assert.match(doc.body, /통합 학습-지식 그래프/);
  assert.ok(Array.isArray(doc.toc));
  assert.ok(doc.toc.some((t) => t.text === '한 줄 정의'));
});
