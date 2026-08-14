"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const indexPath = path.join(__dirname, "..", "web", "index.html");
const html = fs.readFileSync(indexPath, "utf8");
const webWorkflow = fs.readFileSync(
  path.join(__dirname, "..", ".github", "workflows", "deploy-web.yml"),
  "utf8",
);
const androidWorkflow = fs.readFileSync(
  path.join(__dirname, "..", ".github", "workflows", "build.yml"),
  "utf8",
);
const functionsWorkflow = fs.readFileSync(
  path.join(__dirname, "..", ".github", "workflows", "deploy-functions.yml"),
  "utf8",
);

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

test("les builds clients ne publient aucun secret serveur", () => {
  assert.doesNotMatch(webWorkflow, /assets\/service_account\.json/);
  assert.doesNotMatch(webWorkflow, /GEMINI_API_KEY/);
  assert.doesNotMatch(androidWorkflow, /GEMINI_API_KEY/);
  assert.doesNotMatch(webWorkflow, /SERVICE_ACCOUNT_BASE64|sa\.json/);
  assert.doesNotMatch(functionsWorkflow, /SERVICE_ACCOUNT_BASE64|sa\.json/);
  assert.match(webWorkflow, /google-github-actions\/auth@v3/);
  assert.match(functionsWorkflow, /google-github-actions\/auth@v3/);
  assert.match(webWorkflow, /id-token:\s*write/);
  assert.match(functionsWorkflow, /id-token:\s*write/);
});

test("le workflow Web ne déploie que Firebase Hosting", () => {
  assert.match(webWorkflow, /firebase deploy --only hosting/);
  assert.doesNotMatch(webWorkflow, /firebase deploy --only firestore/);
});

test("les Functions ne sont jamais redéployées automatiquement ou avec force", () => {
  assert.match(functionsWorkflow, /workflow_dispatch:/);
  assert.doesNotMatch(functionsWorkflow, /\bpush:/);
  assert.doesNotMatch(functionsWorkflow, /\s--force(?:\s|$)/);
});
