const API_BASE = "http://localhost:7700";

// Context menu: right-click → "Save to Neuron"
chrome.runtime.onInstalled.addListener(() => {
  chrome.contextMenus.create({
    id: "save-page",
    title: "Save page to Neuron",
    contexts: ["page"],
  });
  chrome.contextMenus.create({
    id: "save-selection",
    title: "Save selection to Neuron",
    contexts: ["selection"],
  });
  chrome.contextMenus.create({
    id: "save-link",
    title: "Save link to Neuron",
    contexts: ["link"],
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === "save-page") {
    savePage(tab.url, tab.title);
  } else if (info.menuItemId === "save-selection") {
    saveText(info.selectionText, tab.title, tab.url);
  } else if (info.menuItemId === "save-link") {
    savePage(info.linkUrl, info.linkUrl);
  }
});

// Message handler from popup
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "SAVE_PAGE") {
    savePage(msg.url, msg.title).then(sendResponse);
    return true; // async
  }
  if (msg.type === "SAVE_TEXT") {
    saveText(msg.text, msg.title, msg.url).then(sendResponse);
    return true;
  }
  if (msg.type === "SAVE_YOUTUBE") {
    saveYouTube(msg.url).then(sendResponse);
    return true;
  }
  if (msg.type === "GET_STATUS") {
    getStatus().then(sendResponse);
    return true;
  }
  if (msg.type === "ASK") {
    ask(msg.question).then(sendResponse);
    return true;
  }
});

async function getSettings() {
  const data = await chrome.storage.local.get(["apiBase"]);
  return { apiBase: data.apiBase || API_BASE };
}

async function savePage(url, title) {
  const { apiBase } = await getSettings();
  try {
    const res = await fetch(`${apiBase}/ingest/url`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url }),
    });
    const data = await res.json();
    if (!res.ok) return { ok: false, error: data.detail };
    return { ok: true, title: data.title, chunks: data.chunks };
  } catch (e) {
    return { ok: false, error: "Cannot reach Neuron server. Is it running?" };
  }
}

async function saveText(text, title, url) {
  const { apiBase } = await getSettings();
  try {
    const res = await fetch(`${apiBase}/ingest/text`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text, title, source: "web" }),
    });
    const data = await res.json();
    return { ok: res.ok, chunks: data.chunks };
  } catch (e) {
    return { ok: false, error: "Cannot reach Neuron server." };
  }
}

async function saveYouTube(url) {
  const { apiBase } = await getSettings();
  try {
    const res = await fetch(`${apiBase}/ingest/youtube`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url }),
    });
    const data = await res.json();
    if (!res.ok) return { ok: false, error: data.detail };
    return { ok: true, title: data.title, chunks: data.chunks };
  } catch (e) {
    return { ok: false, error: "Cannot reach Neuron server." };
  }
}

async function getStatus() {
  const { apiBase } = await getSettings();
  try {
    const res = await fetch(`${apiBase}/status`);
    return await res.json();
  } catch (e) {
    return { error: "Cannot reach Neuron server. Is it running?" };
  }
}

async function ask(question) {
  const { apiBase } = await getSettings();
  try {
    const res = await fetch(`${apiBase}/ask`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ q: question }),
    });
    return await res.json();
  } catch (e) {
    return { error: "Cannot reach Neuron server." };
  }
}
