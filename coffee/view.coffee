define 'togethr.view', (exports, root) ->
  
  tmpl = mobone.string.template
  
  valid_username = /^\w+$/
  
  # Namespaces wrapper around `window.localStorage`.
  class Storage
    _ns: (key) ->
      "#{@ns}.#{key}"
    
    set: (key, value) ->
      @storage.setItem @._ns(key), value
      
    
    get: (key) ->
      @storage.getItem @._ns(key)
      
    
    remove: (key) ->
      @storage.removeItem @._ns(key)
      
    
    constructor: (suffix) ->
      @ns = "at.togethr.#{suffix}"
      @storage = window.localStorage
      
    
  
  class SinglePageView extends Backbone.View
    
    chrome: tmpl '''
      <div class="strip">
        <ul class="login-logout">
          <li class="logged-in username">
          </li>
          <li class="logged-in">
            <a href="#" class="logout">
              Logout</a>
          </li>
          <li class="logged-out login-form-container">
            <form class="login">
              <input type="text" name="value" />
            </form>
          </li>
          <li class="logged-out login">
            <a href="#" class="login">
              Login</a>
          </li>
        </ul>
      </div>
      <div class="container">
        <form class="create">
          <h4>Create</h4>
          <input type="text" name="to" />
          <textarea name="msg"></textarea>
          <input type="submit" value="Create message" />
        </form>
        <form class="search">
          <h4>Search</h4>
          <input type="text" name="q" />
        </form>
        <ul class="results">
        </ul>
      </div>
    '''
    
    message: tmpl '''
      <li>
        <p>
          <span>
            To: <%~ to %>
          </span>
          <span>
            By: <%- by %>
          </span>
        </p>
        <p>
          Message: <%~ msg %>
        </p>
      </li>
    '''
    
    events: 
      'submit .create':         'handleCreate'
      'submit .search':         'handleSearch'
      'submit form.login':      'handleLogin'
      'click a.login':          'toggleLogin'
      'click a.logout':         'handleLogout'
    
    
    handleCreate: ->
      $form = @el.find 'form.create'
      qs = $form.serialize()
      qs = "#{qs}&username=#{encodeURIComponent(@storage.get 'username')}"
      $.getJSON '/create', qs, (response) ->
          if 'success' of response
            # pass
          else
            alert 'Yikes that didn\'t work'
          
        
      
      false
      
    
    handleSearch: ->
      $form = @el.find 'form.search'
      $.getJSON '/search', $form.serialize(), (response) ->
          if 'success' of response
            # pass
            console.log 'response.results'
            console.log response.results
          else
            alert 'Yikes that didn\'t work'
          
        
      
      false
      
    
    
    _doLogin: ->
      username = @storage.get 'username'
      @el.find('.login-logout li').hide()
      @el.find('.login-logout li.username').text username
      @el.find('.login-logout li.logged-in').show()
      
    
    handleLogin: ->
      value = @el.find('form.login input').val()
      candidate = $.trim(value).toLowerCase()
      if not valid_username.test candidate
        alert 'That\'s not a valid username.'
      else
        @storage.set 'username', candidate
        @_doLogin()
      false
      
    
    toggleLogin: ->
      $target = @el.find '.login-form-container'
      $target.toggle()
      false
      
    
    handleLogout: ->
      @storage.remove 'username'
      @el.find('.login-logout li').hide()
      @el.find('.login-logout li.username').text ''
      @el.find('.login-logout li.login').show()
      false
    
    
    initialize: ->
      @el.html @chrome()
      @storage = new Storage 'single-page-view'
      @el.find('.login-logout li').hide()
      if @storage.get 'username'
        @_doLogin() 
      else
        @el.find('.login-logout li.login').show()
      
    
  
  exports.SinglePageView = SinglePageView
  


