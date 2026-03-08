let currentTab = null;
let isYouTube = false;

// Init
document.addEventListener("DOMContentLoaded", async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  currentTab = tab;

  // Set page info
  document.getElementById("pageTitle").textContent = tab.title || tab.url;
  document.getElementById("pageUrl").textContent = tab.url;

  // Detect YouTube
  isYouTube = tab.url?.includes("youtube.com/watch") || tab.url?.includes("youtu.be/");
  if (isYouTube) {
    document.getElementById("youtubeBadge").style.display = "block";
  }

  // Check server status
  chrome.runtime.sendMessage({ type: "GET_STATUS" }, (resp) => {
    const dot = document.getElementById("statusDot");
    const count = document.getElementById("statusCount");
    if (resp?.total_chunks !== undefined) {
      dot.classList.add("online");
      count.textContent = `${resp.total_chunks.toLocaleString()} chunks`;
    } else {
      dot.classList.add("offline");
      count.textContent = "offline";
    }
  });

  // Check for selected text
  chrome.scripting.executeScript({
    target: { tabId: tab.id },
    func: () => window.getSelection()?.toString()?.trim(),
  }).then(([result]) => {
    if (result?.result?.length > 10) {
      document.getElementById("saveSelection").style.display = "flex";
    }
  }).catch(() => {});
});

// Save page
document.getElementById("savePage").addEventListener("click", async () => {
  const btn = document.getElementById("savePage");
  btn.disabled = true;
  btn.innerHTML = "<span>⏳</span> Saving...";

  const msgType = isYouTube ? "SAVE_YOUTUBE" : "SAVE_PAGE";
  chrome.runtime.sendMessage(
    { type: msgType, url: currentTab.url, title: currentTab.title },
    (resp) => showFeedback(resp, btn, "⚡ Save to Neuron")
  );
});

// Save selection
document.getElementById("saveSelection").addEventListener("click", async () => {
  const btn = document.getElementById("saveSelection");
  btn.disabled = true;

  chrome.scripting.executeScript({
    target: { tabId: currentTab.id },
    func: () => window.getSelection()?.toString()?.trim(),
  }).then(([result]) => {
    const text = result?.result;
    if (!text) return;
    chrome.runtime.sendMessage(
      { type: "SAVE_TEXT", text, title: currentTab.title, url: currentTab.url },
      (resp) => showFeedback(resp, btn, "✂️ Save selected text")
    );
  });
});

// Ask
document.getElementById("askBtn").addEventListener("click", () => {
  const q = document.getElementById("askInput").value.trim();
  if (!q) return;

  const btn = document.getElementById("askBtn");
  const answerEl = document.getElementById("answer");
  btn.disabled = true;
  btn.textContent = "Thinking...";
  answerEl.style.display = "none";

  chrome.runtime.sendMessage({ type: "ASK", question: q }, (resp) => {
    btn.disabled = false;
    btn.textContent = "Ask Neuron";
    answerEl.style.display = "block";
    answerEl.textContent = resp?.answer || resp?.error || "No response.";
  });
});

// Enter to submit ask
document.getElementById("askInput").addEventListener("keydown", (e) => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    document.getElementById("askBtn").click();
  }
});

function showFeedback(resp, btn, resetLabel) {
  const fb = document.getElementById("feedback");
  btn.disabled = false;
  btn.innerHTML = resetLabel;
  fb.style.display = "block";

  if (resp?.ok) {
    fb.className = "feedback success";
    fb.textContent = `✓ Saved "${(resp.title || "").slice(0, 50)}" — ${resp.chunks} chunks`;
  } else {
    fb.className = "feedback error";
    fb.textContent = resp?.error || "Something went wrong.";
  }

  setTimeout(() => { fb.style.display = "none"; }, 4000);
}
