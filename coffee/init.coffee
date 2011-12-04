# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

((doc) ->

  body = doc.body
  head = doc.head or doc.getElementsByTagName('style')[0].parentNode
  static = '/.static/'

  # Utility function to load the CSS stylesheet at the given `path`.
  CSS = (path) ->
    s = doc.createElement('link')
    s.rel = 'stylesheet'
    s.href = "#{static}#{path}"
    head.appendChild s
    return

  # Check if certain "modern" browser features are available. If not, prompt the
  # user to use a more recent browser.
  if not postMessage? or not localStorage?

    CSS 'update.css'
    browsers = [
      ['chrome', 'Chrome', 'http://www.google.com/chrome']
      ['firefox', 'Firefox', 'http://getfirefox.com']
      ['safari', 'Safari', 'http://www.apple.com/safari/']
    ]

    c = doc.createElement 'div'
    h1 = doc.createElement 'h1'
    h1.innerHTML = 'Please use a more recent browser like:'

    hr = doc.createElement 'hr'
    ul = doc.createElement 'ul'

    for [id, name, url] in browsers
      li = doc.createElement 'li'
      li.innerHTML = """
        <a href="#{url}" title="Upgrade to the latest #{name}" class="img">
          <img src="#{static}gfx/browser.#{id}.png" alt="#{name}" />
        </a>
        <div>
          <a href="#{url}" title="Upgrade to the latest #{name}">
            #{name}
          </a>
        </div>
        </a>
      """ # emacs "
      ul.appendChild li

    c.appendChild h1
    c.appendChild hr
    c.appendChild ul
    body.appendChild c

    return

)(document)
