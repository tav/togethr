
$(document).ready ->
  
  module 'togethr.model'
  
  test "`Query.parse` parses into structured dict.", ->
    
    str = '@tav well #what a #lovely +day @to/go !running #would @you not !say'
    
    data = togethr.model.Query.parse str
    
    console.log data
    
    deepEqual data.hashtags, ['lovely', 'what', 'would']
    deepEqual data.badges, ['to/go']
    deepEqual data.users, ['tav', 'you']
    deepEqual data.actions, ['running', 'say']
    deepEqual data.spaces, ['day']
    deepEqual data.keywords, ['not', 'well']
    
  
  

