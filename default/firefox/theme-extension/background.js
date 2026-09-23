"use strict";

const HOST = "com.hexarchy.firefox_theme";
const POLL_MS = 1500;

let port = null;
let applied = null;
let appliedId = null;

function report(text) {
  try {
    if (port) {
      port.postMessage({ action: "report", text: String(text) });
    }
  } catch (err) {
    /* channel lost */
  }
}

function applyTheme(msg) {
  try {
    if (!msg || msg.ok === false) {
      return;
    }

    if (msg.activeThemeId) {
      const id = msg.activeThemeId;
      if (id !== appliedId) {
        browser.management.setEnabled(id, true).then(
          () => {
            appliedId = id;
            report("setEnabled OK " + id);
          },
          (err) => {
            appliedId = null;
            report("setEnabled FAIL " + id + " :: " + String(err));
          }
        );
      }
    }

    if (msg.colors) {
      const theme = { colors: msg.colors };
      if (msg.properties) {
        theme.properties = msg.properties;
      }
      const snapshot = JSON.stringify(theme);
      if (snapshot !== applied) {
        browser.theme.update(theme).then(
          () => {
            applied = snapshot;
            report("theme.update OK colors=" + snapshot.length + "b");
          },
          (err) => {
            report("theme.update FAIL :: " + String(err));
          }
        );
      }
    }
  } catch (err) {
    report("applyTheme THREW :: " + String(err) + " :: " + (err && err.stack ? err.stack : ""));
  }
}

function poll() {
  if (!port) {
    try {
      port = browser.runtime.connectNative(HOST);
    } catch (err) {
      report("connectNative threw " + String(err));
      port = null;
      return;
    }

    port.onMessage.addListener((msg) => applyTheme(msg));
    port.onDisconnect.addListener(() => {
      port = null;
    });
  }

  try {
    port.postMessage({ action: "get" });
  } catch (err) {
    port = null;
  }
}

browser.runtime.onStartup.addListener(poll);
setInterval(poll, POLL_MS);
poll();