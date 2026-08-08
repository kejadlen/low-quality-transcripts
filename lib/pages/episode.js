const audio = document.getElementById("audio");

function parseTimestamp(ts) {
  const parts = ts.split(":").map(Number);
  if (parts.length === 3) return parts[0] * 3600 + parts[1] * 60 + parts[2];
  if (parts.length === 2) return parts[0] * 60 + parts[1];
  return parts[0];
}

document.addEventListener("click", (e) => {
  const link = e.target.closest("[data-seek]");
  if (!link) return;
  e.preventDefault();
  const seconds = parseTimestamp(link.dataset.seek);
  audio.currentTime = seconds;
  audio.play();
  history.replaceState(null, "", link.getAttribute("href"));
});

await import("./pagefind/pagefind-highlight.js");
new PagefindHighlight({ highlightParam: "highlight" });
