// Stopwatch History Analytics Logic
let stopwatchHistory = [];
let activeTheme = 'dark';

// DOM Elements
const chartContainer = document.getElementById('chart-container');
const logsList = document.getElementById('logs-list');
const tooltip = document.getElementById('chart-tooltip');
const tooltipName = document.getElementById('tooltip-name');
const tooltipTime = document.getElementById('tooltip-time');
const tooltipDate = document.getElementById('tooltip-date');

// Wait for DOM
window.addEventListener('DOMContentLoaded', () => {
  // Bind close window button
  document.getElementById('btn-close-window').addEventListener('click', () => {
    sendCloseMessage();
  });

  // Bind clear all button
  document.getElementById('btn-clear-all').addEventListener('click', () => {
    clearAllHistory();
  });

  // Notify Python that the history page is ready to receive data
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.history_ready) {
    window.webkit.messageHandlers.history_ready.postMessage(null);
  } else {
    // Dev fallback with mock data
    console.log("WebKit environment not detected. Loading development mock data.");
    loadMockData();
  }
});

// Mock data for browser testing
function loadMockData() {
  activeTheme = 'neon';
  document.body.className = 'theme-neon';
  stopwatchHistory = [
    { name: "UI Design Workflow", time: "00:45:12", date: "Jun 11, 14:30" },
    { name: "Debugging WebKit compositing", time: "01:15:00", date: "Jun 11, 16:15" },
    { name: "Coffee Break", time: "00:05:43", date: "Jun 11, 16:22" },
    { name: "Refactoring main.py", time: "00:28:30", date: "Jun 11, 17:05" },
    { name: "Code Review session", time: "00:52:10", date: "Jun 11, 18:40" },
    { name: "Testing layout symmetry", time: "00:12:15", date: "Jun 11, 19:10" }
  ];
  renderDashboard();
}

// IPC calls from Python
window.setTheme = function(themeName) {
  activeTheme = themeName || 'dark';
  document.body.className = '';
  if (activeTheme !== 'dark') {
    document.body.classList.add(`theme-${activeTheme}`);
  }
  renderDashboard();
};

window.setStopwatchHistory = function(historyArray) {
  stopwatchHistory = historyArray || [];
  renderDashboard();
};

// Send actions back to Python
function syncHistoryToPython() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_history) {
    window.webkit.messageHandlers.update_history.postMessage(JSON.stringify(stopwatchHistory));
  }
}

function sendCloseMessage() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.window_control) {
    window.webkit.messageHandlers.window_control.postMessage(JSON.stringify({ action: "close" }));
  }
}

// Clear all records
function clearAllHistory() {
  if (stopwatchHistory.length === 0) return;
  if (confirm("Are you sure you want to clear all stopwatch history records?")) {
    stopwatchHistory = [];
    syncHistoryToPython();
    renderDashboard();
  }
}

// Delete single log entry
function deleteItem(index) {
  if (index >= 0 && index < stopwatchHistory.length) {
    stopwatchHistory.splice(index, 1);
    syncHistoryToPython();
    renderDashboard();
  }
}

// Helper: duration HH:MM:SS -> seconds
function durationToSeconds(durationStr) {
  if (!durationStr) return 0;
  const parts = durationStr.split(':').map(Number);
  if (parts.length === 3) {
    return parts[0] * 3600 + parts[1] * 60 + parts[2];
  } else if (parts.length === 2) {
    return parts[0] * 60 + parts[1];
  } else if (parts.length === 1) {
    return parts[0];
  }
  return 0;
}

// Helper: seconds -> HH:MM:SS or MM:SS
function formatSeconds(totalSecs) {
  const h = Math.floor(totalSecs / 3600);
  const m = Math.floor((totalSecs % 3600) / 60);
  const s = totalSecs % 60;
  if (h > 0) {
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

// Helper: Get nice scale step
function getNiceTickStep(maxVal) {
  const rawStep = maxVal / 4;
  if (rawStep <= 1) return 1;
  if (rawStep <= 2) return 2;
  if (rawStep <= 5) return 5;
  if (rawStep <= 10) return 10;
  if (rawStep <= 15) return 15;
  if (rawStep <= 30) return 30;
  if (rawStep <= 60) return 60;      // 1m
  if (rawStep <= 120) return 120;    // 2m
  if (rawStep <= 300) return 300;    // 5m
  if (rawStep <= 600) return 600;    // 10m
  if (rawStep <= 900) return 900;    // 15m
  if (rawStep <= 1800) return 1800;  // 30m
  if (rawStep <= 3600) return 3600;  // 1h
  
  const hours = rawStep / 3600;
  const roundedHours = Math.ceil(hours);
  return roundedHours * 3600;
}

// Helper: HTML escaper
function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Render the entire layout
function renderDashboard() {
  renderLogs();
  renderChart();
}

// Render right side logs list
function renderLogs() {
  if (!logsList) return;

  if (stopwatchHistory.length === 0) {
    logsList.innerHTML = `
      <div class="empty-state">
        <svg class="empty-state-icon" viewBox="0 0 24 24" width="48" height="48">
          <path fill="currentColor" d="M19,3H5C3.89,3 3,3.9 3,5V19A2,2 0 0,0 5,21H19A2,2 0 0,0 21,19V7L17,3M12,19A3,3 0 0,1 9,16A3,3 0 0,1 12,13A3,3 0 0,1 15,16A3,3 0 0,1 12,19M15,9H5V5H15V9Z"/>
        </svg>
        <div class="empty-state-title">No Recorded Sessions</div>
        <div class="empty-state-desc">Record stopwatch runs in the main clock widget to view logs here.</div>
      </div>
    `;
    return;
  }

  let html = '';
  stopwatchHistory.forEach((item, index) => {
    html += `
      <div class="log-item">
        <div class="log-details">
          <span class="log-name" title="${escapeHtml(item.name)}">${escapeHtml(item.name)}</span>
          <span class="log-meta">${escapeHtml(item.date)}</span>
        </div>
        <div class="log-right">
          <span class="log-time">${escapeHtml(item.time)}</span>
          <button class="delete-btn" onclick="deleteItem(${index})" title="Delete entry">&times;</button>
        </div>
      </div>
    `;
  });
  logsList.innerHTML = html;
}

// Render left side dynamic SVG bar chart
function renderChart() {
  if (!chartContainer) return;
  chartContainer.innerHTML = '';

  if (stopwatchHistory.length === 0) {
    chartContainer.innerHTML = `
      <div class="empty-state">
        <svg class="empty-state-icon" viewBox="0 0 24 24" width="48" height="48">
          <path fill="currentColor" d="M12,2C6.48,2 2,6.48 2,12C2,17.52 6.48,22 12,22C17.52,22 22,17.52 22,12C22,6.48 17.52,2 12,2M16,13H13V16H11V13H8V11H11V8H13V11H16V13Z"/>
        </svg>
        <div class="empty-state-title">Visualization Pending</div>
        <div class="empty-state-desc">Bar chart will render automatically when session data is available.</div>
      </div>
    `;
    return;
  }

  // Set sizing parameters
  const containerWidth = chartContainer.clientWidth || 420;
  const containerHeight = chartContainer.clientHeight || 320;
  const padding = { top: 25, right: 20, bottom: 45, left: 60 };

  const chartHeight = containerHeight - padding.top - padding.bottom;

  // Determine SVG width (enable horizontal scrolling if too many items)
  const minBarWidthWithGap = 48; // bar width 26px + gap 22px
  const calculatedWidth = padding.left + padding.right + (stopwatchHistory.length * minBarWidthWithGap);
  const svgWidth = Math.max(containerWidth, calculatedWidth);
  const chartWidth = svgWidth - padding.left - padding.right;

  // Create outer scroll wrapper if chart overflows the container width
  if (calculatedWidth > containerWidth) {
    chartContainer.style.justifyContent = 'flex-start';
    chartContainer.className = 'chart-scroll-wrapper';
  } else {
    chartContainer.style.justifyContent = 'center';
    chartContainer.className = '';
  }

  // Calculate scales
  const durations = stopwatchHistory.map(item => durationToSeconds(item.time));
  const maxRecordedSec = Math.max(...durations);
  
  // Clean tick step calculation
  const tickStep = getNiceTickStep(maxRecordedSec);
  const maxScaleVal = tickStep * 4; // 4 intervals

  // SVG NS
  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("width", svgWidth);
  svg.setAttribute("height", containerHeight);

  // Gradient Definition matching HSL themes
  const defs = document.createElementNS(svgNS, "defs");
  
  // Neon Theme Gradient (Cyan to Pink)
  const neonGrad = createLinearGradient(svgNS, "gradient-neon", "#00f0ff", "#ff55a3");
  defs.appendChild(neonGrad);

  // Mint Theme Gradient (Mint green)
  const mintGrad = createLinearGradient(svgNS, "gradient-mint", "#87cf3e", "#5ca120");
  defs.appendChild(mintGrad);

  // Amber Theme Gradient (Amber Nixie orange)
  const amberGrad = createLinearGradient(svgNS, "gradient-amber", "#ff7b00", "#ffb870");
  defs.appendChild(amberGrad);

  // Dark Theme Gradient (Monochromatic white/gray)
  const darkGrad = createLinearGradient(svgNS, "gradient-dark", "#ffffff", "#888888");
  defs.appendChild(darkGrad);

  svg.appendChild(defs);

  // 1. Draw horizontal gridlines and Y-axis scale markings
  for (let i = 0; i <= 4; i++) {
    const value = tickStep * i;
    const yVal = padding.top + chartHeight - (value / maxScaleVal) * chartHeight;

    // Gridline
    const gridLine = document.createElementNS(svgNS, "line");
    gridLine.setAttribute("x1", padding.left);
    gridLine.setAttribute("y1", yVal);
    gridLine.setAttribute("x2", svgWidth - padding.right);
    gridLine.setAttribute("y2", yVal);
    gridLine.setAttribute("class", "chart-grid-line");
    svg.appendChild(gridLine);

    // Y Axis labels
    const textLabel = document.createElementNS(svgNS, "text");
    textLabel.setAttribute("x", padding.left - 10);
    textLabel.setAttribute("y", yVal + 4);
    textLabel.setAttribute("class", "chart-text axis-label");
    textLabel.setAttribute("text-anchor", "end");
    textLabel.textContent = formatSeconds(value);
    svg.appendChild(textLabel);
  }

  // 2. Draw Axis lines
  // Y Axis line
  const yAxis = document.createElementNS(svgNS, "line");
  yAxis.setAttribute("x1", padding.left);
  yAxis.setAttribute("y1", padding.top);
  yAxis.setAttribute("x2", padding.left);
  yAxis.setAttribute("y2", padding.top + chartHeight);
  yAxis.setAttribute("class", "chart-axis");
  svg.appendChild(yAxis);

  // X Axis line
  const xAxis = document.createElementNS(svgNS, "line");
  xAxis.setAttribute("x1", padding.left);
  xAxis.setAttribute("y1", padding.top + chartHeight);
  xAxis.setAttribute("x2", svgWidth - padding.right);
  xAxis.setAttribute("y2", padding.top + chartHeight);
  xAxis.setAttribute("class", "chart-axis");
  svg.appendChild(xAxis);

  // 3. Render Bars and Labels
  const barWidth = 24;
  const barSpace = chartWidth / stopwatchHistory.length;
  
  stopwatchHistory.forEach((item, index) => {
    const sec = durationToSeconds(item.time);
    const barHeight = maxScaleVal > 0 ? (sec / maxScaleVal) * chartHeight : 0;
    
    // Position calculations
    // Center the bars in their allotted space slice
    const x = padding.left + (index * barSpace) + (barSpace - barWidth) / 2;
    const y = padding.top + chartHeight - barHeight;

    // Rect Bar
    const rect = document.createElementNS(svgNS, "rect");
    rect.setAttribute("x", x);
    rect.setAttribute("y", y);
    rect.setAttribute("width", barWidth);
    rect.setAttribute("height", Math.max(2, barHeight)); // Ensure tiny values still draw a line
    rect.setAttribute("rx", 3);
    rect.setAttribute("ry", 3);
    rect.setAttribute("class", "chart-bar");
    rect.setAttribute("fill", `url(#gradient-${activeTheme})`);

    // Attach tooltips
    rect.addEventListener('mouseover', (e) => {
      showTooltip(e, item);
    });
    rect.addEventListener('mousemove', (e) => {
      positionTooltip(e);
    });
    rect.addEventListener('mouseout', () => {
      hideTooltip();
    });

    svg.appendChild(rect);

    // Label under the bar (X-axis labels)
    const label = document.createElementNS(svgNS, "text");
    label.setAttribute("x", x + barWidth / 2);
    label.setAttribute("y", padding.top + chartHeight + 16);
    label.setAttribute("class", "chart-text bar-label");
    label.textContent = truncateString(item.name, 9);
    svg.appendChild(label);
  });

  chartContainer.appendChild(svg);
}

// Helper: Linear Gradient Generator
function createLinearGradient(svgNS, id, colorStart, colorEnd) {
  const grad = document.createElementNS(svgNS, "linearGradient");
  grad.setAttribute("id", id);
  grad.setAttribute("x1", "0%");
  grad.setAttribute("y1", "0%");
  grad.setAttribute("x2", "0%");
  grad.setAttribute("y2", "100%");

  const stop1 = document.createElementNS(svgNS, "stop");
  stop1.setAttribute("offset", "0%");
  stop1.setAttribute("stop-color", colorStart);
  stop1.setAttribute("stop-opacity", "1");

  const stop2 = document.createElementNS(svgNS, "stop");
  stop2.setAttribute("offset", "100%");
  stop2.setAttribute("stop-color", colorEnd);
  stop2.setAttribute("stop-opacity", "0.25"); // Fades to semi-translucent for glassmorphic style

  grad.appendChild(stop1);
  grad.appendChild(stop2);
  return grad;
}

// Helper: Truncator
function truncateString(str, length) {
  if (!str) return '';
  return str.length > length ? str.slice(0, length) + '..' : str;
}

// Tooltip Handlers
function showTooltip(event, item) {
  tooltipName.textContent = item.name;
  tooltipTime.textContent = `Duration: ${item.time}`;
  tooltipDate.textContent = `Recorded: ${item.date}`;
  tooltip.style.opacity = '1';
  tooltip.style.transform = 'scale(1)';
  positionTooltip(event);
}

function positionTooltip(event) {
  // We offset the tooltip relative to mouse position
  // Get viewport bounds of container to avoid spilling out
  const bounds = chartContainer.getBoundingClientRect();
  const mouseX = event.clientX;
  const mouseY = event.clientY;

  // Tooltip dimensions estimation
  const tooltipWidth = tooltip.offsetWidth || 140;
  const tooltipHeight = tooltip.offsetHeight || 60;

  let x = mouseX + 12;
  let y = mouseY - tooltipHeight - 12;

  // Horizontal bounds safety
  if (x + tooltipWidth > window.innerWidth - 16) {
    x = mouseX - tooltipWidth - 12;
  }
  // Vertical bounds safety
  if (y < 16) {
    y = mouseY + 16;
  }

  tooltip.style.left = `${x}px`;
  tooltip.style.top = `${y}px`;
}

function hideTooltip() {
  tooltip.style.opacity = '0';
  tooltip.style.transform = 'scale(0.95)';
}
