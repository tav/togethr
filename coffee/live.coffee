# Provides a `LiveClient` for consuming live notifications.  Instantiate with a
# `session_id` and then use `subscribe(query_id, callback)` and 
# `unsubscribe(query_id)` to listen / stop listening for notifications of new
# items that match the query with the given id, e.g.:
# 
#     client = new togethr.live.LiveClient 'sid'
#     client.bind 'ready', ->
#         client.subscribe 'qid', (query_id, items) -> 
#             # do foo with items
#         
define 'togethr.live', (exports, root) ->
  
  class Events
  _.extend Events::, Backbone.Events
  
  # `PollingSocket` is a `WebSocket` impersonator implemented with long polling.
  # Initialize with a `url` and then call `send(data)` to start a cycle of
  # request -> response -> request, etc., e.g.:
  #
  #     sock = new PollingSocket 'wss://host/path'
  #     sock.send('sqid:qid')
  # 
  # Calling `send(data)` again when the socket is waiting for a response will
  # not send the `data` immediately.  Instead it will update the `data` to be
  # sent when the next request is made.
  # 
  # You can `bind()` to `open`, `message`, `error` and `close` events.  Note
  # that a `message` handler can be used to update the data to be sent with
  # the next request:
  # 
  #     sock.bind 'message', (data) -> sock.send('send this data next time')
  # 
  class PollingSocket extends Events
    OPEN: 1
    CLOSED: 3
    BACKOFF_CEILING: 60 * 1000
    data: null
    state: null
    is_in_progress: false
    attempt: 0
    timeout: null
    backoff: ->
      delay = Math.pow(2, @attempt) * 1000
      Math.min delay, @BACKOFF_CEILING
    
    send: (data) ->
      console.log 'PollingSocket.send', data
      @data = data
      if @is_in_progress
        console.log 'Is already in progress.'
        return 
      if @timeout?
        console.log 'Clearing timeout.'
        window.clearTimeout @timeout
      $.ajax
        url: @url,
        dataType: 'jsonp',
        data: q: data
        success: (data) => 
          console.log 'PollingSocket.success', data
          if @state isnt @CLOSED
            @trigger 'message', this, data: data
            @attempt = 0
        
        error: (transport, status, err) => 
          console.log 'PollingSocket.error', transport, status, err
          if @state isnt @CLOSED
            @trigger 'error', this
            @attempt += 1
        
        complete: =>
          console.log 'PollingSocket.complete'
          if @state isnt @CLOSED
            @timeout = window.setTimeout =>
                @send @data
              , @backoff()
            @is_in_progress = false
        
      @is_in_progress = true
    
    close: ->
      @state = @CLOSED
      @trigger 'close', this
    
    constructor: (url) ->
      @url = url
      @state = @OPEN
      window.setTimeout => 
          @trigger 'open', this
        , 20
      
    
  
  # `supportsWebSockets()` returns `true` if the browser has native web socket
  # support, otherwise returns `false`.
  supportsWebSockets = -> 
    window.MozWebSocket? or window.WebSocket?
  
  # `webSocketFactory(url)` is a utility function to return a websocket.
  webSocketFactory = (url) ->
    # If the browser supports web sockets, the factory extends the native
    # implementation with `Backbone.Events` and overrides the web socket's native
    # event handlers to use `Backbone.Events.trigger()` passing the socket as the
    # first argument to any bound event handlers.  The point of which is to
    # normalise the event machinery between native and polling sockets and to make
    # sure the socket handlers can know when socket triggered the event.
    NativeWebSocket = null
    if window.MozWebSocket?
      NativeWebSocket = window.MozWebSocket
    else if window.WebSocket?
      NativeWebSocket = window.WebSocket
    if NativeWebSocket?
      ws = new NativeWebSocket url
      _.extend ws, Backbone.Events
      ws.onopen = -> @trigger 'open', this
      ws.onmessage = (event) -> @trigger 'message', this, event
      ws.onerror = -> @trigger 'error', this
      ws.onclose = -> @trigger 'close', this
      return ws
    return new PollingSocket url
  
  
  ### `LiveClient` holds open one primary and potentially multiple secondary
    connections to the server.  Use `subscribe(query_id, callback)` to bind
    to notifications for a query and `unsubscribe(query_id)` to unbind.
  ###
  class LiveClient extends Events
    
    has_primary: false
    options:
      WebSocketClass: null
      host: 'localhost'
      port: '9040'
      protocol: 'wss'
      path: '/.live/ws'
      fallback_protocol: 'https'
      fallback_path: '/.live/poll'
    
    query_mapping: {}
    dupecache: {}
    
    _cleanup: ->
      console.log 'LiveClient._cleanup', 'TODO: cleanup old items'
      
    
    
    # $(window).unbind 'unload', @close
    # $(window).bind 'unload', @close
    
    # XXX we need to handle websocket error events.  It may be that means
    # we need to normalise the readyState property in the fallback.
    
    webSocket: (url) ->
      sock = webSocketFactory url
      sock.seen = +new Date
      sock.bind 'message', (args...) => @handleMessage args...
      sock.bind 'error', (args...) => @handleError args...
      sock.bind 'close', (args...) => @handleClose args...
    
    # `process(items)` takes items in the form `{query_id: [item_type, item_id], ...}`
    # ignores items that have been processed for the same query already and sends the
    # items to the callback registered for the query_id.
    process: (items) ->
      console.log 'LiveClient.process', items
      # Clear anything in the dupecache that's more than a minute old.
      one_minute_ago = +new Date - 60000
      delete @dupecache[k] if ts < one_minute_ago for k, ts of @dupecache
      # Dedupe.
      for query_id, results of items
        deduped = []
        for result in results
          parts = result.split ','
          item_type = parts[0]
          item_id = parts[1]
          key = "#{query_id}:#{item_type}:#{item_id}"
          if key not of @dupecache
            deduped.push result
            @dupecache[key] = +new Date
        # Send the deduped to the subscribe callback.
        callback = @query_mapping[query_id].callback
        callback query_id, deduped
      
    
    handleMessage: (sock, event) ->
      console.log 'LiveClient.handleMessage', sock, event, this
      items = {}
      if event.data?
        data = JSON.parse(event.data)
        if data.items?
          items = data.items
      sock.seen = +new Date
      if sock.is_primary
        @process items
        query_ids = []
        for query_id, mapping_item of @query_mapping
          query_ids.push query_id
          if mapping_item.secondary?
            mapping_item.secondary.ready_to_close = true
        if query_ids.length
          data = "#{@session_id},#{query_ids.join ','}"
          sock.send data
      else
        @process items
        if sock.ready_to_close
          sock.close()
        else
          sock.send sock.data
        
      
    
    handleError: (sock) ->
      console.error 'LiveClient.handleError', sock
    
    handleClose: (sock) ->
      console.error 'LiveClient.handleClose', sock
    
    
    # `subscribe(query_id, callback)` opens a secondary channel with `query_id`
    # and stores an item mapping the `query_id` to the `callback` and channel.
    subscribe: (query_id, callback) ->
      console.log 'LiveClient.subscribe', query_id, callback
      if query_id of @query_mapping
        return
      mapping_item =
        ready_to_close: false,
        callback: callback
      if $.isEmptyObject @query_mapping
        @primary.send "#{@session_id},#{query_id}"
      else
        sock = @webSocket @url
        sock.is_primary = false
        sock.bind 'open', => sock.send "#{@session_id},#{query_id}"
        mapping_item.secondary = sock
      @query_mapping[query_id] = mapping_item
    
    # `unsubscribe(query_id)` removes the `query_id` mapping item and closes
    # any corresponding secondary channel.
    unsubscribe: (query_id) ->
      console.log 'LiveClient.unsubscribe', query_id
      if query_id not of @query_mapping
        return
      item = @query_mapping[query_id]
      item.secondary.close() if item.secondary?
      delete @query_mapping[query_id]
    
    # Initialize a query mapping, open the primary channel, fire ready and
    # start a cleanup loop.
    constructor: (session_id, options) ->
      console.log 'LiveClient', session_id, options
      $.extend(@options, options) if options?
      @session_id = session_id
      @query_mapping = {}
      has_ws = supportsWebSockets()
      protocol = if has_ws then @options.protocol else @options.fallback_protocol
      path = if has_ws then @options.path else @options.fallback_pth
      port_str = if @options.port then ":#{@options.port}" else ''
      @url = "#{protocol}://#{@options.host}#{port_str}#{path}"
      @primary = @webSocket @url
      @primary.is_primary = true
      @primary.bind 'open', => @trigger 'ready'
      interval = window.setInterval @_cleanup, 5 * 60 * 1000
      $(window).bind 'unload', -> window.clearInterval interval
      
    
  
  exports.PollingSocket = PollingSocket
  exports.supportsWebSockets = supportsWebSockets
  exports.webSocketFactory = webSocketFactory
  exports.LiveClient = LiveClient
  

