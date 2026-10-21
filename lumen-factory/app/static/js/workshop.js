(function () {
  var form = document.getElementById("launch-form");
  var card = document.getElementById("launch-card");
  var status = document.getElementById("form-status");
  if (!form || !card) {
    return;
  }

  form.addEventListener("submit", function (event) {
    event.preventDefault();
    var name = document.getElementById("site-name").value.trim();
    var tagline = document.getElementById("tagline").value.trim();
    if (!name || !tagline) {
      status.textContent = "Enter a site name and a tagline.";
      return;
    }
    card.querySelector("[data-name]").textContent = name;
    card.querySelector("[data-tagline]").textContent = tagline;
    card.querySelector("[data-serial]").textContent = "LF-" + serial(name + "|" + tagline);
    card.classList.add("is-stamped");
    status.textContent = "Card stamped in this browser. Nothing was saved.";
  });

  function serial(value) {
    var hash = 0;
    for (var i = 0; i < value.length; i += 1) {
      hash = (hash * 31 + value.charCodeAt(i)) >>> 0;
    }
    return hash.toString(16).slice(0, 6).toUpperCase().padStart(6, "0");
  }
})();
