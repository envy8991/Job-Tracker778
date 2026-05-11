const target = new URL("app/", window.location.href);

if (window.location.pathname.endsWith("/website/") || window.location.pathname.endsWith("/website/index.html") || !window.location.pathname.endsWith("/app/")) {
  window.location.replace(target);
}
