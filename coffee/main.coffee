define 'main', (exports, root) ->

  exports.run = ->

    if self isnt top
      top.location = self.location
      return

    $body = $ '#body'
    view = new togethr.view.SinglePageView el: $body
    $body.show()
