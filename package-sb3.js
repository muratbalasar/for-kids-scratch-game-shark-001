const fs = require('fs');
const path = require('path');
const Packager = require('@turbowarp/packager');

const run = async () => {
  const inputFile = process.argv[2] || path.join(__dirname, '_GAME_pkg.sb3');
  const outputDir  = path.join(__dirname, 'output');
  const outputFile = path.join(outputDir, 'index.html');

  if (!fs.existsSync(inputFile)) {
    console.error(`Error: input file not found: ${inputFile}`);
    process.exit(1);
  }

  if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir);

  console.log('Reading sb3 file...');
  const projectData = fs.readFileSync(inputFile);

  console.log('Loading project...');
  const loadedProject = await Packager.loadProject(projectData, (type, a, b) => {
    if (b) process.stdout.write(`\r  ${type}: ${a}/${b}   `);
    else process.stdout.write(`\r  ${type}: ${Math.round(a * 100)}%   `);
  });
  console.log('\nPackaging...');

  const packager = new Packager.Packager();
  packager.project = loadedProject;

  const result = await packager.package();

  fs.writeFileSync(outputFile, result.data);
  
  // Inject mobile UX enhancements after file is written successfully
  const mobileCSS = `<style>
html, body { height: 100%; margin: 0; padding: 0; }
body { min-height: -webkit-fill-available; }
@supports (height: 100dvh) { body { min-height: 100dvh; } }
canvas { touch-action: none; display: block; }
* { -webkit-tap-highlight-color: transparent; }
</style>`;

  const touchControlsHTML = `<style id="tw-touch-controls-style">
#tw-touch-controls {
  position: fixed;
  inset: auto 0 0 0;
  display: none;
  justify-content: space-between;
  align-items: flex-end;
  gap: 20px;
  padding: max(10px, env(safe-area-inset-top)) 12px max(12px, env(safe-area-inset-bottom));
  z-index: 2147483647;
  pointer-events: none;
  user-select: none;
}

#tw-touch-controls .tc-panel {
  pointer-events: auto;
  display: grid;
  gap: 8px;
}

#tw-touch-controls .tc-dpad {
  grid-template-columns: repeat(3, 56px);
  grid-template-rows: repeat(3, 56px);
}

#tw-touch-controls .tc-btn {
  border: none;
  border-radius: 999px;
  color: #fff;
  font: 700 18px/1.1 system-ui, -apple-system, Segoe UI, sans-serif;
  box-shadow: 0 6px 18px rgba(0, 0, 0, 0.25);
  touch-action: none;
}

#tw-touch-controls .tc-panel-blue .tc-btn {
  background: rgba(32, 122, 255, 0.74);
}

#tw-touch-controls .tc-panel-red .tc-btn {
  background: rgba(234, 64, 64, 0.74);
}

#tw-touch-controls .tc-btn:active,
#tw-touch-controls .tc-btn.tc-active {
  filter: brightness(1.2);
}

#tw-touch-controls .tc-up { grid-column: 2; grid-row: 1; }
#tw-touch-controls .tc-left { grid-column: 1; grid-row: 2; }
#tw-touch-controls .tc-right { grid-column: 3; grid-row: 2; }
#tw-touch-controls .tc-down { grid-column: 2; grid-row: 3; }

@media (hover: none), (pointer: coarse), (max-width: 1024px) {
  #tw-touch-controls { display: flex; }
}
</style>
<div id="tw-touch-controls" aria-label="On-screen touch controls">
  <div class="tc-panel tc-dpad tc-panel-blue" aria-label="Shark 1 movement">
    <button type="button" id="tc1-up" class="tc-btn tc-up" aria-label="Shark 1 move up">▲</button>
    <button type="button" id="tc1-left" class="tc-btn tc-left" aria-label="Shark 1 move left">◀</button>
    <button type="button" id="tc1-right" class="tc-btn tc-right" aria-label="Shark 1 move right">▶</button>
    <button type="button" id="tc1-down" class="tc-btn tc-down" aria-label="Shark 1 move down">▼</button>
  </div>
  <div class="tc-panel tc-dpad tc-panel-red" aria-label="Shark 2 movement">
    <button type="button" id="tc2-up" class="tc-btn tc-up" aria-label="Shark 2 move up">▲</button>
    <button type="button" id="tc2-left" class="tc-btn tc-left" aria-label="Shark 2 move left">◀</button>
    <button type="button" id="tc2-right" class="tc-btn tc-right" aria-label="Shark 2 move right">▶</button>
    <button type="button" id="tc2-down" class="tc-btn tc-down" aria-label="Shark 2 move down">▼</button>
  </div>
</div>
<script>
(function () {
  var root = document.getElementById('tw-touch-controls');
  if (!root) return;

  var keyMap = {
    'tc1-left':  { key: 'ArrowLeft',  code: 'ArrowLeft' },
    'tc1-right': { key: 'ArrowRight', code: 'ArrowRight' },
    'tc1-up':    { key: 'ArrowUp',    code: 'ArrowUp' },
    'tc1-down':  { key: 'ArrowDown',  code: 'ArrowDown' },
    'tc2-left':  { key: 'a',          code: 'KeyA' },
    'tc2-right': { key: 's',          code: 'KeyS' },
    'tc2-up':    { key: 'w',          code: 'KeyW' },
    'tc2-down':  { key: 'z',          code: 'KeyZ' }
  };

  var active = new Set();

  var emit = function (type, payload) {
    var isDown = type === 'keydown';

    if (window.vm && typeof window.vm.postIOData === 'function') {
      window.vm.postIOData('keyboard', {
        key: payload.key,
        isDown: isDown
      });
    }

    var event = new KeyboardEvent(type, {
      key: payload.key,
      code: payload.code,
      bubbles: true,
      cancelable: true
    });
    window.dispatchEvent(event);
    document.dispatchEvent(event);
  };

  var press = function (id) {
    var payload = keyMap[id];
    if (!payload || active.has(id)) return;
    active.add(id);
    emit('keydown', payload);
    var btn = document.getElementById(id);
    if (btn) btn.classList.add('tc-active');
  };

  var release = function (id) {
    var payload = keyMap[id];
    if (!payload || !active.has(id)) return;
    active.delete(id);
    emit('keyup', payload);
    var btn = document.getElementById(id);
    if (btn) btn.classList.remove('tc-active');
  };

  var releaseAll = function () {
    Array.from(active).forEach(release);
  };

  Object.keys(keyMap).forEach(function (id) {
    var btn = document.getElementById(id);
    if (!btn) return;

    btn.addEventListener('pointerdown', function (e) {
      e.preventDefault();
      try { btn.setPointerCapture(e.pointerId); } catch (_) {}
      press(id);
    }, { passive: false });

    ['pointerup', 'pointercancel', 'pointerleave', 'lostpointercapture'].forEach(function (eventName) {
      btn.addEventListener(eventName, function (e) {
        e.preventDefault();
        release(id);
      }, { passive: false });
    });
  });

  window.addEventListener('blur', releaseAll);
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) releaseAll();
  });
})();
</script>`;

  let html = fs.readFileSync(outputFile, 'utf8');

  const lower = html.toLowerCase();

  const headCloseIdx = lower.indexOf('</head>');
  if (headCloseIdx !== -1) {
    html = html.slice(0, headCloseIdx) + mobileCSS + '\n' + html.slice(headCloseIdx);
  }

  const lowerAfterHead = html.toLowerCase();
  const htmlCloseIdx = lowerAfterHead.lastIndexOf('</html>');
  const searchLimit = htmlCloseIdx === -1 ? lowerAfterHead.length : htmlCloseIdx;
  const bodyCloseIdx = lowerAfterHead.lastIndexOf('</body>', searchLimit);
  if (bodyCloseIdx !== -1) {
    html = html.slice(0, bodyCloseIdx) + touchControlsHTML + '\n' + html.slice(bodyCloseIdx);
  }

  fs.writeFileSync(outputFile, html, 'utf8');
  console.log(`Done! Output: ${outputFile} (${(result.data.length / 1024 / 1024).toFixed(2)} MB)`);
};

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
