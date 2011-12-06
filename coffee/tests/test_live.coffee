$(document).ready ->
  
  module 'togethr.live', 
    setup: ->
      # pass
      
    
    teardown: -> 
      # pass
      
    
  
  # `createItem()` and `setupQuery()` are utility functions to test integration
  # with the live server.
  createItem = (to, by_, msg, callback) ->
    qs = "to=#{to}&by=#{by_}&msg=#{msg}}"
    $.getJSON "/create", qs, (response) ->
        callback true if 'success' of response
    
  
  setupQuery = (session_id, query_id, query, callback) ->
    qs = "sqid=#{session_id}:#{query_id}&q=#{query}"
    $.getJSON "/search", qs, (response) ->
        callback true if 'success' of response
    
  
        
  test "Sanity check tests", ->
      a = true
      ok a
  
  test "Initialize a new LiveClient", ->
      client = new togethr.live.LiveClient 'sid'
      ok client?
  
  asyncTest "Check the ready event fires.", ->
      client = new togethr.live.LiveClient 'sid'
      client.bind 'ready', -> 
          ok true
          start()
      
  
  asyncTest "Subscribe to a query.", ->
      client = new togethr.live.LiveClient 'sid'
      client.bind 'ready', -> 
          client.subscribe 'qid', (event) -> # pass
          ok not $.isEmptyObject client.query_mapping
          start()
          client.unsubscribe 'qid'
      
  
  asyncTest "Subscribe callback recieves query_ids and items.", ->
      client = new togethr.live.LiveClient 'sid'
      client.bind 'ready', -> 
          setupQuery 'sid', 'test_query_1', 'foo2', ->
              client.subscribe 'test_query_1', (query_id, items) ->
                  equals query_id, 'test_query_1'
                  equals items.length, 1
                  start()
              # Wait 500 ms and then post a message.
              window.setTimeout ->
                  createItem 'test_ctx', 'test_user', "foo2", -> # pass 
                  createItem 'test_ctx', 'test_user', "foo2", -> # pass 
                  createItem 'test_ctx', 'test_user', "foo2", -> # pass 
                , 500
              # Wait 2s and bail out
              window.setTimeout ->
                  ok false, 'bailing out'
                  start()
                , 2000
              
          
      
  
  
  ###
  asyncTest "Subscribe callback recieves query_ids and items.", ->
      results = []
      client = new togethr.live.LiveClient 'sid'
      client.bind 'ready', -> 
          setupQuery 'sid', 'qid', 'foo2', ->
              client.subscribe 'qid', (query_id, items) ->
                  console.log query_id, items, items.length, results.length
                  equals query_id, 'qid'
                  results.push item for item in items
              
              # Wait .2 second and then post a message.
              window.setTimeout ->
                  # Post 10 messages
                  for i in [1..10]
                    createItem 'test_ctx', 'test_user', "foo2 #{i}", -> # pass 
                , 1000
              
              # Wait 3 seconds and then check we recieved them.
              window.setTimeout ->
                  equals results.length, 10
                  start()
                , 3000
              
          
      
  
  ###
  #subscribe 'a', (event) ->
  #    console.log event
  #    ok event?
    
      
  
  

