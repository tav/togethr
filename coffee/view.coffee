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


    get_or_create: (key, defaultFactory) ->
      value = @get key
      if not value?
        value = defaultFactory()
        @set key, value
      value


    remove: (key) ->
      @storage.removeItem @._ns(key)


    constructor: (suffix) ->
      @ns = "at.togethr.#{suffix}"
      @storage = window.localStorage



  # As above for `window.sessionStorage`.
  class Session extends Storage
    constructor: (suffix) ->
      super suffix
      @storage = window.sessionStorage

  class LoginBar extends Backbone.View
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
    '''

    events:
      'submit form.login':      'handleLogin'
      'click a.login':          'toggleLogin'
      'click a.logout':         'handleLogout'

    _doLogin: ->
      username = @storage.get 'username'
      @$('.login-logout li').hide()
      @$('.login-logout li.username').text username
      @$('.login-logout li.logged-in').show()


    handleLogin: ->
      value = @$('form.login input').val()
      candidate = $.trim(value).toLowerCase()
      if not valid_username.test candidate
        alert 'That\'s not a valid username.'
      else
        @storage.set 'username', candidate
        @_doLogin()
      false


    toggleLogin: ->
      $target = @$ '.login-form-container'
      $target.toggle()
      false


    handleLogout: ->
      @storage.remove 'username'
      @$('.login-logout li').hide()
      @$('.login-logout li.username').text ''
      @$('.login-logout li.login').show()
      false

    initialize: ->
      @el.append @chrome()
      @storage = new Storage 'single-page-view'
      @$('.login-logout li').hide()
      if @storage.get 'username'
        @_doLogin()
      else
        @$('.login-logout li.login').show()



  class ContainerView extends Backbone.View

    chrome: tmpl '''
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
      <li data-created="<%- created %>">
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


    _getSQID: ->
      session_id = @session.get_or_create 'sid', -> mobone.math.uuid()
      query_id = mobone.math.uuid()
      @sqid = "#{session_id}:#{query_id}"
      @sqid


    handleCreate: ->
      $form = @$ 'form.create'
      if not @storage.get 'username'
        alert 'You must be logged in to create a message'
      else
        qs = $form.serialize()
        qs = "#{qs}&by=#{encodeURIComponent(@storage.get 'username')}"
        $.getJSON '/create', qs, (response) ->
            if 'success' of response
              $form.get(0).reset()
            else
              alert 'Yikes that didn\'t work'



      false


    handleSearch: ->
      $form = @$ 'form.search'
      sqid = @_getSQID()
      qs = $form.serialize()
      $.getJSON '/search', "#{qs}&sqid=#{sqid}", (response) =>
          console.log response
          if 'success' of response
            @results.html ''
            $.each response.results, (i, result) =>
                @results.prepend @message result
          else
            alert 'Yikes that didn\'t work'



      false


    initialize: ->
      @el.append @chrome()
      @results = @$ 'ul.results'
      @storage = new Storage 'single-page-view'
      @session = new Session 'session'


  class SinglePageView extends Backbone.View

    initialize: ->
      @login_bar = new LoginBar el: @el
      @container_view = new ContainerView el: @el


  exports.SinglePageView = SinglePageView
