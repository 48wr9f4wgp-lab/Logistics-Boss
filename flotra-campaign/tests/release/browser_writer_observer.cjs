'use strict';
// Read-only engine/lifecycle observation, shared by Playwright and native CDP.
module.exports = config => {
    const data = { realm: crypto.randomUUID(), engineInstances: 0, starts: [], locks: [], writes: [], statuses: [], lifecycle: [], input: [] };
    const stamp = () => Math.round(performance.now());
    const controls = new Map();
    window.__writerHarness = { data, release: name => {
      if (!controls.has(name)) throw new Error('No held native callback for ' + name);
      controls.get(name)(); controls.delete(name);
    } };
    for (const type of ['pageshow', 'pagehide']) addEventListener(type, event => {
      const item = { type, persisted: event.persisted, trusted: event.isTrusted, at: stamp(), realm: data.realm, writes: data.writes.length, lockRequests: data.locks.length, starts: data.starts.length };
      data.lifecycle.push(item);
      console.debug('WRITER_LIFECYCLE ' + JSON.stringify(item));
    });
    for (const type of ['mousedown', 'mouseup', 'keydown']) addEventListener(type, event => {
      data.input.push({ type, trusted: event.isTrusted, target: event.target?.id || event.target?.nodeName, focused: document.hasFocus(), visibility: document.visibilityState, key: event.key, x: event.clientX, y: event.clientY, at: stamp() });
      if (data.input.length > 300) data.input.shift();
    }, true);
    new MutationObserver(records => {
      for (const record of records) {
        if (record.target.id === 'status-label' || record.target.id === 'status-notice') {
          const text = Array.from(record.addedNodes, node => node.textContent).join('') || record.target.textContent;
          data.statuses.push({ text, at: stamp() });
        }
      }
    }).observe(document, { subtree: true, childList: true, characterData: true });
    for (const method of ['setItem', 'removeItem', 'clear']) {
      const native = Storage.prototype[method];
      Storage.prototype[method] = function (...args) {
        if (this === localStorage) data.writes.push({ method, key: args[0] ?? null, length: String(args[1] ?? '').length, at: stamp() });
        return Reflect.apply(native, this, args);
      };
    }
    // index.js declares a global lexical `const Engine`, so replacing only
    // window.Engine would miss the loader's real constructor. Its exported
    // feature check runs after `const engine` is constructed and before ready().
    // Observe that actual instance then forward startGame and the check intact.
    // No game/QA method is called or exposed by this instrumentation.
    let EngineValue;
    const observed = new WeakSet();
    Object.defineProperty(window, 'Engine', {
      configurable: true, get: () => EngineValue,
      set(value) {
        EngineValue = value;
        if (typeof value?.getMissingFeatures !== 'function') return;
        const check = value.getMissingFeatures;
        value.getMissingFeatures = function (...args) {
          const instance = (0, eval)('engine'); // Read the real loader lexical.
          if (!observed.has(instance)) {
            observed.add(instance); data.engineInstances++;
            const start = instance.startGame;
            instance.startGame = function (...args) {
              const item = { at: stamp(), state: 'pending' }; data.starts.push(item);
              const result = Reflect.apply(start, this, args);
              result.then(() => { item.state = 'fulfilled'; }, error => { item.state = 'rejected'; item.error = String(error); });
              return result;
            };
          }
          return Reflect.apply(check, this, args);
        };
      },
    });
    const manager = navigator.locks;
    if (config.api === 'absent') {
      Object.defineProperty(navigator, 'locks', { configurable: true, value: undefined });
    } else if (config.api === 'reject') {
      Object.defineProperty(navigator, 'locks', { configurable: true, value: {
        request(name, options) { data.locks.push({ name, options, refused: true, at: stamp() }); return Promise.reject(new DOMException('Synthetic CI API refusal', 'SecurityError')); },
      } });
    } else {
      if (!manager) throw new Error('Actual Web Locks unavailable in the CI browser');
      const nativeRequest = manager.request.bind(manager);
      Object.defineProperty(manager, 'request', { configurable: true, value(name, options, callback) {
        const item = { name, options, requestedAt: stamp() }; data.locks.push(item);
        return nativeRequest(name, options, async lock => {
          item.nativeGrant = lock ? { name: lock.name, mode: lock.mode, type: Object.prototype.toString.call(lock) } : null;
          item.grantedAt = stamp();
          if (lock && config.delayLock === name) {
            item.delayed = true;
            await new Promise(resolve => controls.set(name, resolve));
          }
          item.deliveredAt = stamp();
          try { return await callback(lock); }
          finally { item.callbackCompletedAt = stamp(); }
        });
      } });
    }
  };
