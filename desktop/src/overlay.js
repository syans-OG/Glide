import { listen } from '@tauri-apps/api/event';

const canvas = document.getElementById('overlay-canvas');
const ctx = canvas.getContext('2d');

let width = window.innerWidth;
let height = window.innerHeight;

function resizeCanvas() {
  width = window.innerWidth;
  height = window.innerHeight;
  canvas.width = width * window.devicePixelRatio;
  canvas.height = height * window.devicePixelRatio;
  ctx.scale(window.devicePixelRatio, window.devicePixelRatio);
}

window.addEventListener('resize', resizeCanvas);
resizeCanvas();

// Pointer State
let targetState = {
  active: false,
  x: width / 2,
  y: height / 2,
  mode: 'laser',
  radius: 120,
};

let currentPos = {
  x: width / 2,
  y: height / 2,
  opacity: 0,
};

const trailHistory = [];
const MAX_TRAIL = 6;

// Listen for Pointer Events from Tauri Backend
listen('pointer-event', (event) => {
  const data = event.payload;
  if (!data.active) {
    targetState.active = false;
    return;
  }

  targetState.active = true;
  targetState.x = data.x * width;
  targetState.y = data.y * height;
  targetState.mode = data.mode || 'laser';
  targetState.radius = data.radius || 120;
});

// 60fps Animation Loop with Fluid Easing (Apple/Emil Kowalski Standard)
function renderLoop() {
  ctx.clearRect(0, 0, width, height);

  // Smooth LERP interpolation
  const lerpFactor = 0.38;
  currentPos.x += (targetState.x - currentPos.x) * lerpFactor;
  currentPos.y += (targetState.y - currentPos.y) * lerpFactor;

  // Opacity fade in/out
  const targetOpacity = targetState.active ? 1.0 : 0.0;
  currentPos.opacity += (targetOpacity - currentPos.opacity) * 0.25;

  if (currentPos.opacity > 0.01) {
    if (targetState.mode === 'spotlight') {
      renderSpotlight(currentPos.x, currentPos.y, targetState.radius, currentPos.opacity);
    } else {
      renderLaser(currentPos.x, currentPos.y, currentPos.opacity);
    }
  }

  requestAnimationFrame(renderLoop);
}

function renderLaser(x, y, opacity) {
  // Store trail history for particle spell effect
  trailHistory.unshift({ x, y, opacity });
  if (trailHistory.length > MAX_TRAIL) {
    trailHistory.pop();
  }

  // Draw motion trail
  for (let i = trailHistory.length - 1; i >= 0; i--) {
    const point = trailHistory[i];
    const trailRatio = 1 - i / MAX_TRAIL;
    const trailRadius = 5 * trailRatio;

    ctx.beginPath();
    ctx.arc(point.x, point.y, trailRadius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 69, 58, ${0.25 * trailRatio * opacity})`;
    ctx.fill();
  }

  // Outer Glow Aura
  const glowGrad = ctx.createRadialGradient(x, y, 0, x, y, 28);
  glowGrad.addColorStop(0, `rgba(255, 59, 48, ${0.75 * opacity})`);
  glowGrad.addColorStop(0.4, `rgba(255, 69, 58, ${0.35 * opacity})`);
  glowGrad.addColorStop(1, 'rgba(255, 69, 58, 0)');

  ctx.beginPath();
  ctx.arc(x, y, 28, 0, Math.PI * 2);
  ctx.fillStyle = glowGrad;
  ctx.fill();

  // Core Solid Laser Dot
  ctx.beginPath();
  ctx.arc(x, y, 6, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(255, 255, 255, ${0.95 * opacity})`;
  ctx.fill();

  ctx.beginPath();
  ctx.arc(x, y, 4.5, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(255, 59, 48, ${1.0 * opacity})`;
  ctx.fill();
}

function renderSpotlight(x, y, radius, opacity) {
  ctx.save();

  // 1. Dark Vignette Layer
  ctx.fillStyle = `rgba(0, 0, 0, ${0.62 * opacity})`;
  ctx.fillRect(0, 0, width, height);

  // 2. Punch Out Spotlight Circle
  ctx.globalCompositeOperation = 'destination-out';

  const spotlightGrad = ctx.createRadialGradient(x, y, radius * 0.7, x, y, radius);
  spotlightGrad.addColorStop(0, `rgba(0, 0, 0, ${1.0 * opacity})`);
  spotlightGrad.addColorStop(1, 'rgba(0, 0, 0, 0)');

  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fillStyle = spotlightGrad;
  ctx.fill();

  ctx.restore();
}

renderLoop();
