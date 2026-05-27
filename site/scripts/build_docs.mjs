import fs from 'fs';
import path from 'path';
import matter from 'gray-matter';

// site/scripts 기준 → ../../content
const CONTENT_DIR = path.resolve('../../content');
const OUTPUT_DIR = path.resolve('../assets/docs');

const CATEGORIES = ['overview', 'flow', 'practice'];

const TAG_KEYWORDS = [
  'kafka', 'argocd', 'terraform', 'eks', 'rds', 'msk', 'redis', 'opensearch',
  'docker', 'helm', 'staging', 'dev', 'prod', 'security', 'tls', 'acl',
  'flyway', 'gradle', 'ci', 'cd', 'deploy', 'rollback', 'e2e', 'avro', 'schema',
  'jwt', 'rls', 'msa', 'rag', 'srs', 'pgvector', 'flutter', 'gateway',
];

const STOP_PARTICLES = ['은', '는', '이', '가', '을', '를', '의', '에', '로', '와', '과', '도', '만', '까지'];

function collectMarkdownFiles() {
  const files = [];
  for (const cat of CATEGORIES) {
    const dir = path.join(CONTENT_DIR, cat);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).sort()) {
      if (f.endsWith('.md')) {
        files.push({ absPath: path.join(dir, f), category: cat });
      }
    }
  }
  return files;
}

function slugify(absPath) {
  return path.basename(absPath, '.md')
    .toLowerCase()
    .replace(/[^a-z0-9가-힣_-]/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function extractToc(body) {
  const toc = [];
  for (const line of body.split('\n')) {
    const m = line.match(/^(#{2,3})\s+(.+)/);
    if (m) {
      const level = m[1].length;
      const text = m[2].trim();
      const anchor = text
        .toLowerCase()
        .replace(/[^a-z0-9가-힣\s-]/g, '')
        .replace(/\s+/g, '-');
      toc.push({ level, text, anchor });
    }
  }
  return toc;
}

function extractTags(body) {
  const lower = body.toLowerCase();
  const matched = TAG_KEYWORDS.filter(kw => {
    const regex = new RegExp(`\\b${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
    return (lower.match(regex) || []).length >= 3;
  });
  return matched.slice(0, 5);
}

function extractCompletionRate(body) {
  const checked = (body.match(/- \[x\]/gi) || []).length;
  const unchecked = (body.match(/- \[ \]/g) || []).length;
  const total = checked + unchecked;
  if (total === 0) return null;
  return Math.round((checked / total) * 100);
}

function getLastModified(absPath) {
  try {
    return fs.statSync(absPath).mtime.toISOString().slice(0, 10);
  } catch { return null; }
}

function buildSearchIndex(docs) {
  const index = {};
  for (const doc of docs) {
    // strip code blocks before indexing, title gets 3x weight
    const strippedBody = doc.body.replace(/```[\s\S]*?```/g, '').replace(/`[^`]+`/g, '');
    const text = `${doc.title} ${doc.title} ${doc.title} ${strippedBody}`;
    const tokens = text
      .split(/[\s,.;:!?()\[\]{}|/\\<>"'`~#*_=+\-\n\r\t]+/)
      .filter(Boolean);

    for (const raw of tokens) {
      let token = raw.toLowerCase();
      // strip Korean particles
      for (const p of STOP_PARTICLES) {
        if (token.endsWith(p) && token.length > p.length + 1) {
          token = token.slice(0, -p.length);
          break;
        }
      }
      if (token.length < 3 || token.length > 30) continue;
      if (/^\d+$/.test(token)) continue;
      if (!index[token]) index[token] = [];
      if (!index[token].find(e => e.s === doc.slug)) {
        index[token].push({ s: doc.slug, c: doc.category });
      }
    }
  }
  // prune tokens appearing in 80%+ of docs (too common to be useful)
  const threshold = Math.floor(docs.length * 0.8);
  for (const token of Object.keys(index)) {
    if (index[token].length > threshold) {
      delete index[token];
    }
  }

  return index;
}

async function main() {
  const files = collectMarkdownFiles();
  console.log(`Found ${files.length} markdown files`);

  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  for (const cat of CATEGORIES) {
    fs.mkdirSync(path.join(OUTPUT_DIR, cat), { recursive: true });
  }

  const indexEntries = [];
  const allDocs = [];

  for (const { absPath, category } of files) {
    const raw = fs.readFileSync(absPath, 'utf-8');
    const { data: frontmatter, content: body } = matter(raw);

    const slug = slugify(absPath);
    const title = frontmatter.title
      || body.split('\n').find(l => l.startsWith('# '))?.replace(/^#\s+/, '')
      || slug;
    const source = 'synapse-onboarding';
    const summary = '';

    const doc = {
      slug,
      title,
      category,
      source,
      tags: extractTags(body),
      summary,
      metadata: {
        lastUpdated: getLastModified(absPath),
        status: 'active',
        completionRate: extractCompletionRate(body),
      },
      toc: extractToc(body),
      body,
    };

    allDocs.push(doc);

    const docPath = path.join(OUTPUT_DIR, category, `${slug}.json`);
    fs.writeFileSync(docPath, JSON.stringify(doc, null, 2));

    indexEntries.push({
      slug: doc.slug,
      title: doc.title,
      category: doc.category,
      source: doc.source,
      tags: doc.tags,
      summary: doc.summary,
      metadata: doc.metadata,
    });
  }

  // Write index
  fs.writeFileSync(path.join(OUTPUT_DIR, 'index.json'), JSON.stringify(indexEntries, null, 2));

  // Write search index
  const searchIndex = buildSearchIndex(allDocs);
  const searchJson = JSON.stringify(searchIndex);
  fs.writeFileSync(path.join(OUTPUT_DIR, 'search-index.json'), searchJson);

  const sizeKB = (Buffer.byteLength(searchJson) / 1024).toFixed(1);
  console.log(`Built ${indexEntries.length} docs, search index ${sizeKB}KB`);
}

main().catch(console.error);
