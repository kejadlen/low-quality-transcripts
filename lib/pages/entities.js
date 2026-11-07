// Narrows the topics index as you type; without JS the page is still a full list.
const input = document.getElementById("topic-filter");
const empty = document.getElementById("topic-filter-empty");
const sections = [...document.querySelectorAll("section")];
const fold = (s) => s.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
const items = [...document.querySelectorAll(".topics li, .more-list li")].map((li) => ({ li, name: fold(li.textContent) }));

input.hidden = false;
input.addEventListener("input", () => {
  const query = fold(input.value.trim());
  for (const { li, name } of items) li.hidden = !name.includes(query);
  let any = false;
  for (const section of sections) {
    const visible = section.querySelector("li:not([hidden])") !== null;
    section.hidden = !visible;
    any ||= visible;
    const more = section.querySelector("details");
    if (more) more.open = query !== "" && more.querySelector("li:not([hidden])") !== null;
  }
  empty.hidden = any;
});
