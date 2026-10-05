/* CSS pixels are the game's logical coordinates; DPR only increases sharpness.
 * No persistence, gameplay state, or storage keys are accessed by this bridge. */
(function () {
  'use strict';
  const canvas = document.getElementById('canvas');
  const api = { metricsJSON: '', read: () => JSON.parse(api.metricsJSON || '{}') };
  window.FlotraViewport = api;
  // Godot's Web loader maps touchcancel to an ordinary touchend. Notify the
  // input owner before that loader handles the event, without swallowing the
  // release it needs to clear engine state. The callback drains earlier input
  // before invalidating its held gestures, so back-to-back canceled touches
  // cannot re-arm a button when their starts are processed on a later frame.
  let cancelTouch = null;
  api.setTouchCancelHandler = handler => { cancelTouch = typeof handler === 'function' ? handler : null; };
  canvas.addEventListener('touchcancel', () => {
    if (cancelTouch) cancelTouch();
  }, { capture: true, passive: true });
  // Godot's Web mouse-motion bridge omits the DOM buttons bitmask. Expose the
  // observed mouse state read-only so a missed release cannot keep panning on
  // hover. Pointer capture and browser defaults remain untouched.
  let mouseButtons = -1;
  Object.defineProperty(api, 'mouseButtons', { get: () => mouseButtons });
  for (const type of ['pointerdown', 'pointermove', 'pointerup', 'pointercancel']) {
    window.addEventListener(type, event => {
      if (event.pointerType === 'mouse') mouseButtons = type === 'pointercancel' ? 0 : event.buttons;
    }, { capture: true, passive: true });
  }
  window.addEventListener('blur', () => { mouseButtons = 0; }, { capture: true, passive: true });
  let scheduled = false;
  function sync() {
    scheduled = false;
    const visual = window.visualViewport;
    // Browser toolbars and the on-screen keyboard can change the visible height
    // without changing the layout viewport. CSS env() reserves notch/home space.
    const visibleHeight = visual && visual.scale === 1 ? Math.min(window.innerHeight, visual.height) : window.innerHeight;
    document.documentElement.style.setProperty('--flotra-visible-height', `${visibleHeight}px`);
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.max(1, Number(window.devicePixelRatio) || 1);
    const width = Math.max(1, Math.round(rect.width * dpr));
    const height = Math.max(1, Math.round(rect.height * dpr));
    if (canvas.width !== width) canvas.width = width;
    if (canvas.height !== height) canvas.height = height;
    api.metricsJSON = JSON.stringify({
      width: rect.width, height: rect.height, x: rect.x, y: rect.y,
      dpr, backingWidth: canvas.width, backingHeight: canvas.height,
    });
  }
  function schedule() {
    if (!scheduled) { scheduled = true; requestAnimationFrame(sync); }
  }
  window.addEventListener('resize', schedule);
  window.addEventListener('orientationchange', schedule);
  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', schedule);
    window.visualViewport.addEventListener('scroll', schedule);
  }
  if (window.ResizeObserver) new ResizeObserver(schedule).observe(canvas);
  // DPR can change when a desktop window moves between displays, without resize.
  function watchDPR() {
    if (!window.matchMedia) return;
    const query = window.matchMedia(`(resolution: ${window.devicePixelRatio || 1}dppx)`);
    query.addEventListener('change', () => { schedule(); watchDPR(); }, { once: true });
  }
  watchDPR();
  sync();
}());
