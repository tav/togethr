# Public Domain (-) 2011-2012 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

((root, doc, ASSETS) ->

  # We declare a few property names to help with minification.
  appendChild = 'appendChild'
  createElement = 'createElement'
  innerHTML = 'innerHTML'
  location = 'location'
  repeat = setTimeout

  # Frame bust to avoid clickjacking attacks.
  if self isnt top
    top[location] = self[location]
    return

  # Grab the <head> and <body>.
  head = doc.head or doc.getElementsByTagName('style')[0].parentNode
  body = doc.body

  # Utility function to load the CSS stylesheet at the given `path`.
  CSS = (path) ->
    s = doc[createElement] 'link'
    s.rel = 'stylesheet'
    s.href = "#{STATIC}#{path}"
    head[appendChild] s
    return s

  # Compute variables relating to the progress indicator.
  width = 240 # [keep this synced with the stylesheet]
  step = target = width / 10
  finished = false
  finishReq = 3

  incr = ->
    if (target + step) > width
      target = width
    else
      target += step
    return

  finish = ->
    finishReq -= 1
    if finishReq is 0
      target = width
      finished = true
    else
      incr()
    return

  # Utility function to load the JavaScript at the given `path`.
  JS = (path, async, callback) ->
    s = doc[createElement] 'script'
    s.type = 'text/javascript'
    if async
      s.async = true
    s.onload = ->
      if not s._l
        s._l = true
        incr()
        callback() if callback
      return
    s.onreadystatechange = ->
      if (s.readyState is "loaded" or s.readyState is "complete") and not s._l
        s._l = true
        incr()
        callback() if callback
      return
    s.src = path
    head[appendChild] s
    return s

  # Load Google Analytics.
  if doc[location].hostname isnt "localhost"
    root._gaq = [
      ['_setAccount', ANALYTICS_ID]
      ['_setDomainName', ANALYTICS_HOST]
      ['_trackPageview']
    ]
    JS "https://ssl.google-analytics.com/ga.js", true

  notSupported = () ->
    for prop in ['ProgressEvent', 'Int32Array', 'addEventListener', 'localStorage', 'FormData', 'postMessage']
      if !root[prop]
        return true

  # Check if certain "modern" browser features are available. If not, prompt the
  # user to use a more recent browser.
  if notSupported() or !Array.isArray

    CSS ASSETS['update.css']

    # We can hopefully add IE and Opera to this list once IE 10 and Opera 12 are
    # officially released.
    browsers = [
      ['Chrome', 'http://www.google.com/chrome', '16']
      ['Firefox', 'http://getfirefox.com', '9']
      ['Safari', 'http://www.apple.com/safari/', '5.1']
    ]

    c = doc[createElement] 'div'
    h1 = doc[createElement] 'h1'
    h1[innerHTML] = 'Please use a more recent browser like:'

    hr = doc[createElement] 'hr'
    ul = doc[createElement] 'ul'

    for [name, url, version] in browsers
      link = """<a href="#{url}" title="Upgrade to the latest #{name}" """
      li = doc[createElement] 'li'
      li[innerHTML] = """#{link} class="img"><img src="#{STATIC}#{ASSETS['gfx/' + name + '.png']}" alt="#{name}"></a><div>#{link}>#{name} #{version}+</a></div>""" # emacs "
      ul[appendChild] li

    c[appendChild] h1
    c[appendChild] hr
    c[appendChild] ul
    body[appendChild] c

    return

  # Set the body background colour to dampen delayed flashes.
  body.style.backgroundColor = BGCOLOR

  # Initialise the progress indicator.
  twrap = doc[createElement] 'div'
  twrap.id = 'ltw'
  text = doc[createElement] 'div'
  text.id = 'lt'
  text[innerHTML] = 'L O A D I N G '

  ellip = doc[createElement] 'span'
  ellip[innerHTML] = '. '
  elstates = ['. ', '. . ', '. . .']
  elstate = 0

  wrap = doc[createElement] 'div'
  wrap.id = 'lw'
  bar = doc[createElement] 'div'
  bar.id = 'lb'

  text[appendChild] ellip
  twrap[appendChild] text
  body[appendChild] twrap
  wrap[appendChild] bar
  body[appendChild] wrap

  curwidth = 0
  barStyle = bar.style

  progress = ->
    if target > curwidth
      curwidth += 24
      elstate += 0.30
      ellip[innerHTML] = elstates[~~(elstate % 3)]
      barStyle.width = curwidth + 'px'
    if curwidth < width
      repeat progress, 5
      return
    if finished
      body.removeChild twrap
      body.removeChild wrap
      togethr.focus()
    return

  progress()

  # Utility function to repeatedly verify that a predicate has been satisfied
  # relating to some DOM element.
  check = (elem, pred, callback) ->
    if pred(elem)
      callback()
    else
      repeat((-> check(elem, pred, callback)), 5)
    return

  # TODO(tav): Select the bidi stylesheet depending on session info.
  # Load the CSS stylesheet.
  check CSS(ASSETS['site.css']),
    (elem) ->
      try
        if elem.sheet and elem.sheet.cssRules.length > 0
            return true
        else if elem[styleSheet] and elem[styleSheet].cssText.length > 0
            return true
        else if elem[innerHTML] and elem[innerHTML].length > 0
            return true
      catch err
        return false
    , finish

  # Load TypeKit.
  JS "https://use.typekit.com/#{TYPEKIT}.js", false, ->
    try
      Typekit.load
        active: finish
        inactive: finish
    catch e
    incr()
    return

  # Load the client.
  JS "#{STATIC}#{ASSETS['client.js']}", false, ->
    togethr.run incr
    finish()
    return

  return

)(window, document, ASSETS)
