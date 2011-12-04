# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

((root, doc) ->

  # Define config params.
  analyticsHost = '.togethr.at'
  analyticsId = 'UA-90176-30'
  bgColor = "#252525"
  static = '/.static/'
  typekit = ''

  # Frame bust to avoid clickjacking attacks.
  if self isnt top
    top.location = self.location
    return

  # Grab the <head> and <body>.
  head = doc.head or doc.getElementsByTagName('script')[0].parentNode
  body = doc.body

  # Utility function to load the CSS stylesheet at the given `path`.
  CSS = (path) ->
    s = doc.createElement 'link'
    s.rel = 'stylesheet'
    s.href = "#{static}#{path}"
    head.appendChild s
    return s

  # Check if certain "modern" browser features are available. If not, prompt the
  # user to use a more recent browser.
  if not postMessage? or not localStorage?

    CSS ASSETS['update.css']
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
      img = "gfx/browser.#{id}.png"
      li = doc.createElement 'li'
      li.innerHTML = """
        <a href="#{url}" title="Upgrade to the latest #{name}" class="img">
          <img src="#{static}#{ASSETS[img]}" alt="#{name}" />
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

  # Set the body background colour to avoid overly delayed flashes.
  body.style.backgroundColor = bgColor

  # Compute variables relating to the progress indicator.
  width = 240 # [keep this synced with the sass]
  step = target = width / 10
  finished = false

  incr = ->
    if (target + step) > width
      target = width
    else
      target += step

  finish = ->
    target = width
    finished = true

  # Utility function to repeatedly verify that a predicate has been satisfied
  # relating to some DOM element.
  check = (elem, pred, callback) ->
    if pred(elem)
      callback()
    else
      setTimeout((-> check(elem, pred, callback)), 5)
    return

  # TODO(tav): Select the bidi stylesheet depending on session info.
  style = ASSETS['site.data.css']

  # Load the CSS stylesheet and initialise the progress indicator once it has
  # been loaded.
  check CSS(style),
    (elem) ->
      try
        if elem.sheet and elem.sheet.cssRules.length > 0
            return true
        else if elem.styleSheet and elem.styleSheet.cssText.length > 0
            return true
        else if elem.innerHTML and elem.innerHTML.length > 0
            return true
      catch err
        return false
    , ->

      twrap = doc.createElement 'div'
      twrap.id = 'ltw'

      text = doc.createElement 'div'
      text.id = 'lt'
      text.innerHTML = 'L O A D I N G '

      ellip = doc.createElement 'span'
      ellip.innerHTML = '. '
      elstates = ['. ', '. . ', '. . .']
      elstate = 0

      wrap = doc.createElement 'div'
      wrap.id = 'lw'

      bar = doc.createElement 'div'
      bar.id = 'lb'

      text.appendChild ellip
      twrap.appendChild text
      body.appendChild twrap
      wrap.appendChild bar
      body.appendChild wrap

      curwidth = 0
      style = bar.style

      progress = ->
        if target > curwidth
          curwidth += 4
          elstate += 0.05
          ellip.innerHTML = elstates[~~(elstate % 3)]
          style.width = curwidth + 'px'
        if curwidth < width
          setTimeout(progress, 5)
          return
        if finished
          body.removeChild(twrap)
          body.removeChild(wrap)
          container.style.display = 'block'
        return

      progress()
      return

  # Utility function to load the JavaScript at the given `path`.
  JS = (path, async, callback) ->
    s = doc.createElement 'script'
    s.type = 'text/javascript'
    if async
      s.async = true
    if callback
      s.onload = ->
        if not s.isLoaded
          s.isLoaded = true
          incr()
          callback()
        return
      s.onreadystatechange = ->
        if (s.readyState is "loaded" or s.readyState is "complete") and not s.isLoaded
          s.isLoaded = true
          incr()
          callback()
        return
    s.src = path
    head.appendChild s
    return s

  # Load Google Analytics.
  if doc.location.hostname isnt "localhost"
    root._gaq = [
      ['_setAccount', analyticsId]
      ['_setDomainName', analyticsHost]
      ['_trackPageview']
    ]
    JS "https://ssl.google-analytics.com/ga.js", true

  # Create the root #body element.
  container = doc.createElement 'div'
  container.id = 'body'
  container.style.display = 'none'
  body.appendChild container

  # Load the scripts.
  JS "https://ajax.googleapis.com/ajax/libs/jquery/1.7/jquery.min.js", false, ->
    JS "#{static}#{ASSETS['base.js']}", false, ->
      JS "#{static}#{ASSETS['client.js']}", false, ->
        main.run(container)
        finish()

  return

)(window, document)
