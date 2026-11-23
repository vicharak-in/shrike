#ifndef WEB_DASHBOARD_H
#define WEB_DASHBOARD_H

#include <Arduino.h>

const char INDEX_HTML[] PROGMEM = R"rawliteral(
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Shrike-TraceRunner | Web PID Tuning</title>
<style>
  :root {
    --bg: #0b0f19;
    --card: #151d2f;
    --border: #23304a;
    --accent: #00d2ff;
    --accent-hover: #00b4db;
    --green: #00e676;
    --red: #ff3d71;
    --yellow: #ffaa00;
    --text: #e2e8f0;
    --text-muted: #8a99ad;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
  body { background: var(--bg); color: var(--text); padding: 12px; display: flex; flex-direction: column; align-items: center; min-height: 100vh; }
  .container { width: 100%; max-width: 540px; display: flex; flex-direction: column; gap: 14px; }
  
  /* Header */
  header { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 14px 16px; display: flex; justify-content: space-between; align-items: center; }
  .brand { display: flex; flex-direction: column; }
  .brand h1 { font-size: 1.15rem; font-weight: 700; color: #fff; letter-spacing: 0.5px; }
  .brand span { font-size: 0.75rem; color: var(--accent); font-weight: 500; }
  .badge { padding: 4px 10px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; }
  .badge-armed { background: rgba(0, 230, 118, 0.15); color: var(--green); border: 1px solid var(--green); }
  .badge-disarmed { background: rgba(255, 61, 113, 0.15); color: var(--red); border: 1px solid var(--red); }
  
  /* Cards */
  .card { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 14px 16px; }
  .card-title { font-size: 0.82rem; font-weight: 600; text-transform: uppercase; color: var(--text-muted); letter-spacing: 0.8px; margin-bottom: 12px; display: flex; justify-content: space-between; align-items: center; }
  
  /* Sensors Display */
  .sensor-bar { display: grid; grid-template-columns: repeat(8, 1fr); gap: 6px; margin-bottom: 10px; }
  .sensor-cell { display: flex; flex-direction: column; align-items: center; gap: 4px; }
  .sensor-box { width: 100%; height: 26px; border-radius: 6px; background: #1c273c; border: 1px solid #2d3e5e; transition: all 0.1s ease; }
  .sensor-box.active { background: var(--accent); border-color: #80e5ff; box-shadow: 0 0 10px rgba(0, 210, 255, 0.6); }
  .sensor-label { font-size: 0.68rem; color: var(--text-muted); font-family: monospace; }
  
  /* Error Meter */
  .error-meter { height: 10px; background: #1c273c; border-radius: 5px; position: relative; margin: 10px 0; overflow: hidden; border: 1px solid #2d3e5e; }
  .error-center { position: absolute; left: 50%; top: 0; width: 2px; height: 100%; background: #4a5d7e; transform: translateX(-50%); }
  .error-indicator { position: absolute; top: 0; width: 14px; height: 100%; background: var(--green); border-radius: 3px; transform: translateX(-50%); transition: left 0.08s linear; }
  .telemetry-row { display: flex; justify-content: space-between; font-size: 0.85rem; font-family: monospace; color: var(--text); }
  
  /* Actuator Gauges */
  .gauge-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 6px; }
  .gauge-box { background: #0e1422; border: 1px solid var(--border); border-radius: 8px; padding: 10px; text-align: center; }
  .gauge-label { font-size: 0.72rem; color: var(--text-muted); text-transform: uppercase; margin-bottom: 4px; }
  .gauge-val { font-size: 1.25rem; font-weight: 700; color: #fff; font-family: monospace; }
  .gauge-sub { font-size: 0.7rem; color: var(--accent); margin-top: 2px; }

  /* Sliders */
  .tune-group { display: flex; flex-direction: column; gap: 12px; }
  .slider-row { display: flex; flex-direction: column; gap: 6px; }
  .slider-hdr { display: flex; justify-content: space-between; font-size: 0.85rem; }
  .slider-name { font-weight: 600; color: var(--text); }
  .slider-val { font-family: monospace; font-weight: 700; color: var(--accent); }
  input[type=range] { width: 100%; height: 8px; border-radius: 4px; background: #1c273c; outline: none; -webkit-appearance: none; }
  input[type=range]::-webkit-slider-thumb { -webkit-appearance: none; width: 22px; height: 22px; border-radius: 50%; background: var(--accent); cursor: pointer; box-shadow: 0 0 6px rgba(0, 210, 255, 0.5); }

  /* Buttons */
  .btn-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .btn { border: none; border-radius: 8px; padding: 12px; font-size: 0.85rem; font-weight: 700; cursor: pointer; transition: all 0.15s ease; text-transform: uppercase; letter-spacing: 0.5px; }
  .btn-arm { background: var(--green); color: #000; }
  .btn-arm:hover { filter: brightness(1.1); }
  .btn-disarm { background: var(--yellow); color: #000; }
  .btn-stop { background: var(--red); color: #fff; grid-column: span 2; font-size: 0.95rem; padding: 14px; }
  .btn-reset { background: #23304a; color: var(--text); }
  
  /* Presets */
  .preset-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; margin-top: 8px; }
  .btn-preset { background: #1a2337; border: 1px solid var(--border); color: var(--text); padding: 8px; font-size: 0.72rem; border-radius: 6px; font-weight: 600; cursor: pointer; text-align: center; }
  .btn-preset:hover { border-color: var(--accent); color: var(--accent); }
  
  /* Footer */
  footer { text-align: center; font-size: 0.7rem; color: var(--text-muted); margin-top: 6px; }
</style>
</head>
<body>
<div class="container">
  <!-- Header -->
  <header>
    <div class="brand">
      <h1>Shrike-TraceRunner</h1>
      <span>FPGA-Primary Live PID Tuning</span>
    </div>
    <div id="arm-badge" class="badge badge-disarmed">DISARMED</div>
  </header>

  <!-- Live Telemetry Card -->
  <div class="card">
    <div class="card-title">
      <span>8-Channel IR Sensors</span>
      <span id="wd-status" style="color: var(--green)">WD: OK</span>
    </div>
    <div class="sensor-bar">
      <div class="sensor-cell"><div id="s7" class="sensor-box"></div><span class="sensor-label">S7</span></div>
      <div class="sensor-cell"><div id="s6" class="sensor-box"></div><span class="sensor-label">S6</span></div>
      <div class="sensor-cell"><div id="s5" class="sensor-box"></div><span class="sensor-label">S5</span></div>
      <div class="sensor-cell"><div id="s4" class="sensor-box"></div><span class="sensor-label">S4</span></div>
      <div class="sensor-cell"><div id="s3" class="sensor-box"></div><span class="sensor-label">S3</span></div>
      <div class="sensor-cell"><div id="s2" class="sensor-box"></div><span class="sensor-label">S2</span></div>
      <div class="sensor-cell"><div id="s1" class="sensor-box"></div><span class="sensor-label">S1</span></div>
      <div class="sensor-cell"><div id="s0" class="sensor-box"></div><span class="sensor-label">S0</span></div>
    </div>
    
    <div class="error-meter">
      <div class="error-center"></div>
      <div id="err-indicator" class="error-indicator" style="left: 50%;"></div>
    </div>
    
    <div class="telemetry-row">
      <span>Line Error: <b id="err-val" style="color: var(--accent)">0</b></span>
      <span id="track-status" style="color: var(--text-muted)">CENTERED</span>
    </div>

    <!-- Actuators -->
    <div class="gauge-grid">
      <div class="gauge-box">
        <div class="gauge-label">Left Servo (PMOD J5-5)</div>
        <div id="pwml-val" class="gauge-val">1500 &mu;s</div>
        <div id="pwml-sub" class="gauge-sub">Neutral (Stop)</div>
      </div>
      <div class="gauge-box">
        <div class="gauge-label">Right Servo (PMOD J5-6)</div>
        <div id="pwmr-val" class="gauge-val">1500 &mu;s</div>
        <div id="pwmr-sub" class="gauge-sub">Neutral (Stop)</div>
      </div>
    </div>
  </div>

  <!-- Live PID Tuning Card -->
  <div class="card">
    <div class="card-title">
      <span>FPGA PID & Drive Parameters</span>
      <span style="font-size: 0.7rem; color: var(--accent);">50 MHz Real-Time Core</span>
    </div>
    <div class="tune-group">
      <div class="slider-row">
        <div class="slider-hdr">
          <span class="slider-name">Base Speed (PWM Target)</span>
          <span id="speed-disp" class="slider-val">80</span>
        </div>
        <input type="range" id="speed-slider" min="0" max="180" value="80" oninput="updateParam('speed', this.value)">
      </div>

      <div class="slider-row">
        <div class="slider-hdr">
          <span class="slider-name">Kp (Proportional Gain)</span>
          <span id="kp-disp" class="slider-val">4</span>
        </div>
        <input type="range" id="kp-slider" min="0" max="15" value="4" oninput="updateParam('kp', this.value)">
      </div>

      <div class="slider-row">
        <div class="slider-hdr">
          <span class="slider-name">Ki (Integral Gain / Anti-Windup)</span>
          <span id="ki-disp" class="slider-val">0</span>
        </div>
        <input type="range" id="ki-slider" min="0" max="7" value="0" oninput="updateParam('ki', this.value)">
      </div>

      <div class="slider-row">
        <div class="slider-hdr">
          <span class="slider-name">Kd (Derivative Damping)</span>
          <span id="kd-disp" class="slider-val">2</span>
        </div>
        <input type="range" id="kd-slider" min="0" max="15" value="2" oninput="updateParam('kd', this.value)">
      </div>
    </div>

    <!-- Presets -->
    <div style="margin-top: 14px;">
      <span style="font-size: 0.72rem; text-transform: uppercase; color: var(--text-muted); font-weight: 600;">Quick Track Presets:</span>
      <div class="preset-row">
        <button class="btn-preset" onclick="applyPreset(60, 3, 0, 1)">Conservative<br><small>Kp=3 Kd=1</small></button>
        <button class="btn-preset" onclick="applyPreset(85, 4, 0, 2)">Balanced<br><small>Kp=4 Kd=2</small></button>
        <button class="btn-preset" onclick="applyPreset(115, 6, 0, 4)">Fast Slalom<br><small>Kp=6 Kd=4</small></button>
      </div>
    </div>
  </div>

  <!-- Safety & Control Actions -->
  <div class="card">
    <div class="card-title">Motor Arming & Safety Actions</div>
    <div class="btn-grid">
      <button class="btn btn-arm" onclick="sendAction('arm')">&#9654; Arm Motors</button>
      <button class="btn btn-disarm" onclick="sendAction('disarm')">&#9208; Disarm (0V)</button>
      <button class="btn btn-stop" onclick="sendAction('stop')">&#9888; EMERGENCY STOP</button>
      <button class="btn btn-reset" onclick="sendAction('reset')">Reset FPGA PID</button>
      <button class="btn btn-reset" onclick="sendAction('polarity')">Toggle Invert</button>
    </div>
  </div>

  <footer>
    Vicharak Shrike-Fi &bull; ForgeFPGA SLG47910 + ESP32-S3 &bull; Web AP: 192.168.4.1
  </footer>
</div>

<script>
let tuneTimeout = null;

function updateParam(name, val) {
  document.getElementById(name + '-disp').innerText = val;
  clearTimeout(tuneTimeout);
  tuneTimeout = setTimeout(() => {
    fetch(`/api/tune?${name}=${val}`, { method: 'POST' }).catch(e => console.error(e));
  }, 100);
}

function applyPreset(speed, kp, ki, kd) {
  document.getElementById('speed-slider').value = speed;
  document.getElementById('speed-disp').innerText = speed;
  document.getElementById('kp-slider').value = kp;
  document.getElementById('kp-disp').innerText = kp;
  document.getElementById('ki-slider').value = ki;
  document.getElementById('ki-disp').innerText = ki;
  document.getElementById('kd-slider').value = kd;
  document.getElementById('kd-disp').innerText = kd;
  
  fetch(`/api/tune?speed=${speed}&kp=${kp}&ki=${ki}&kd=${kd}`, { method: 'POST' })
    .catch(e => console.error(e));
}

function sendAction(action) {
  fetch(`/api/action?cmd=${action}`, { method: 'POST' }).catch(e => console.error(e));
}

function pollTelemetry() {
  fetch('/api/telemetry')
    .then(r => r.json())
    .then(data => {
      // 1. Arm badge
      const badge = document.getElementById('arm-badge');
      if (data.armed) {
        badge.className = 'badge badge-armed';
        badge.innerText = 'ARMED';
      } else {
        badge.className = 'badge badge-disarmed';
        badge.innerText = 'DISARMED';
      }

      // 2. Watchdog status
      const wd = document.getElementById('wd-status');
      if (data.watchdog_ok) {
        wd.innerText = 'WD: OK';
        wd.style.color = 'var(--green)';
      } else {
        wd.innerText = 'WD: FAIL';
        wd.style.color = 'var(--red)';
      }

      // 3. Sensor bits (8 channels)
      const raw = data.sensors || 0;
      for (let i = 0; i < 8; i++) {
        const el = document.getElementById('s' + i);
        if ((raw & (1 << i)) !== 0) {
          el.classList.add('active');
        } else {
          el.classList.remove('active');
        }
      }

      // 4. Line Error & Meter
      const err = data.error || 0;
      document.getElementById('err-val').innerText = (err > 0 ? '+' : '') + err;
      
      // Map error from [-7, +7] to [10%, 90%]
      const pct = 50 + (err / 7.0) * 40;
      document.getElementById('err-indicator').style.left = Math.min(Math.max(pct, 5), 95) + '%';
      
      const track = document.getElementById('track-status');
      if (data.line_lost) {
        track.innerText = 'LINE LOST (PIVOT)';
        track.style.color = 'var(--yellow)';
      } else if (err === 0) {
        track.innerText = 'CENTERED';
        track.style.color = 'var(--green)';
      } else {
        track.innerText = (err > 0 ? 'RIGHT ' : 'LEFT ') + Math.abs(err);
        track.style.color = 'var(--accent)';
      }

      // 5. Servo Pulse Widths
      const l_pw = data.left_pw || 1500;
      const r_pw = data.right_pw || 1500;
      document.getElementById('pwml-val').innerText = l_pw + ' \u03BCs';
      document.getElementById('pwmr-val').innerText = r_pw + ' \u03BCs';
      
      if (!data.armed) {
        document.getElementById('pwml-sub').innerText = '0V Silence (Disarmed)';
        document.getElementById('pwmr-sub').innerText = '0V Silence (Disarmed)';
      } else {
        const l_pct = Math.round(((l_pw - 1500) / 500.0) * 100);
        const r_pct = Math.round(((1500 - r_pw) / 500.0) * 100);
        document.getElementById('pwml-sub').innerText = (l_pct >= 0 ? '+' : '') + l_pct + '% Fwd';
        document.getElementById('pwmr-sub').innerText = (r_pct >= 0 ? '+' : '') + r_pct + '% Fwd';
      }
    })
    .catch(e => {
      document.getElementById('wd-status').innerText = 'OFFLINE';
      document.getElementById('wd-status').style.color = 'var(--red)';
    });
}

// Poll telemetry every 100ms (10 Hz)
setInterval(pollTelemetry, 100);
pollTelemetry();
</script>
</body>
</html>
)rawliteral";

#endif // WEB_DASHBOARD_H
