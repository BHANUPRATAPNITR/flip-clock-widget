/**
 * Stopwatch History Analytics - Client Logic
 * 
 * This script runs inside the secondary GTK WebKit webview (web/history.html).
 * It is responsible for:
 *   1. Receiving stopwatch history logs and themes from the Python backend via IPC.
 *   2. Dynamically rendering an SVG-based bar chart of session durations.
 *   3. Rendering a scrollable side-panel of recorded sessions with single-deletion controls.
 *   4. Syncing deleted entries or clear-all commands back to Python in real-time.
 *   5. Displaying interactive glassmorphic tooltips when hovering over chart bars.
 */

// Core state variables
let stopwatchHistory = []; // Local cache of stopwatch runs (format: { name, time, date })
let activeTheme = 'dark';    // Current theme matching parent clock ('dark' | 'mint' | 'neon' | 'amber')

// DOM Elements
const chartContainer = document.getElementById('chart-container');
const logsList = document.getElementById('logs-list');
const tooltip = document.getElementById('chart-tooltip');
const tooltipName = document.getElementById('tooltip-name');
const tooltipTime = document.getElementById('tooltip-time');
const tooltipDate = document.getElementById('tooltip-date');

/**
 * Initialization Event Listener
 * Sets up basic window action bindings and flags the backend that the UI is fully loaded.
 */
window.addEventListener('DOMContentLoaded', () => {
  // Bind close button to signal the Python wrapper to close the secondary Gtk.Window
  document.getElementById('btn-close-window').addEventListener('click', () => {
    sendCloseMessage();
  });

  // Bind clear all button to clean the local cache, sync to Python, and re-render
  document.getElementById('btn-clear-all').addEventListener('click', () => {
    clearAllHistory();
  });

  // Signal the Python backend that the script context is loaded and ready.
  // Python will reply by injecting current configurations via window.setTheme and window.setStopwatchHistory.
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.history_ready) {
    console.log("[DEBUG] Posting history_ready message to WebKit bridge.");
    window.webkit.messageHandlers.history_ready.postMessage(null);
  } else {
    // Development/Fallback environment (e.g., standard browser view)
    console.log("[DEBUG] WebKit bridge not detected. Loading development mock data.");
    loadMockData();
  }
});

/**
 * loadMockData
 * Populates local variables with sample sessions to facilitate quick debugging in local web browsers.
 */
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

// ==========================================
// IPC BRIDGING (COMMUNICATION WITH PYTHON)
// ==========================================

/**
 * window.setTheme
 * Called dynamically from Python's main.py to sync the active theme setting.
 * @param {string} themeName - Theme name ('dark' | 'mint' | 'neon' | 'amber')
 */
window.setTheme = function(themeName) {
  console.log(`[DEBUG] Received theme update from Python: ${themeName}`);
  activeTheme = themeName || 'dark';
  document.body.className = ''; // Reset body classes
  if (activeTheme !== 'dark') {
    document.body.classList.add(`theme-${activeTheme}`);
  }
  // Re-render dashboard because gradients on SVG bars must match the new theme accent colors
  renderDashboard();
};

/**
 * window.setStopwatchHistory
 * Called dynamically from Python's main.py when config loads or stopwatch sessions update.
 * @param {Array} historyArray - Serialized JSON array of stopwatch sessions
 */
window.setStopwatchHistory = function(historyArray) {
  console.log(`[DEBUG] Received history update from Python. Length: ${historyArray ? historyArray.length : 0}`);
  stopwatchHistory = historyArray || [];
  renderDashboard();
};

/**
 * syncHistoryToPython
 * Posts the stringified history log back to Python context to be stored in config.json.
 */
function syncHistoryToPython() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_history) {
    console.log("[DEBUG] Syncing updated history back to Python backend.");
    window.webkit.messageHandlers.update_history.postMessage(JSON.stringify(stopwatchHistory));
  }
}

/**
 * sendCloseMessage
 * Signals Python's window_control message handler to close/destroy the history window container.
 */
function sendCloseMessage() {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.window_control) {
    console.log("[DEBUG] Signaling Python to close the history window.");
    window.webkit.messageHandlers.window_control.postMessage(JSON.stringify({ action: "close" }));
  }
}

// ==========================================
// LOG ENTRIES OPERATIONS
// ==========================================

/**
 * clearAllHistory
 * Empties the history log, triggers synchronization back to the filesystem, and refreshes the viewport.
 */
function clearAllHistory() {
  if (stopwatchHistory.length === 0) return;
  if (confirm("Are you sure you want to clear all stopwatch history records?")) {
    console.log("[ACTION] Clearing all history logs.");
    stopwatchHistory = [];
    syncHistoryToPython();
    renderDashboard();
  }
}

/**
 * deleteItem
 * Deletes a single entry from the logs array, syncs state to python, and triggers a visual redraw.
 * @param {number} index - Index of the item in the local stopwatchHistory array
 */
function deleteItem(index) {
  if (index >= 0 && index < stopwatchHistory.length) {
    console.log(`[ACTION] Deleting history log at index: ${index}`);
    stopwatchHistory.splice(index, 1);
    syncHistoryToPython();
    renderDashboard();
  }
}

// ==========================================
// MATHS & TIME CONVERSION UTILITIES
// ==========================================

/**
 * durationToSeconds
 * Parses a standard stopwatch duration string to raw seconds.
 * Supports format: "HH:MM:SS" (e.g. "01:15:30" -> 4530)
 * @param {string} durationStr - Formatted time string
 * @returns {number} Time in seconds
 */
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

/**
 * formatSeconds
 * Converts raw seconds back to formatted string.
 * Formats: "HH:MM:SS" if hours > 0, otherwise "MM:SS". Used for chart labels.
 * @param {number} totalSecs - Time in seconds
 * @returns {string} Formatted output string
 */
function formatSeconds(totalSecs) {
  const h = Math.floor(totalSecs / 3600);
  const m = Math.floor((totalSecs % 3600) / 60);
  const s = totalSecs % 60;
  if (h > 0) {
    return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  }
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

/**
 * getNiceTickStep
 * Calculates a clean step division for the Y-axis based on the maximum recorded duration.
 * This prevents arbitrary/messy floating scale numbers (e.g. splits scale at 15s, 5m, 1h increments).
 * @param {number} maxVal - Max duration in seconds
 * @returns {number} Step size in seconds
 */
function getNiceTickStep(maxVal) {
  const rawStep = maxVal / 4; // Split the Y-axis height into 4 segments (resulting in 5 grid markings)
  if (rawStep <= 1) return 1;
  if (rawStep <= 2) return 2;
  if (rawStep <= 5) return 5;
  if (rawStep <= 10) return 10;
  if (rawStep <= 15) return 15;
  if (rawStep <= 30) return 30;
  if (rawStep <= 60) return 60;      // 1 minute
  if (rawStep <= 120) return 120;    // 2 minutes
  if (rawStep <= 300) return 300;    // 5 minutes
  if (rawStep <= 600) return 600;    // 10 minutes
  if (rawStep <= 900) return 900;    // 15 minutes
  if (rawStep <= 1800) return 1800;  // 30 minutes
  if (rawStep <= 3600) return 3600;  // 1 hour
  
  // For durations > 1 hour, round up to full hours
  const hours = rawStep / 3600;
  const roundedHours = Math.ceil(hours);
  return roundedHours * 3600;
}

/**
 * escapeHtml
 * Sanitizes input string to prevent potential XSS injection vectors through session labels.
 * @param {string} str - Raw string
 * @returns {string} Escaped HTML string
 */
function escapeHtml(str) {
  if (!str) return '';
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// ==========================================
// RENDER ACTIONS (DOM MANIPULATION)
// ==========================================

/**
 * renderDashboard
 * Helper to update both visual sections of the analytics viewport in a single invocation.
 */
function renderDashboard() {
  renderLogs();
  renderChart();
}

/**
 * renderLogs
 * Builds the right-hand scrollable side-panel showing individual log rows.
 */
function renderLogs() {
  if (!logsList) return;

  // Render an empty-state message if there are no logs saved
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

  // Iterate chronologically through logs and compile HTML templates
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

/**
 * renderChart
 * Generates and draws the dynamic SVG bar chart in the left panel.
 * Performs math to scale Y-axis values and handles overflow horizontal scroll limits.
 */
function renderChart() {
  if (!chartContainer) return;
  chartContainer.innerHTML = ''; // Reset container content

  // Draw empty state message if no data exists
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

  // Sizing metrics
  const containerWidth = chartContainer.clientWidth || 420;
  const containerHeight = chartContainer.clientHeight || 320;
  
  // Padding zones inside the SVG to allocate space for axes labels
  const padding = { top: 25, right: 20, bottom: 45, left: 60 };
  const chartHeight = containerHeight - padding.top - padding.bottom;

  // Math check: determine width requirements.
  // We specify a minimum bar width + spacing gap (48px) to guarantee readability.
  // If the total width exceeds the container clientWidth, we set a larger width to enable scrollbars.
  const minBarWidthWithGap = 48; 
  const calculatedWidth = padding.left + padding.right + (stopwatchHistory.length * minBarWidthWithGap);
  const svgWidth = Math.max(containerWidth, calculatedWidth);
  const chartWidth = svgWidth - padding.left - padding.right;

  // Toggle layout structure depending on whether scrolling is triggered
  if (calculatedWidth > containerWidth) {
    chartContainer.style.justifyContent = 'flex-start';
    chartContainer.className = 'chart-scroll-wrapper'; // Horizontal overflow auto
  } else {
    chartContainer.style.justifyContent = 'center';
    chartContainer.className = '';
  }

  // Calculate scaling factors for the chart
  const durations = stopwatchHistory.map(item => durationToSeconds(item.time));
  const maxRecordedSec = Math.max(...durations);
  
  // Get neat division interval size
  const tickStep = getNiceTickStep(maxRecordedSec);
  const maxScaleVal = tickStep * 4; // 4 intervals on scale height

  // Create SVG element programmatically under the SVG Namespace
  const svgNS = "http://www.w3.org/2000/svg";
  const svg = document.createElementNS(svgNS, "svg");
  svg.setAttribute("width", svgWidth);
  svg.setAttribute("height", containerHeight);

  // SVG Definitions block to house dynamic linear gradients
  const defs = document.createElementNS(svgNS, "defs");
  
  // 1. Neon Theme Gradient definition (Cyan to Hot Pink)
  const neonGrad = createLinearGradient(svgNS, "gradient-neon", "#00f0ff", "#ff55a3");
  defs.appendChild(neonGrad);

  // 2. Mint Theme Gradient definition (Linux Mint bright green to dark green)
  const mintGrad = createLinearGradient(svgNS, "gradient-mint", "#87cf3e", "#5ca120");
  defs.appendChild(mintGrad);

  // 3. Amber Theme Gradient definition (Nixie tube orange to light orange)
  const amberGrad = createLinearGradient(svgNS, "gradient-amber", "#ff7b00", "#ffb870");
  defs.appendChild(amberGrad);

  // 4. Dark Theme Gradient definition (Monochromatic matte white to gray)
  const darkGrad = createLinearGradient(svgNS, "gradient-dark", "#ffffff", "#888888");
  defs.appendChild(darkGrad);

  svg.appendChild(defs);

  // ----------------------------------------------------
  // DRAW AXIS MARKS, TICK LABELS, AND HORIZONTAL LINES
  // ----------------------------------------------------
  for (let i = 0; i <= 4; i++) {
    const value = tickStep * i;
    // Map value to coordinate y. Coordinate system has (0,0) in top-left corner
    const yVal = padding.top + chartHeight - (value / maxScaleVal) * chartHeight;

    // Draw horizontal grid line
    const gridLine = document.createElementNS(svgNS, "line");
    gridLine.setAttribute("x1", padding.left);
    gridLine.setAttribute("y1", yVal);
    gridLine.setAttribute("x2", svgWidth - padding.right);
    gridLine.setAttribute("y2", yVal);
    gridLine.setAttribute("class", "chart-grid-line"); // Styling handled by styles inside history.html
    svg.appendChild(gridLine);

    // Draw scale tick text label
    const textLabel = document.createElementNS(svgNS, "text");
    textLabel.setAttribute("x", padding.left - 10);
    textLabel.setAttribute("y", yVal + 4);
    textLabel.setAttribute("class", "chart-text axis-label");
    textLabel.setAttribute("text-anchor", "end");
    textLabel.textContent = formatSeconds(value);
    svg.appendChild(textLabel);
  }

  // ----------------------------------------------------
  // DRAW MAIN COORDINATE AXES
  // ----------------------------------------------------
  // Vertical Y-Axis line
  const yAxis = document.createElementNS(svgNS, "line");
  yAxis.setAttribute("x1", padding.left);
  yAxis.setAttribute("y1", padding.top);
  yAxis.setAttribute("x2", padding.left);
  yAxis.setAttribute("y2", padding.top + chartHeight);
  yAxis.setAttribute("class", "chart-axis");
  svg.appendChild(yAxis);

  // Horizontal X-Axis line
  const xAxis = document.createElementNS(svgNS, "line");
  xAxis.setAttribute("x1", padding.left);
  xAxis.setAttribute("y1", padding.top + chartHeight);
  xAxis.setAttribute("x2", svgWidth - padding.right);
  xAxis.setAttribute("y2", padding.top + chartHeight);
  xAxis.setAttribute("class", "chart-axis");
  svg.appendChild(xAxis);

  // ----------------------------------------------------
  // DRAW RECTANGLE BARS AND THEIR LABELS
  // ----------------------------------------------------
  const barWidth = 24; // Fixed bar width
  const barSpace = chartWidth / stopwatchHistory.length; // Spacing interval width per item
  
  stopwatchHistory.forEach((item, index) => {
    const sec = durationToSeconds(item.time);
    // Convert duration to height in pixels
    const barHeight = maxScaleVal > 0 ? (sec / maxScaleVal) * chartHeight : 0;
    
    // Position math: center the bar inside the divided space slot
    const x = padding.left + (index * barSpace) + (barSpace - barWidth) / 2;
    const y = padding.top + chartHeight - barHeight;

    // Create SVG <rect> element representing the bar
    const rect = document.createElementNS(svgNS, "rect");
    rect.setAttribute("x", x);
    rect.setAttribute("y", y);
    rect.setAttribute("width", barWidth);
    // Ensure very short runs still show a 2px horizontal slice to provide hover target feedback
    rect.setAttribute("height", Math.max(2, barHeight)); 
    rect.setAttribute("rx", 3); // Slightly rounded top corners
    rect.setAttribute("ry", 3);
    rect.setAttribute("class", "chart-bar");
    rect.setAttribute("fill", `url(#gradient-${activeTheme})`); // Link gradient fill by id

    // Event listeners to handle glassmorphic tooltips
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

    // Create session label text under the bar (X-axis text label)
    const label = document.createElementNS(svgNS, "text");
    label.setAttribute("x", x + barWidth / 2);
    label.setAttribute("y", padding.top + chartHeight + 16);
    label.setAttribute("class", "chart-text bar-label");
    label.textContent = truncateString(item.name, 9); // Truncated name (hover reveals full text)
    svg.appendChild(label);
  });

  chartContainer.appendChild(svg);
}

/**
 * createLinearGradient
 * Generates an SVG `<linearGradient>` tag programmatically.
 * @param {string} svgNS - SVG Namespace URL
 * @param {string} id - HTML ID attribute
 * @param {string} colorStart - Top start color hex
 * @param {string} colorEnd - Bottom end color hex
 * @returns {SVGElement} Completed linearGradient element
 */
function createLinearGradient(svgNS, id, colorStart, colorEnd) {
  const grad = document.createElementNS(svgNS, "linearGradient");
  grad.setAttribute("id", id);
  grad.setAttribute("x1", "0%");
  grad.setAttribute("y1", "0%");
  grad.setAttribute("x2", "0%");
  grad.setAttribute("y2", "100%");

  // Top anchor color (full opacity)
  const stop1 = document.createElementNS(svgNS, "stop");
  stop1.setAttribute("offset", "0%");
  stop1.setAttribute("stop-color", colorStart);
  stop1.setAttribute("stop-opacity", "1");

  // Bottom anchor color (semi-translucent to align with glassmorphic styles)
  const stop2 = document.createElementNS(svgNS, "stop");
  stop2.setAttribute("offset", "100%");
  stop2.setAttribute("stop-color", colorEnd);
  stop2.setAttribute("stop-opacity", "0.25");

  grad.appendChild(stop1);
  grad.appendChild(stop2);
  return grad;
}

/**
 * truncateString
 * Limits length of text and appends suffix dots.
 * @param {string} str - Target string
 * @param {number} length - Maximum length
 * @returns {string} Truncated string
 */
function truncateString(str, length) {
  if (!str) return '';
  return str.length > length ? str.slice(0, length) + '..' : str;
}

// ==========================================
// TOOLTIP VIEWPORTS MANAGEMENT
// ==========================================

/**
 * showTooltip
 * Fills data and fades in the custom floating card viewport.
 * @param {Event} event - Mouseover event
 * @param {Object} item - History log item containing session meta
 */
function showTooltip(event, item) {
  tooltipName.textContent = item.name;
  tooltipTime.textContent = `Duration: ${item.time}`;
  tooltipDate.textContent = `Recorded: ${item.date}`;
  tooltip.style.opacity = '1';
  tooltip.style.transform = 'scale(1)'; // pop scale effect
  positionTooltip(event);
}

/**
 * positionTooltip
 * Computes coordinates for the tooltip to follow the cursor.
 * Performs collision checking with window edges to prevent clipping.
 * @param {Event} event - Mousemove event
 */
function positionTooltip(event) {
  const mouseX = event.clientX;
  const mouseY = event.clientY;

  // Measure tooltip size dynamically
  const tooltipWidth = tooltip.offsetWidth || 140;
  const tooltipHeight = tooltip.offsetHeight || 60;

  // Offset tooltip slightly up and to the right of the cursor
  let x = mouseX + 12;
  let y = mouseY - tooltipHeight - 12;

  // Horizontal collision prevention: push left if spilling off-screen right
  if (x + tooltipWidth > window.innerWidth - 16) {
    x = mouseX - tooltipWidth - 12;
  }
  // Vertical collision prevention: push down if spilling off-screen top
  if (y < 16) {
    y = mouseY + 16;
  }

  tooltip.style.left = `${x}px`;
  tooltip.style.top = `${y}px`;
}

/**
 * hideTooltip
 * Fades out and scales down the tooltip.
 */
function hideTooltip() {
  tooltip.style.opacity = '0';
  tooltip.style.transform = 'scale(0.95)';
}
