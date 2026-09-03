import { invoke } from '@tauri-apps/api/core';
import { listen } from '@tauri-apps/api/event';
import { getCurrentWindow } from '@tauri-apps/api/window';
import QRCode from 'qrcode';

const appWindow = getCurrentWindow();

// DOM Elements
const statusDot = document.getElementById('status-dot');
const statusText = document.getElementById('status-text');
const qrcodeCanvas = document.getElementById('qrcode-canvas');
const themeToggle = document.getElementById('theme-toggle');
const tabWifi = document.getElementById('tab-wifi');
const tabBluetooth = document.getElementById('tab-bluetooth');
const panelWifi = document.getElementById('panel-wifi');
const panelBluetooth = document.getElementById('panel-bluetooth');
const btHostName = document.getElementById('bt-host-name');
const btnOpenBt = document.getElementById('btn-open-bt');
const winMinimize = document.getElementById('win-minimize');
const winClose = document.getElementById('win-close');

// Window Controls
winMinimize?.addEventListener('click', () => {
  appWindow.minimize();
});

winClose?.addEventListener('click', () => {
  // Exit the whole app (main + overlay windows + background servers) so the
  // process/terminal terminates, not just the main window.
  invoke('exit_app').catch((err) => {
    console.error('exit_app failed:', err);
    appWindow.close();
  });
});

// Tab Switcher
tabWifi?.addEventListener('click', () => {
  tabWifi.classList.add('active');
  tabBluetooth?.classList.remove('active');
  panelWifi?.classList.add('active');
  panelBluetooth?.classList.remove('active');
});

tabBluetooth?.addEventListener('click', () => {
  tabBluetooth.classList.add('active');
  tabWifi?.classList.remove('active');
  panelBluetooth?.classList.add('active');
  panelWifi?.classList.remove('active');
});

// Open Bluetooth Windows Settings
btnOpenBt?.addEventListener('click', async () => {
  try {
    await invoke('open_bluetooth_settings');
  } catch (err) {
    console.error('Failed to open bluetooth settings:', err);
  }
});

// Theme Switcher
let isDark = true;
themeToggle?.addEventListener('click', () => {
  isDark = !isDark;
  document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
});

// Server error display
let errorOverlay = null;

function showServerError(message) {
  if (errorOverlay) return;
  errorOverlay = document.createElement('div');
  errorOverlay.style.cssText = `
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.85); display: flex; align-items: center;
    justify-content: center; z-index: 9999; padding: 20px;
  `;
  errorOverlay.innerHTML = `
    <div style="background: #1a1a2e; border: 1px solid #ff3b3b; border-radius: 16px;
      padding: 24px; text-align: center; max-width: 300px;">
      <div style="font-size: 32px; margin-bottom: 12px;">⚠️</div>
      <div style="color: #ff3b3b; font-weight: 700; font-size: 14px; margin-bottom: 8px;">
        Server Error
      </div>
      <div style="color: #888; font-size: 12px; margin-bottom: 16px;">
        ${message.includes('address already in use')
          ? 'Port 8765 sudah digunakan. Tutup aplikasi Glide lain atau restart komputer.'
          : message}
      </div>
      <button onclick="this.parentElement.parentElement.remove(); window.__errorOverlay = null;"
        style="background: #ff3b3b; color: white; border: none; padding: 8px 20px;
          border-radius: 8px; cursor: pointer; font-weight: 600; font-size: 12px;">
        Tutup
      </button>
    </div>
  `;
  document.body.appendChild(errorOverlay);
}

// Initialize Host Info & Render QR Code
async function initHostInfo() {
  try {
    const info = await invoke('get_connection_info');
    if (info.hostname && btHostName) {
      btHostName.textContent = info.hostname;
    }

    // Auth token comes from the command (exact token the servers enforce).
    const authToken = info.token || window.__AUTH_TOKEN || '';
    const tokenEl = document.getElementById('auth-token-text');
    if (tokenEl) tokenEl.textContent = authToken || '(tidak ada)';
    const btCodeEl = document.getElementById('bt-code-text');
    if (btCodeEl) btCodeEl.textContent = info.bt_code || '(tidak ada)';

    // Generate Standard Clean QR Code with auth token
    const payload = JSON.stringify({
      ip: info.ip,
      port: info.port,
      ws: info.ws_url,
      token: authToken,
    });

    await QRCode.toCanvas(qrcodeCanvas, payload, {
      width: 172,
      margin: 1,
      color: {
        dark: '#050507',
        light: '#FFFFFF',
      },
      errorCorrectionLevel: 'L',
    });
  } catch (err) {
    console.error('Failed to init host info:', err);
    QRCode.toCanvas(qrcodeCanvas, '127.0.0.1:8765', {
      width: 172,
      margin: 1,
      color: {
        dark: '#050507',
        light: '#FFFFFF',
      },
    });
  }
}

// Listen to Device Status Events from Rust
let minimizeTimeout = null;
let isDeviceConnected = false;
const modeTabs = document.querySelector('.mode-tabs');
const panelConnected = document.getElementById('panel-connected');
const autoMinimizeBar = document.getElementById('auto-minimize-bar');

listen('device-status', async (event) => {
  const data = event.payload;
  if (data.client_count > 0) {
    isDeviceConnected = true;
    statusDot.className = 'status-dot connected';
    statusText.textContent = `HP Terhubung (${data.client_count} device)`;

    // Hide tabs & standard panels, show connected success card
    if (modeTabs) modeTabs.style.display = 'none';
    if (panelWifi) panelWifi.classList.remove('active');
    if (panelBluetooth) panelBluetooth.classList.remove('active');
    if (panelConnected) panelConnected.classList.add('active');

    // Trigger visual progress bar
    setTimeout(() => {
      if (autoMinimizeBar) autoMinimizeBar.style.width = '100%';
    }, 50);

    // Auto-minimize after 1.25s so user can immediately present PowerPoint/Canva
    clearTimeout(minimizeTimeout);
    minimizeTimeout = setTimeout(async () => {
      try {
        await appWindow.minimize();
      } catch (e) {
        console.error('Failed to minimize window:', e);
      }
    }, 1250);
  } else {
    // DISCONNECTED: Restore & Focus Window Automatically!
    clearTimeout(minimizeTimeout);
    if (autoMinimizeBar) autoMinimizeBar.style.width = '0%';

    statusDot.className = 'status-dot';
    statusText.textContent = 'Menunggu HP terhubung...';

    // Restore tabs and active panels
    if (panelConnected) panelConnected.classList.remove('active');
    if (modeTabs) modeTabs.style.display = 'flex';
    if (tabBluetooth && tabBluetooth.classList.contains('active')) {
      if (panelBluetooth) panelBluetooth.classList.add('active');
    } else {
      if (panelWifi) panelWifi.classList.add('active');
    }

    // If it was previously connected and now disconnected, auto-restore window!
    if (isDeviceConnected) {
      isDeviceConnected = false;
      try {
        await appWindow.unminimize();
        await appWindow.show();
        await appWindow.setFocus();
      } catch (e) {
        console.error('Failed to restore window on disconnect:', e);
      }
    }
  }
});

// Listen to Bluetooth adapter status events from Rust
const btStatus = document.getElementById('bt-status');
listen('bluetooth-status', (event) => {
  const data = event.payload || {};
  if (!btStatus) return;
  if (data.error) {
    btStatus.textContent = 'Bluetooth tidak tersedia di perangkat ini';
  } else if (data.connected) {
    btStatus.textContent = 'Terhubung via Bluetooth';
  } else {
    btStatus.textContent = 'Bluetooth siap — sambungkan dari HP';
  }
});

// Listen to server errors
listen('server-error', (event) => {
  showServerError(event.payload);
});

initHostInfo();
