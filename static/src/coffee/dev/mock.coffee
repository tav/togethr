# Mock `$.ajax` and `liveClient` whilst in development.
(->
  
  window.liveClient =
    subscribe: -> # noop
    unsubscribe: -> # noop
  
  
  $.mockjax
    url: '/api/locations'
    dataType: 'json'
    responseText: []
    
  
  $.mockjax
    url: '/api/locations/*'
    dataType: 'json'
    response: (settings) -> @responseText = settings.data
    
  
  $.mockjax
    url: '/api/bookmarks'
    dataType: 'json'
    responseText: []
    
  
  $.mockjax
    url: '/api/bookmarks/*'
    dataType: 'json'
    response: (settings) -> @responseText = settings.data
    
  
  $.mockjax
    url: '/api/messages/*'
    dataType: 'json'
    response: (settings) ->
      console.log "Faking response for /api/message/*"
      console.log settings#, settings.data, settings.data.id
      id = settings.data.id
      console.log id
      message = 
        id: id
        user: 'username'
        ll: '51.5197248,-0.1406875'
        hashtags: ['#football']
        keywords: ['foo', 'bar']
        actions: ['offer']
        users: ['tav', 'thruflo']
        content: "!offer @tav and @thruflo foo #football bar #{id}"
        created: +new Date
        appreciation_count: Math.floor(Math.random() * 100)
        reply_count: Math.floor(Math.random() * 3)
        replies:
          cursor: 0
          results: []
      mi = parseInt id.slice(4)
      cursor = 0
      for i in [mi+10..mi+14]
        result =
           id: "msg-#{i}"
           user: 'username'
           ll: '51.5197248,-0.1406875'
           hashtags: ['#football']
           keywords: ['foo', 'bar']
           actions: ['offer']
           users: ['tav', 'thruflo']
           content: "!offer @tav and @thruflo foo #football bar #{i}"
           created: +new Date
           appreciation_count: Math.floor(Math.random() * 100)
           reply_count: Math.floor(Math.random() * 3)
           in_reply_to: id
        message.replies.results.push result
      console.log message
      @responseText = message
      
    
  
  $.mockjax
    url: '/api/messages'
    dataType: 'json'
    response: (settings) ->
      console.log 'Faking response for /api/messages'
      # fake a cursor for now
      cursor = 0
      # return the distance in the query or generate a random one
      if settings.data.distance?
        distance = settings.data.distance
      else
        r = Math.random()
        distance = Math.sqrt(r * r * r * 100000)
      results = []
      for i in [0..10]
        result =
          id: "msg-#{i}"
          user: 'username'
          ll: settings.data.ll
          hashtags: ['#football']
          keywords: ['foo', 'bar']
          actions: ['offer']
          users: ['tav', 'thruflo']
          content: "!offer @tav and @thruflo foo #football bar #{i}"
          created: +new Date
          appreciation_count: Math.floor(Math.random() * 100)
          reply_count: Math.floor(Math.random() * 3)
        if settings.data.in_reply_to?
          result['in_reply_to'] = settings.data.in_reply_to
        results.push result
      @responseText =
        cursor: cursor
        distance: distance
        results: results
      
    
  
  
  $.mockjax
    url: '/api/query'
    dataType: 'json'
    response: (settings) ->
      console.log 'Faking response for /api/query'
      # fake a cursor for now
      cursor = 0
      # return the distance in the query or generate a random one
      if settings.data.distance?
        distance = settings.data.distance
      else
        r = Math.random()
        distance = Math.sqrt(r * r * r * 100000)
      d = settings.data
      hashtags = if d.hashtags? and d.hashtags.length then d.hashtags else ['football']
      keywords = if d.keywords? and d.keywords.length then d.keywords else ['foo', 'bar']
      actions = if d.actions? and d.actions.length then d.actions else ['offer']
      users = if d.users? and d.users.length then d.users else ['tav', 'thruflo']
      
      offset = 0
      if settings.data.in_reply_to
        offset = 10 + parseInt settings.data.in_reply_to.slice 4
      
      start = offset
      end = offset + 6
      
      results = []
      for i in [start..end]
        content = "!#{actions.join ' !'} #{keywords.join ' '} @#{users.join ' @'} ##{hashtags.join(' #')}"
        result =
          id: "msg-#{i}"
          user: 'username'
          ll: settings.data.ll
          hashtags: hashtags
          keywords: keywords
          actions: actions
          users: users
          content: "#{content} #{i}"
          created: +new Date
          appreciation_count: Math.floor(Math.random() * 100)
          reply_count: Math.floor(Math.random() * 3)
        if settings.data.in_reply_to?
          result['in_reply_to'] = settings.data.in_reply_to
        results.push result
      @responseText =
        cursor: cursor
        distance: distance
        results: results
      
    
  
  
)()

