const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync('web/index.html', 'utf8');
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)][0][1];

async function shell({ standalone = false, display = false, registrations = [], ipad = false } = {}) {
  const elements = new Map();
  const timers = [];
  const events = {};
  const removed = [];
  const document = {
    baseURI: 'https://example.test/', documentElement: {}, querySelector: () => null,
    getElementById(id) {
      if (!elements.has(id)) {
        const classes = new Set();
        elements.set(id, { classes, classList: {
          add: c => classes.add(c), remove: c => classes.delete(c) },
          addEventListener() {}, parentNode: { removeChild: () => removed.push(id) } });
      }
      return elements.get(id);
    }
  };
  for (const id of ['loading', 'ios-install-banner', 'pwa-install-banner']) {
    document.getElementById(id);
  }
  const navigator = { standalone, userAgent: ipad ? 'Macintosh' : 'iPhone',
    platform: ipad ? 'MacIntel' : 'iPhone', maxTouchPoints: 5,
    serviceWorker: { getRegistrations: async () => registrations, register: async () => {} } };
  const window = { navigator, location: new URL(document.baseURI),
    matchMedia: () => ({ matches: display }),
    setTimeout: fn => timers.push(fn), addEventListener: (name, fn) => { events[name] = fn; } };
  vm.runInNewContext(script, { window, document, navigator, URL,
    MutationObserver: class { observe() {} disconnect() {} },
    sessionStorage: { getItem: () => null, setItem() {} } });
  await Promise.resolve();
  for (const timer of timers) timer();
  return { elements, events, removed };
}

test('Safari propose installation, standalone iOS ou display-mode jamais', async () => {
  for (const settings of [{}, {standalone: true}, {display: true}, {standalone: true, ipad: true}]) {
    const state = await shell(settings);
    assert.equal(state.elements.get('ios-install-banner').classes.has('show'),
      !settings.standalone && !settings.display);
    assert.equal(state.elements.get('pwa-install-banner').classes.has('show'), false);
    assert.ok(state.removed.includes('loading'));
  }
});

test('ancienne installation : seul worker Flutter connu ciblé, FCM et autres préservés', async () => {
  const calls = [];
  const worker = (name, scope = '/') => ({
    scope: 'https://example.test' + scope,
    active: { scriptURL: 'https://example.test/' + name },
    unregister: async () => { calls.push(name); }
  });
  await shell({ standalone: true, registrations: [
    worker('flutter_service_worker.js?v=old'),
    worker('firebase-messaging-sw.js', '/firebase-cloud-messaging-push-scope'),
    worker('firebase-messaging-sw.js'), worker('other.js'),
    {...worker('flutter_service_worker.js'), waiting: {scriptURL: 'https://example.test/firebase-messaging-sw.js'}}
  ]});
  assert.deepEqual(calls, ['flutter_service_worker.js?v=old']);
});

test('nouvelle installation sans worker et onglet Safari ne nettoient rien', async () => {
  await shell({standalone: true});
  let calls = 0;
  await shell({registrations: [{unregister: () => { calls++; }}]});
  assert.equal(calls, 0);
});

test('écran de chargement non interceptant, pas de transformation des coordonnées Flutter', () => {
  const loading = html.match(/#loading\s*\{([^}]+)\}/)[1];
  assert.match(loading, /pointer-events:\s*none/);
  assert.match(html, /video\[id\^="videoElement-"\]:not\(\[controls\]\)\s*\{\s*pointer-events:\s*none/);
  assert.doesNotMatch(html, /(?:touchstart|pointerdown|visualViewport)\s*[,.)]/);
});
