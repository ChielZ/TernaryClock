// ---- Ternary Time Model ----

const TERNARY_SECOND = 86400 / 19683; // ~4.3896 real seconds
const TOTAL_UNITS = 11; // 9 trits + 2 separators

function getTernaryTime() {
  const now = new Date();
  const midnight = new Date(now);
  midnight.setHours(0, 0, 0, 0);
  const realSecs = (now - midnight) / 1000;
  const sinceNoon = realSecs - 43200;
  const total = Math.max(-9841, Math.min(9841, Math.floor(sinceNoon / TERNARY_SECOND)));
  const trits = toBalancedTernary(total, 9);
  return {
    trits,
    hours: trits.slice(0, 3),
    minutes: trits.slice(3, 6),
    seconds: trits.slice(6, 9),
  };
}

function toBalancedTernary(n, digits) {
  const trits = [];
  let v = n;
  for (let i = 0; i < digits; i++) {
    let r = v % 3;
    v = Math.trunc(v / 3);
    if (r > 1) { r -= 3; v += 1; }
    if (r < -1) { r += 3; v -= 1; }
    trits.push(r);
  }
  return trits.reverse();
}

function tritsToDecimal(trits) {
  return trits.reduce((acc, t) => acc * 3 + t, 0);
}

// ---- Canvas Drawing ----

function drawClock(canvas, time, options = {}) {
  const { showLeadingZeros = true, showDecimal = false, useBalanced = false } = options;
  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;

  // Get the CSS pixel width from the container
  const cssWidth = canvas.parentElement.clientWidth * 0.92;
  const roughCellWidth = cssWidth / TOTAL_UNITS;
  const lineWidth = roughCellWidth * 0.15;
  const edgePad = lineWidth / 2 + 2;
  const cellWidth = (cssWidth - 2 * edgePad) / TOTAL_UNITS;
  const actualLineWidth = cellWidth * 0.15;
  const displayHeight = cellWidth * 3;
  const vPad = actualLineWidth * 0.6;
  const dotSize = actualLineWidth * 1.2;

  // Decimal readout
  const decimalFontSize = Math.max(14, cellWidth * 0.65);
  const decimalGap = showDecimal ? cellWidth * 0.5 : 0;
  const decimalHeight = showDecimal ? decimalFontSize * 1.5 : 0;
  const totalHeight = displayHeight + decimalGap + decimalHeight;

  // Set canvas size: CSS size for layout, pixel size for sharp rendering
  canvas.style.width = cssWidth + 'px';
  canvas.style.height = totalHeight + 'px';
  canvas.width = cssWidth * dpr;
  canvas.height = totalHeight * dpr;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

  ctx.clearRect(0, 0, cssWidth, totalHeight);
  ctx.strokeStyle = '#ecd9af';
  ctx.fillStyle = '#ecd9af';
  ctx.lineWidth = actualLineWidth;
  ctx.lineCap = 'round';

  let x = edgePad;
  const top = vPad;
  const bottom = displayHeight - vPad;

  x = drawTrits(ctx, time.hours, x, cellWidth, top, bottom, showLeadingZeros);
  x = drawDot(ctx, x, cellWidth, dotSize, displayHeight / 2);
  x = drawTrits(ctx, time.minutes, x, cellWidth, top, bottom, showLeadingZeros);
  x = drawDot(ctx, x, cellWidth, dotSize, displayHeight / 2);
  drawTrits(ctx, time.seconds, x, cellWidth, top, bottom, showLeadingZeros);

  // Decimal readout
  if (showDecimal) {
    const h = tritsToDecimal(time.hours);
    const m = tritsToDecimal(time.minutes);
    const s = tritsToDecimal(time.seconds);
    const fmt = useBalanced
      ? (v) => (v > 0 ? '+' + v : v === 0 ? '0' : '' + v)
      : (v) => '' + (v + 13);
    const text = `${fmt(h)} · ${fmt(m)} · ${fmt(s)}`;
    ctx.font = `${decimalFontSize}px Comfortaa, sans-serif`;
    ctx.globalAlpha = 0.5;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(text, cssWidth / 2, displayHeight + decimalGap + decimalHeight / 2);
    ctx.globalAlpha = 1;
  }
}

function drawTrits(ctx, trits, startX, cellWidth, top, bottom, showLeadingZeros) {
  const found = trits.findIndex(t => t !== 0);
  const first = showLeadingZeros ? 0
    : found === -1 ? trits.length - 1  // all zeros: show only the last trit
    : found;

  let x = startX;
  for (let i = 0; i < trits.length; i++) {
    if (i >= first) {
      ctx.beginPath();
      const trit = trits[i];
      if (trit === 1) {
        ctx.moveTo(x + cellWidth, top);
        ctx.lineTo(x, bottom);
      } else if (trit === -1) {
        ctx.moveTo(x, top);
        ctx.lineTo(x + cellWidth, bottom);
      } else {
        ctx.moveTo(x + cellWidth / 2, top);
        ctx.lineTo(x + cellWidth / 2, bottom);
      }
      ctx.stroke();
    }
    x += cellWidth;
  }
  return x;
}

function drawDot(ctx, startX, width, dotSize, midY) {
  const cx = startX + width / 2;
  ctx.beginPath();
  ctx.arc(cx, midY, dotSize / 2, 0, Math.PI * 2);
  ctx.fill();
  return startX + width;
}

// ---- Settings State ----

const state = {
  showLeadingZeros: true,
  showDecimal: false,
  useBalanced: false,
  settingsOpen: false,
};

// ---- DOM Setup ----

const clockCanvas = document.getElementById('clock-canvas');
const previewCanvas = document.getElementById('preview-canvas');
const clockView = document.getElementById('clock-view');
const settingsView = document.getElementById('settings-view');
const infoBtn = document.getElementById('info-btn');
const closeBtn = document.getElementById('close-btn');
const toggleZeros = document.getElementById('toggle-zeros');
const toggleDecimal = document.getElementById('toggle-decimal');
const pickerBalanced = document.getElementById('picker-balanced');
const pickerOptions = pickerBalanced.querySelectorAll('.picker-option');

// ---- Toggle Helpers ----

function updateToggle(el, value) {
  el.classList.toggle('on', value);
}

function updatePickerVisibility() {
  pickerBalanced.classList.toggle('disabled', !state.showDecimal);
}

// ---- Event Listeners ----

infoBtn.addEventListener('click', () => {
  state.settingsOpen = true;
  settingsView.classList.remove('hidden');
});

closeBtn.addEventListener('click', closeSettings);

document.querySelector('.settings-clock-preview').addEventListener('click', closeSettings);

function closeSettings() {
  state.settingsOpen = false;
  settingsView.classList.add('hidden');
}

toggleZeros.addEventListener('click', () => {
  state.showLeadingZeros = !state.showLeadingZeros;
  updateToggle(toggleZeros, state.showLeadingZeros);
});

toggleDecimal.addEventListener('click', () => {
  state.showDecimal = !state.showDecimal;
  updateToggle(toggleDecimal, state.showDecimal);
  updatePickerVisibility();
});

pickerOptions.forEach(btn => {
  btn.addEventListener('click', () => {
    state.useBalanced = btn.dataset.value === 'balanced';
    pickerOptions.forEach(b => b.classList.toggle('selected', b === btn));
  });
});

// ---- Initial Toggle State ----

updateToggle(toggleZeros, state.showLeadingZeros);
updateToggle(toggleDecimal, state.showDecimal);
updatePickerVisibility();

// ---- Render Loop ----

const TICK_INTERVAL = (TERNARY_SECOND / 27) * 1000; // sub-second tick in ms (~163ms)

function tick() {
  const time = getTernaryTime();
  const opts = {
    showLeadingZeros: state.showLeadingZeros,
    showDecimal: state.showDecimal,
    useBalanced: state.useBalanced,
  };

  drawClock(clockCanvas, time, opts);

  if (state.settingsOpen) {
    drawClock(previewCanvas, time, opts);
  }
}

setInterval(tick, TICK_INTERVAL);
tick();
