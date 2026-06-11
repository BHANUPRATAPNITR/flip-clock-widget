// State variables
let use24Hour = true;
let showSeconds = true;
let isLocked = false;
let currentDigits = {
  h1: null, h2: null,
  m1: null, m2: null,
  s1: null, s2: null
};

// Timer / Stopwatch state
let currentMode = "clock"; // "clock" | "stopwatch" | "timer"
let stopwatchSeconds = 0;
let stopwatchRunning = false;

let timerDurationMinutes = 5; // Default 5 minutes
let timerSecondsRemaining = 300;
let timerRunning = false;
let timerFinished = false;

// Slider drag state tracking
let activeDragSliders = { hours: false, minutes: false, seconds: false };

// Stopwatch history state
let stopwatchHistory = [];

// Map of card IDs to DOM elements
const cards = {
  h1: document.getElementById('h1'),
  h2: document.getElementById('h2'),
  m1: document.getElementById('m1'),
  m2: document.getElementById('m2'),
  s1: document.getElementById('s1'),
  s2: document.getElementById('s2')
};

// Drag handler elements
const dragHandle = document.getElementById('drag-handle');
const dragHint = document.querySelector('.drag-hint');
const widgetLabel = document.getElementById('widget-label');

// Synchronize label changes to Python backend (using textContent for contenteditable div)
widgetLabel.addEventListener('input', (e) => {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_label) {
    window.webkit.messageHandlers.update_label.postMessage(e.target.textContent);
  }
});

// Intercept keys on the contenteditable div
widgetLabel.addEventListener('keydown', (e) => {
  // Prevent Enter key from creating a newline; blur/submit the field instead
  if (e.key === 'Enter') {
    e.preventDefault();
    widgetLabel.blur();
  }
});

// Prevent rich HTML paste actions, paste plain text only
widgetLabel.addEventListener('paste', (e) => {
  e.preventDefault();
  const text = (e.originalEvent || e).clipboardData.getData('text/plain');
  
  // Insert plain text at the current cursor position
  if (document.queryCommandSupported('insertText')) {
    document.execCommand('insertText', false, text);
  } else {
    // Fallback if execCommand is not supported
    const selection = window.getSelection();
    if (!selection.rangeCount) return;
    selection.deleteFromDocument();
    selection.getRangeAt(0).insertNode(document.createTextNode(text));
  }
});

// Drag and Click Mode-Switch Interactions
let startX = 0, startY = 0;
let isMouseDown = false;
let dragTriggered = false;
let mouseDownTime = 0;
let alarmSilencedThisClick = false;

dragHandle.addEventListener('mousedown', (e) => {
  // Clear visual timer alert if active
  if (document.body.classList.contains('timer-alert-active')) {
    document.body.classList.remove('timer-alert-active');
    alarmSilencedThisClick = true;
    window.resetTimerState();
  } else {
    alarmSilencedThisClick = false;
  }

  // Check left click, unlocked state, and make sure we aren't clicking the text input box, timer controls, window controls, mode selector, vertical sliders, or history list
  const isControl = e.target.closest('#timer-controls') || 
                    e.target.closest('.window-controls') || 
                    e.target.closest('.mode-selector') || 
                    e.target.closest('.timer-slider-container') || 
                    e.target.closest('.history-panel') || 
                    e.target === widgetLabel;
  if (e.button === 0 && !isLocked && !isControl) {
    isMouseDown = true;
    startX = e.screenX;
    startY = e.screenY;
    dragTriggered = false;
    mouseDownTime = e.timeStamp || Date.now();
  }
});

window.addEventListener('mousemove', (e) => {
  if (isMouseDown && !dragTriggered) {
    const deltaX = Math.abs(e.screenX - startX);
    const deltaY = Math.abs(e.screenY - startY);
    // If mouse moves more than 5px while pressed, trigger native window drag in Gtk
    if (deltaX > 5 || deltaY > 5) {
      dragTriggered = true;
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.drag) {
        window.webkit.messageHandlers.drag.postMessage(JSON.stringify({
          button: 0,
          x: e.screenX,
          y: e.screenY,
          time: e.timeStamp || Date.now()
        }));
      }
    }
  }
});

window.addEventListener('mouseup', (e) => {
  if (isMouseDown) {
    isMouseDown = false;
    if (!dragTriggered) {
      if (alarmSilencedThisClick) {
        alarmSilencedThisClick = false;
      }
    }
  }
});

// Flip animation logic
function flipCard(cardKey, newValue) {
  const card = cards[cardKey];
  if (!card) return;

  const oldValue = currentDigits[cardKey];
  
  // If the value hasn't changed or it's the first run, set directly without flip
  if (oldValue === null) {
    card.querySelectorAll('span').forEach(span => span.textContent = newValue);
    currentDigits[cardKey] = newValue;
    return;
  }

  if (oldValue === newValue) return;

  // Clear any active flipping state/timeout on this card
  if (card.timeoutId) {
    clearTimeout(card.timeoutId);
    card.classList.remove('flipping');
  }

  const topBack = card.querySelector('.top-back span');
  const bottomBack = card.querySelector('.bottom-back span');
  const topFront = card.querySelector('.top-front span');
  const bottomFront = card.querySelector('.bottom-front span');

  // Prepare card faces for animation
  topBack.textContent = newValue;
  bottomFront.textContent = newValue;
  topFront.textContent = oldValue;
  bottomBack.textContent = oldValue;

  // Trigger CSS transition
  card.classList.add('flipping');
  currentDigits[cardKey] = newValue;

  // Clean up flip class and finalize values after animation finishes (600ms)
  card.timeoutId = setTimeout(() => {
    topFront.textContent = newValue;
    bottomBack.textContent = newValue;
    card.classList.remove('flipping');
    card.timeoutId = null;
  }, 580);
}

// Render digits helper
function renderTime(h, m, s) {
  const hStr = String(h).padStart(2, '0');
  const mStr = String(m).padStart(2, '0');
  const sStr = String(s).padStart(2, '0');

  flipCard('h1', hStr[0]);
  flipCard('h2', hStr[1]);
  flipCard('m1', mStr[0]);
  flipCard('m2', mStr[1]);
  
  if (showSeconds || currentMode === 'stopwatch' || currentMode === 'timer') {
    flipCard('s1', sStr[0]);
    flipCard('s2', sStr[1]);
  }
}

// Time update loop (ticks every second)
function tick() {
  updateRunningClasses();
  syncSliderPosition();

  // Stop flash alert if mode changed
  if (currentMode !== 'timer' && document.body.classList.contains('timer-alert-active')) {
    document.body.classList.remove('timer-alert-active');
  }

  if (currentMode === 'clock') {
    const now = new Date();
    
    // Format hours
    let hours = now.getHours();
    if (!use24Hour) {
      hours = hours % 12;
      hours = hours ? hours : 12; // 0 should be 12 in 12h clock
    }
    
    renderTime(hours, now.getMinutes(), now.getSeconds());

    // Update date string (e.g. Thursday, Jun 11, 2026)
    const options = { weekday: 'long', month: 'short', day: 'numeric', year: 'numeric' };
    const dateStr = now.toLocaleDateString(undefined, options);
    const dateDisplay = document.getElementById('date-display');
    if (dateDisplay && dateDisplay.textContent !== dateStr) {
      dateDisplay.textContent = dateStr;
    }
  } else if (currentMode === 'stopwatch') {
    if (stopwatchRunning) {
      stopwatchSeconds++;
    }
    
    const h = Math.floor(stopwatchSeconds / 3600);
    const m = Math.floor((stopwatchSeconds % 3600) / 60);
    const s = stopwatchSeconds % 60;
    
    renderTime(h, m, s);

    // Update status display
    const dateDisplay = document.getElementById('date-display');
    if (dateDisplay) {
      dateDisplay.textContent = `Stopwatch - ${stopwatchRunning ? 'Running' : 'Paused'}`;
    }
  } else if (currentMode === 'timer') {
    if (timerRunning && timerSecondsRemaining > 0) {
      timerSecondsRemaining--;
      if (timerSecondsRemaining === 0) {
        timerRunning = false;
        timerFinished = true;
        document.body.classList.add('timer-alert-active');
        updateControlButtonsUI();
        updateRunningClasses();
        
        // Trigger GTK system notification via bridge
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.notify) {
          window.webkit.messageHandlers.notify.postMessage(JSON.stringify({
            title: "Countdown Timer Complete",
            body: `Your timer for ${timerDurationMinutes} minutes has finished!`
          }));
        }
      }
    }

    const h = Math.floor(timerSecondsRemaining / 3600);
    const m = Math.floor((timerSecondsRemaining % 3600) / 60);
    const s = timerSecondsRemaining % 60;

    renderTime(h, m, s);

    // Update status display
    const dateDisplay = document.getElementById('date-display');
    if (dateDisplay) {
      if (timerFinished) {
        dateDisplay.textContent = "Timer Completed! Click background to silence.";
      } else {
        dateDisplay.textContent = `Timer (${timerDurationMinutes}m) - ${timerRunning ? 'Running' : 'Paused'}`;
      }
    }
  }
}

// GUI Resize Helper
window.resizeWindow = function() {
  const rect = dragHandle.getBoundingClientRect();
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.resize) {
    window.webkit.messageHandlers.resize.postMessage(JSON.stringify({
      width: Math.ceil(rect.width),
      height: Math.ceil(rect.height)
    }));
  }
};

// UI Control Button Syncer
function updateControlButtonsUI() {
  const btnPlayPause = document.getElementById('btn-play-pause');
  const path = document.getElementById('play-icon-path');
  if (!btnPlayPause || !path) return;

  let isRunning = false;
  if (currentMode === 'stopwatch') {
    isRunning = stopwatchRunning;
  } else if (currentMode === 'timer') {
    isRunning = timerRunning;
  }
  
  if (isRunning) {
    path.setAttribute('d', 'M14,19H18V5H14M6,19H10V5H6V19Z'); // Pause icon
    btnPlayPause.setAttribute('title', 'Pause');
  } else {
    path.setAttribute('d', 'M8,5.14V19.14L19,12.14L8,5.14Z'); // Play icon
    btnPlayPause.setAttribute('title', 'Start / Continue');
  }
  
  if (currentMode === 'timer') {
    document.querySelectorAll('.preset-btn').forEach(btn => {
      const mins = parseInt(btn.getAttribute('data-mins'), 10);
      if (timerDurationMinutes === mins) {
        btn.classList.add('active');
      } else {
        btn.classList.remove('active');
      }
    });
  }
}

// API methods exposed to Python
window.setTheme = function(themeName) {
  document.body.className = ''; // Reset
  if (themeName !== 'dark') { // Treat dark (monochromatic) as default root theme
    document.body.classList.add(`theme-${themeName}`);
  }
  // Keep active mode class
  document.body.classList.add(`mode-${currentMode}`);
  updateSecondsVisibilityClass();
  setTimeout(window.resizeWindow, 100);
};

window.setScale = function(scaleValue) {
  dragHandle.style.transform = `scale(${scaleValue})`;
  setTimeout(window.resizeWindow, 100);
};

window.setFormat = function(is24H) {
  use24Hour = is24H;
  tick(); // Force refresh digits immediately
};

window.setShowSeconds = function(visible) {
  showSeconds = visible;
  updateSecondsVisibilityClass();
  tick();
  setTimeout(window.resizeWindow, 100);
};

window.setLocked = function(locked) {
  isLocked = locked;
  if (isLocked) {
    dragHint.classList.remove('visible');
  } else {
    dragHint.classList.add('visible');
  }
};

window.setMode = function(modeName) {
  const prevMode = currentMode;
  currentMode = modeName;
  document.body.classList.remove('mode-clock', 'mode-stopwatch', 'mode-timer', 'timer-alert-active');
  document.body.classList.add(`mode-${modeName}`);
  
  // Clear flip history cache to prevent transition glitches on first draw
  currentDigits = { h1: null, h2: null, m1: null, m2: null, s1: null, s2: null };
  
  if (currentMode === 'stopwatch') {
    // Reset or keep stopwatch values
  } else if (currentMode === 'timer') {
    timerFinished = false;
  }
  
  // Update active segmented controls tab highlighters
  document.querySelectorAll('.mode-tab').forEach(tab => {
    if (tab.getAttribute('data-mode') === modeName) {
      tab.classList.add('active');
    } else {
      tab.classList.remove('active');
    }
  });
  
  updateControlButtonsUI();
  updateSecondsVisibilityClass();
  updateRunningClasses();
  syncSliderPosition();

  // Close history panel on mode change
  const panel = document.getElementById('history-panel');
  if (panel && panel.classList.contains('expanded')) {
    panel.classList.remove('expanded');
    setTimeout(window.resizeWindow, 320);
  }

  tick(); // Re-render immediately
  setTimeout(window.resizeWindow, 100);
};

window.toggleTimerState = function() {
  if (currentMode === 'stopwatch') {
    stopwatchRunning = !stopwatchRunning;
  } else if (currentMode === 'timer') {
    if (timerFinished) {
      window.resetTimerState();
    }
    timerRunning = !timerRunning;
  }
  updateControlButtonsUI();
  updateRunningClasses();
  tick();
};

window.resetTimerState = function() {
  document.body.classList.remove('timer-alert-active');
  if (currentMode === 'stopwatch') {
    stopwatchRunning = false;
    stopwatchSeconds = 0;
  } else if (currentMode === 'timer') {
    timerRunning = false;
    timerFinished = false;
    timerSecondsRemaining = timerDurationMinutes * 60;
  }
  
  // Clear flip cache to reset cards cleanly
  currentDigits = { h1: null, h2: null, m1: null, m2: null, s1: null, s2: null };
  updateControlButtonsUI();
  updateRunningClasses();
  syncSliderPosition();
  tick();
};

window.setTimerDuration = function(minutes) {
  timerDurationMinutes = minutes;
  window.resetTimerState();
};

window.setLabel = function(text) {
  widgetLabel.textContent = text || '';
};

function updateSecondsVisibilityClass() {
  if (showSeconds || currentMode === 'stopwatch' || currentMode === 'timer') {
    document.body.classList.remove('seconds-hidden');
  } else {
    document.body.classList.add('seconds-hidden');
  }
}

// Timer Controls Initialization
function initTimerControls() {
  const btnPlayPause = document.getElementById('btn-play-pause');
  const btnReset = document.getElementById('btn-reset');
  const btnRecord = document.getElementById('btn-record');
  const btnHistory = document.getElementById('btn-history');
  const btnClearHistory = document.getElementById('btn-clear-history');

  if (btnPlayPause) {
    btnPlayPause.addEventListener('click', (e) => {
      e.stopPropagation();
      window.toggleTimerState();
    });
  }
  if (btnReset) {
    btnReset.addEventListener('click', (e) => {
      e.stopPropagation();
      window.resetTimerState();
    });
  }
  if (btnRecord) {
    btnRecord.addEventListener('click', (e) => {
      e.stopPropagation();
      recordStopwatchSession();
    });
  }
  if (btnHistory) {
    btnHistory.addEventListener('click', (e) => {
      e.stopPropagation();
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.show_history) {
        window.webkit.messageHandlers.show_history.postMessage(null);
      }
    });
  }
  if (btnClearHistory) {
    btnClearHistory.addEventListener('click', (e) => {
      e.stopPropagation();
      clearAllHistory();
    });
  }
  document.querySelectorAll('.preset-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const mins = parseInt(btn.getAttribute('data-mins'), 10);
      window.setTimerDuration(mins);
    });
  });
}

// Scroll Wheel Time Adjustments
function initScrollAdjustments() {
  const hoursGroup = document.getElementById('group-hours');
  const minutesGroup = document.getElementById('group-minutes');
  const secondsGroup = document.getElementById('group-seconds');
  
  if (hoursGroup) {
    hoursGroup.addEventListener('wheel', (e) => {
      if (currentMode === 'timer' && !timerRunning) {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 1 : -1;
        adjustTimerDuration(delta * 3600);
      }
    }, { passive: false });
  }
  
  if (minutesGroup) {
    minutesGroup.addEventListener('wheel', (e) => {
      if (currentMode === 'timer' && !timerRunning) {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 1 : -1;
        adjustTimerDuration(delta * 60);
      }
    }, { passive: false });
  }
  
  if (secondsGroup) {
    secondsGroup.addEventListener('wheel', (e) => {
      if (currentMode === 'timer' && !timerRunning) {
        e.preventDefault();
        const delta = e.deltaY < 0 ? 5 : -5;
        adjustTimerDuration(delta);
      }
    }, { passive: false });
  }
}

function adjustTimerDuration(secondsDelta) {
  let newSeconds = timerSecondsRemaining + secondsDelta;
  if (newSeconds < 5) newSeconds = 5;
  if (newSeconds > 86399) newSeconds = 86399;
  
  timerSecondsRemaining = newSeconds;
  timerDurationMinutes = Math.round(newSeconds / 60) || 1;
  
  currentDigits = { h1: null, h2: null, m1: null, m2: null, s1: null, s2: null };
  updateControlButtonsUI();
  tick();
}

// Start update timer
setInterval(tick, 1000);
tick(); // Run once immediately

// Initialize controls and scroll adjustments
initTimerControls();
initScrollAdjustments();
initWindowControls();
initModeSelector();
initSlider();

function updateRunningClasses() {
  document.body.classList.toggle('timer-running', timerRunning);
  document.body.classList.toggle('stopwatch-running', stopwatchRunning);
}

function syncSliderPosition() {
  if (currentMode !== 'timer' || timerRunning) return;

  const knobHours = document.getElementById('slider-knob-hours');
  const knobMinutes = document.getElementById('slider-knob-minutes');
  const knobSeconds = document.getElementById('slider-knob-seconds');
  if (!knobHours || !knobMinutes || !knobSeconds) return;

  const h = Math.floor(timerSecondsRemaining / 3600);
  const m = Math.floor((timerSecondsRemaining % 3600) / 60);
  const s = timerSecondsRemaining % 60;

  const maxTravel = 120; // 140px track - 20px knob

  // Hours: 0 to 23
  if (!activeDragSliders.hours) {
    const hClamped = Math.min(23, Math.max(0, h));
    const bottomHours = (hClamped / 23) * maxTravel;
    knobHours.style.bottom = `${bottomHours}px`;
  }

  // Minutes: 0 to 59
  if (!activeDragSliders.minutes) {
    const mClamped = Math.min(59, Math.max(0, m));
    const bottomMinutes = (mClamped / 59) * maxTravel;
    knobMinutes.style.bottom = `${bottomMinutes}px`;
  }

  // Seconds: 0 to 59
  if (!activeDragSliders.seconds) {
    const sClamped = Math.min(59, Math.max(0, s));
    const bottomSeconds = (sClamped / 59) * maxTravel;
    knobSeconds.style.bottom = `${bottomSeconds}px`;
  }
}

function initSlider() {
  initSliderComponent('hours', 'slider-knob-hours', 'slider-track-hours', 23);
  initSliderComponent('minutes', 'slider-knob-minutes', 'slider-track-minutes', 59);
  initSliderComponent('seconds', 'slider-knob-seconds', 'slider-track-seconds', 59);
}

function initSliderComponent(type, knobId, trackId, maxValue) {
  const knob = document.getElementById(knobId);
  const track = document.getElementById(trackId);
  if (!knob || !track) return;

  const maxTravel = 120; // 140px track - 20px knob

  function handleMove(clientY) {
    const rect = track.getBoundingClientRect();
    let yFromBottom = rect.bottom - clientY - 10;
    yFromBottom = Math.min(maxTravel, Math.max(0, yFromBottom));
    
    knob.style.bottom = `${yFromBottom}px`;
    
    const unitValue = Math.round((yFromBottom / maxTravel) * maxValue);
    
    const h = Math.floor(timerSecondsRemaining / 3600);
    const m = Math.floor((timerSecondsRemaining % 3600) / 60);
    const s = timerSecondsRemaining % 60;
    
    let newH = h;
    let newM = m;
    let newS = s;
    
    if (type === 'hours') newH = unitValue;
    else if (type === 'minutes') newM = unitValue;
    else if (type === 'seconds') newS = unitValue;
    
    const newTotalSeconds = (newH * 3600) + (newM * 60) + newS;
    
    if (newTotalSeconds >= 5 && timerSecondsRemaining !== newTotalSeconds) {
      timerSecondsRemaining = newTotalSeconds;
      timerDurationMinutes = Math.round(newTotalSeconds / 60) || 1;
      currentDigits = { h1: null, h2: null, m1: null, m2: null, s1: null, s2: null };
      tick();
    }
  }

  knob.addEventListener('mousedown', (e) => {
    if (e.button !== 0) return;
    e.stopPropagation();
    activeDragSliders[type] = true;
    document.body.style.cursor = 'grabbing';
    knob.style.cursor = 'grabbing';
    
    const onMouseMove = (moveEvent) => {
      handleMove(moveEvent.clientY);
    };

    const onMouseUp = () => {
      activeDragSliders[type] = false;
      document.body.style.cursor = '';
      knob.style.cursor = '';
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
    };

    window.addEventListener('mousemove', onMouseMove);
    window.addEventListener('mouseup', onMouseUp);
  });

  track.addEventListener('mousedown', (e) => {
    if (e.button !== 0 || e.target === knob) return;
    e.stopPropagation();
    handleMove(e.clientY);
    
    const mousedownEvent = new MouseEvent('mousedown', {
      button: 0,
      clientX: e.clientX,
      clientY: e.clientY,
      bubbles: true
    });
    knob.dispatchEvent(mousedownEvent);
  });
}

function initModeSelector() {
  document.querySelectorAll('.mode-tab').forEach(tab => {
    tab.addEventListener('click', (e) => {
      e.stopPropagation();
      const targetMode = tab.getAttribute('data-mode');
      if (targetMode === currentMode) return;
      
      // Notify Python backend
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_mode) {
        window.webkit.messageHandlers.update_mode.postMessage(targetMode);
      }
      window.setMode(targetMode);
    });
  });
}

function initWindowControls() {
  const minBtn = document.getElementById('win-min');
  const maxBtn = document.getElementById('win-max');
  const closeBtn = document.getElementById('win-close');
  
  if (minBtn) {
    minBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.window_control) {
        window.webkit.messageHandlers.window_control.postMessage(JSON.stringify({ action: "minimize" }));
      }
    });
  }
  if (maxBtn) {
    maxBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.window_control) {
        window.webkit.messageHandlers.window_control.postMessage(JSON.stringify({ action: "maximize" }));
      }
    });
  }
  if (closeBtn) {
    closeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.window_control) {
        window.webkit.messageHandlers.window_control.postMessage(JSON.stringify({ action: "close" }));
      }
    });
  }
}

// Notify backend when loaded
window.addEventListener('DOMContentLoaded', () => {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.ready) {
    window.webkit.messageHandlers.ready.postMessage('ready');
  }
  // Setup initial UI styles & size resize
  document.body.classList.add(`mode-${currentMode}`);
  updateControlButtonsUI();
  setTimeout(window.resizeWindow, 200);
});

// Reset drag state if window loses focus to prevent mouse-stuck bugs
window.addEventListener('blur', () => {
  isMouseDown = false;
});

window.setStopwatchHistory = function(historyArray) {
  stopwatchHistory = historyArray || [];
  renderHistory();
};

function recordStopwatchSession() {
  const h = Math.floor(stopwatchSeconds / 3600);
  const m = Math.floor((stopwatchSeconds % 3600) / 60);
  const s = stopwatchSeconds % 60;
  const formattedTime = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;

  const labelVal = widgetLabel.textContent.trim();
  const sessionName = labelVal || `Session #${stopwatchHistory.length + 1}`;

  const now = new Date();
  const dateOptions = { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false };
  const formattedDate = now.toLocaleDateString(undefined, dateOptions);

  const entry = {
    name: sessionName,
    time: formattedTime,
    date: formattedDate
  };

  // Add to beginning of history list (newest first)
  stopwatchHistory.unshift(entry);

  // Cap history list size at 50 items
  if (stopwatchHistory.length > 50) {
    stopwatchHistory.pop();
  }

  // Update Python config
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_history) {
    window.webkit.messageHandlers.update_history.postMessage(JSON.stringify(stopwatchHistory));
  }

  renderHistory();

  // If history panel was closed, expand it so the user sees the newly added record!
  const panel = document.getElementById('history-panel');
  if (panel && !panel.classList.contains('expanded')) {
    toggleHistoryPanel();
  }
}

function deleteHistoryItem(index) {
  if (index >= 0 && index < stopwatchHistory.length) {
    stopwatchHistory.splice(index, 1);
    
    // Update Python config
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_history) {
      window.webkit.messageHandlers.update_history.postMessage(JSON.stringify(stopwatchHistory));
    }
    
    renderHistory();
  }
}

function clearAllHistory() {
  if (confirm("Are you sure you want to clear all stopwatch history records?")) {
    stopwatchHistory = [];
    
    // Update Python config
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.update_history) {
      window.webkit.messageHandlers.update_history.postMessage(JSON.stringify(stopwatchHistory));
    }
    
    renderHistory();
  }
}

function renderHistory() {
  const historyList = document.getElementById('history-list');
  if (!historyList) return;

  if (stopwatchHistory.length === 0) {
    historyList.innerHTML = '<div style="text-align: center; color: rgba(255, 255, 255, 0.35); font-size: 11px; padding: 16px 0;">No saved sessions. Click Save to record.</div>';
    return;
  }

  let html = '';
  stopwatchHistory.forEach((item, index) => {
    html += `
      <div class="history-item">
        <div class="item-details">
          <span class="item-name">${escapeHtml(item.name)}</span>
          <span class="item-meta">${escapeHtml(item.date)}</span>
        </div>
        <div class="item-right">
          <span class="item-time">${escapeHtml(item.time)}</span>
          <button class="delete-item-btn" onclick="deleteHistoryItem(${index})" title="Delete entry">&times;</button>
        </div>
      </div>
    `;
  });
  
  historyList.innerHTML = html;
}

function toggleHistoryPanel() {
  const panel = document.getElementById('history-panel');
  if (!panel) return;

  panel.classList.toggle('expanded');
  // Trigger window resize in GTK to adjust for height panel
  setTimeout(window.resizeWindow, 320);
}

function escapeHtml(str) {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}
