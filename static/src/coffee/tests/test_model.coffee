
$(document).ready ->
  
  tests_path = '/src/coffee/tests/'
  
  module 'mobone.model', teardown: -> window.localStorage.clear()
  
  asyncTest "Fetch a stored `LocalModel`.", ->
    
    class LM extends mobone.model.LocalModel
      storage_name: 'test'
    
    class LC extends mobone.model.LocalCollection
      storage_name: 'test'
      model: LM
    
    instance = new LM 
      id: 'a', 
      value: 'a'
    instance.save {},
      success: ->
        instance = new LM id: 'a'
        instance.fetch
          success: ->
            value = instance.get 'value'
            equal value, 'a'
    
    start()
    
  
  asyncTest "Stored `LocalModel` is fetched by `LocalCollection`.", ->
    
    class LM extends mobone.model.LocalModel
      storage_name: 'test'
    
    class LC extends mobone.model.LocalCollection
      storage_name: 'test'
      model: LM
    
    c = new LC
    m = new LM
      id: 'a'
      value: 'a'
    m.save {},
      success: ->
        c.fetch
          success: ->
            m = c.get 'a'
            equal m, undefined
    
    start()
    
  
  asyncTest "`LocalModel` tracks storage updates.", ->
    
    class LM extends mobone.model.LocalModel
      storage_name: 'test'
      track_changes: true
    
    instance = new LM
      id: 'a'
      value: 'foo'
    instance.save()
    
    $('body').append $ '<iframe id="test-storage-event-iframe"></iframe>'
    iframe = $ 'iframe#test-storage-event-iframe'
    iframe.attr 'src', "#{tests_path}html/test_model_update.html"
    iframe.load ->
      setTimeout ->
          value = instance.get 'value'
          equal value, 'iframe'
          iframe.remove()
        , 0
      start()
    
    
    
  
  asyncTest "`LocalCollection` tracks adds.", ->
    
    class LM extends mobone.model.LocalModel
      storage_name: 'test'
    
    
    class LC extends mobone.model.LocalCollection
      storage_name: 'test'
      track_changes: true
      model: LM
    
    
    collection = new LC
    
    $('body').append $ '<iframe id="test-storage-event-iframe"></iframe>'
    iframe = $ 'iframe#test-storage-event-iframe'
    iframe.attr 'src', "#{tests_path}html/test_collection_add.html"
    iframe.load ->
      setTimeout ->
          model = collection.get 'n'
          value = model.get 'value' if model?
          equal value, 'n'
          iframe.remove()
        , 0
      start()
    
    
  
  asyncTest "`LocalCollection` tracks removes.", ->
    
    class LM extends mobone.model.LocalModel
      storage_name: 'test'
    
    
    class LC extends mobone.model.LocalCollection
      storage_name: 'test'
      track_changes: true
      model: LM
    
    
    model = new LM id: 'n', value: 'n'
    model.save {},
      success: ->
        collection = new LC
        collection.fetch
          success: ->
            $('body').append $ '<iframe id="test-storage-event-iframe"></iframe>'
            iframe = $ 'iframe#test-storage-event-iframe'
            iframe.attr 'src', "#{tests_path}html/test_collection_remove.html"
            iframe.load ->
              setTimeout ->
                  model = collection.get 'n'
                  equal model, undefined
                  iframe.remove()
                , 0
              start()
            
          
        
      
    
    
  
  

