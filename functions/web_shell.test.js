"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const indexPath = path.join(__dirname, "..", "web", "index.html");
const html = fs.readFileSync(indexPath, "utf8");

test("les scripts inline de index.html ont une syntaxe JavaScript valide", () => {
  const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
  assert.ok(scripts.length > 0);
  for (const [, source] of scripts) {
    assert.doesNotThrow(() => new Function(source));
  }
});

test("le shell web ne contient aucun overlay vidéo pré-Flutter", () => {
  assert.equal(html.includes('id="intro-overlay"'), false);
  assert.equal(html.includes('id="intro-video"'), false);
  assert.match(html, /#loading[\s\S]*pointer-events:\s*none/);
});

test("le document HTML est complet et non corrompu", () => {
  assert.match(html, /<\/body>\s*<\/html>\s*$/);
  assert.equal(/[ÃÂ]|â€|ðŸ/.test(html), false);
});
