(function () {
  var post = function (o) { window.chrome.webview.postMessage(JSON.stringify(o)); };
  marked.setOptions({ gfm: true, breaks: false });

  var decode = function (s) { try { return decodeURIComponent(s); } catch (e) { return s; } };

  var slugify = function (s) {
    return s.toLowerCase().trim().replace(/[^\p{L}\p{N}\s_-]/gu, '').replace(/\s+/g, '-');
  };

  var assignHeadingIds = function () {
    var used = {};
    document.querySelectorAll('#content h1, #content h2, #content h3, #content h4, #content h5, #content h6').forEach(function (h) {
      var base = slugify(h.textContent || '');
      if (!base) return;
      var id = base, n = 0;
      while (used[id]) { n += 1; id = base + '-' + n; }
      used[id] = true;
      h.id = id;
    });
  };

  var scrollToAnchor = function (a) {
    if (!a) return;
    var t = document.getElementById(decode(a));
    if (t) t.scrollIntoView();
  };

  window.chrome.webview.addEventListener('message', function (e) {
    var m = JSON.parse(e.data);
    if (m.type !== 'render') return;
    document.getElementById('theme').setAttribute('href', 'https://app.molmd/' + (m.dark ? 'dark.css' : 'light.css'));
    document.getElementById('base').setAttribute('href', m.baseUrl);
    var html = DOMPurify.sanitize(marked.parse(m.markdown), { FORBID_TAGS: ['style', 'form', 'iframe', 'object', 'embed'] });
    document.getElementById('content').innerHTML = html;
    document.querySelectorAll('input[type=checkbox]').forEach(function (c) { c.disabled = true; });
    assignHeadingIds();
    window.scrollTo(0, 0);
    scrollToAnchor(m.anchor);
    post({ type: 'rendered' });
  });

  document.addEventListener('click', function (e) {
    var a = e.target.closest ? e.target.closest('a') : null;
    if (!a) return;
    e.preventDefault();
    var href = a.getAttribute('href') || '';
    if (href.charAt(0) === '#') {
      scrollToAnchor(href.slice(1));
      return;
    }
    post({ type: 'link', href: a.href, raw: href });
  });
  document.addEventListener('contextmenu', function (e) { e.preventDefault(); });
  post({ type: 'ready' });
})();
