import "@hotwired/turbo-rails"
import "bootstrap"
import $ from "jquery"

// Auto select light or dark theme

; (function () {
  const htmlElement = document.querySelector("html")
  if (htmlElement.getAttribute("data-bs-theme") === "auto") {
    function updateTheme() {
      document.querySelector("html").setAttribute("data-bs-theme",
        window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
    }
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", updateTheme)
    updateTheme()
  }
})()

// Delete tag button

$(document).on("turbo:load", function () {
  $("#delete_confirm").on("keyup", function(event) {
    event.preventDefault();

    var field = $(this);
    var button = $("#delete-button");

    if (field.val() == field.attr("data-expected")) {
      button.removeClass("disabled");
    }
    else {
      button.addClass("disabled");
    }
  });

  const filter = document.querySelector("[data-repository-filter]")
  if (filter) {
    const items = [...document.querySelectorAll("[data-repository-name]")]
    const groups = [...document.querySelectorAll("[data-namespace-group]")]
    const empty = document.querySelector("[data-filter-empty]")

    const applyFilter = () => {
      const query = filter.value.trim().toLowerCase()
      items.forEach((item) => { item.hidden = !item.dataset.repositoryName.includes(query) })
      groups.forEach((group) => {
        group.hidden = ![...group.querySelectorAll("[data-repository-name]")].some((item) => !item.hidden)
      })
      empty.hidden = groups.some((group) => !group.hidden)
    }

    filter.addEventListener("input", applyFilter)
    $(document).off("keydown.repository-filter").on("keydown.repository-filter", (event) => {
      if (event.key === "/" && document.activeElement !== filter) {
        event.preventDefault()
        filter.focus()
      }
    })
  }

  const tagFilter = document.querySelector("[data-tag-filter]")
  if (tagFilter) {
    const tags = [...document.querySelectorAll("[data-tag-name]")]
    const empty = document.querySelector("[data-tag-empty]")
    tagFilter.addEventListener("input", () => {
      const query = tagFilter.value.trim().toLowerCase()
      tags.forEach((item) => { item.hidden = !item.dataset.tagName.includes(query) })
      empty.hidden = tags.some((item) => !item.hidden)
    })
  }

  document.querySelectorAll("[data-copy-text]").forEach((button) => {
    button.addEventListener("click", async () => {
      await navigator.clipboard.writeText(button.dataset.copyText)
      const label = button.textContent
      button.textContent = "已复制"
      button.classList.add("copied")
      window.setTimeout(() => { button.textContent = label; button.classList.remove("copied") }, 1400)
    })
  })
});
