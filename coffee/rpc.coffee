# Public Domain (-) 2012 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  path = '/.rpc'
  pyPath = '/.pyrpc'

  context = null
  isPy = {}
  registry = {}

  exports.rpc = () ->

    params = Array.prototype.slice.call arguments
    name = params[0]
    url = if isPy[name] then pyPath else path
    errback = null
    header = {}

    self = {header: header}
    self.do = (callback) ->
      xhr = new XMLHttpRequest
      xhr.open "POST", url, true
      xhr.onreadystatechange = () ->
        if xhr.readyState isnt 4
          return
        if xhr.status isnt 200
          errback() if errback
          return
        resp = JSON.parse(xhr.responseText)
        if resp.error
          errback(resp.error) if errback
          return
        ctx = {header: resp.header}
        callback(ctx, resp.reply...)
        return
      xhr.send(JSON.stringify({header: self.header, call: params}))
      return self

    self.error = (cb) ->
      errback = cb
      return self

    return self

  return
