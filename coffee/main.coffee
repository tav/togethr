# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'main', (exports, root) ->

  exports.run = (body) ->

    view = new togethr.view.SinglePageView el: $(body)
