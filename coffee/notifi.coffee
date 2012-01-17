# Public Domain (-) 2012 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  doc = root.document
  $notifi = doc.createElement 'div'
  $notifi.id = 'notifi'

  transitionEvents =
    Moz: 'transitionend'
    ms: 'MSTransitionEnd'
    O: 'oTransitionEnd'
    Webkit: 'webkitTransitionEnd'

  transitionEvent = 'transitionend'
  getEvent = (style) ->
    if typeof style['TransitionProperty'] is 'string'
      return 1
    for prefix, event of transitionEvents
      if typeof style[prefix+'TransitionProperty'] is 'string'
        transitionEvent = event
        return 1
    return

  exports.initNotifi = (elem) ->
    if !getEvent(elem.style)
      return
    return 1

  initNotifier = (type, sticky) ->
    (msg, callback) ->
      s

  exports.notifiAsk = initNotifier 'ask', true
  exports.notifiDoing = initNotifier 'doing', true
  exports.notifiDone = initNotifier 'done'
  exports.notifiError = initNotifier 'error'
