# Mock `$.ajax` and `ampify.live` whilst in development.
(->
  
  $.mockjax
    url: '/api/locations',
    dataType: 'json',
    responseText: []
    
  
  $.mockjax
    url: '/api/locations/*',
    dataType: 'json',
    response: (settings) -> @responseText = settings.data
    
  
  $.mockjax
    url: '/api/bookmarks',
    dataType: 'json',
    responseText: []
    
  
  $.mockjax
    url: '/api/bookmarks/*',
    dataType: 'json',
    response: (settings) -> @responseText = settings.data
    
  
  $.mockjax
    url: '/api/message/*',
    dataType: 'json',
    response: (settings) ->
      id = settings.data.id
      console.log "Faking response for /api/message/#{id}"
      message = 
        'id': "msg-#{i}"
        'user': 'username'
        'll': '51.5197248,-0.1406875'
        'hashtags': ['#football']
        'keywords': ['foo', 'bar']
        'actions': ['offer']
        'users': ['tav', 'thruflo']
        'content': "!offer @tav and @thruflo foo #football bar #{id}"
        'created': +new Date
        'appreciation_count': Math.floor(Math.random() * 100)
        'reply_count': Math.floor(Math.random() * 3)
        '__initial_data':
          cursor: 0
          results: []
      mi = parseInt id.slice(4)
      cursor = 0
      for i in [mi+10..mi+14]
        result =
          'id': "msg-#{i}"
          'user': 'username'
          'll': '51.5197248,-0.1406875'
          'hashtags': ['#football']
          'keywords': ['foo', 'bar']
          'actions': ['offer']
          'users': ['tav', 'thruflo']
          'content': "!offer @tav and @thruflo foo #football bar #{i}"
          'created': +new Date
          'appreciation_count': Math.floor(Math.random() * 100)
          'reply_count': Math.floor(Math.random() * 3)
          'in_reply_to': id
        message.__initial_data.results.push result
      @responseText = message
      
  
  
  $.mockjax
    url: '/api/messages',
    dataType: 'json',
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
          'id': "msg-#{i}"
          'user': 'username'
          'll': settings.data.ll
          'hashtags': ['#football']
          'keywords': ['foo', 'bar']
          'actions': ['offer']
          'users': ['tav', 'thruflo']
          'content': "!offer @tav and @thruflo foo #football bar #{i}"
          'created': +new Date
          'appreciation_count': Math.floor(Math.random() * 100)
          'reply_count': Math.floor(Math.random() * 3)
        if settings.data.in_reply_to?
          result['in_reply_to'] = settings.data.in_reply_to
        results.push result
      @responseText =
        cursor: cursor
        distance: distance
        results: results
      
    
  
)()
