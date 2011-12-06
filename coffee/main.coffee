# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  exports.run = (body, incr) ->

    view = new togethr.view.SinglePageView el: $(body)
