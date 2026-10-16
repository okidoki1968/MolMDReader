(function () {
  var post = function (o) { window.chrome.webview.postMessage(JSON.stringify(o)); };
  marked.setOptions({ gfm: true, breaks: false });

  window.chrome.webview.addEventListener('message', function (e) {
    var m = JSON.parse(e.data);
    if (m.type !== 'render') return;
    document.getElementById('theme').setAttribute('href', 'https://app.molmd/' + (m.dark ? 'dark.css' : 'light.css'));
    document.getElementById('base').setAttribute('href', m.baseUrl);
    var html = DOMPurify.sanitize(marked.parse(m.markdown), { FORBID_TAGS: ['style', 'form', 'iframe', 'object', 'embed'] });
    document.getElementById('content').innerHTML = html;
    document.querySelectorAll('input[type=checkbox]').forEach(function (c) { c.disabled = true; });
    window.scrollTo(0, 0);
    if (m.anchor) { var t = document.getElementById(m.anchor); if (t) t.scrollIntoView(); }
    post({ type: 'rendered' });
  });

  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a') : null;
    if (!a) return;
    e.preventDefault();
    var href = a.getAttribute('href') || '';
    if (href.charAt(0) === '#') {
      var t = document.getElementById(decodeURIComponent(href.slice(1)));
      if (t) t.scrollIntoView();
      return;
    }
    post({ type: 'link', href: a.href, raw: href });
  });
  document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  post({ type: 'ready' });
})();
