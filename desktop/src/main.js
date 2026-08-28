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
  appWindow.close();
});

// Tab Switcher
tabWifi.addEventListener('click', () => {
  tabWifi.classList.add('active');
  tabBluetooth.classList.remove('active');
  panelWifi.classList.add('active');
  panelBluetooth.classList.remove('active');
});

tabBluetooth.addEventListener('click', () => {
  tabBluetooth.classList.add('active');
  tabWifi.classList.remove('active');
  panelBluetooth.classList.add('active');
  panelWifi.classList.remove('active');
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
themeToggle.addEventListener('click', () => {
  isDark = !isDark;
  document.documentElement.setAttribute('data-theme', isDark ? 'dark' : 'light');
});

// Initialize Host Info & Render QR Code
async function initHostInfo() {
  try {
    const info = await invoke('get_connection_info');
    if (info.hostname && btHostName) {
      btHostName.textContent = info.hostname;
    }

    // Generate Standard Clean QR Code
    const payload = JSON.stringify({
      ip: info.ip,
      port: info.port,
      ws: info.ws_url,
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

initHostInfo();
