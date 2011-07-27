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
          'user': 'username'
          'll': settings.data.ll
          'hashtags': ['#football']
          'keywords': ['foo', 'bar']
          'actions': ['offer']
          'users': ['tav', 'thruflo']
          'content': "!offer @tav and @thruflo foo #football bar"
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
