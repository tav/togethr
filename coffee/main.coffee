# Public Domain (-) 2011 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  doc = root.document
  doc.$ = doc.getElementById
  body = doc.body
  domly = exports.domly
  humane = exports.humane
  local = root.localStorage

  # Create the root #body container element.
  container = doc.createElement 'div'
  container.id = 'body'
  container.style.display = 'none'
  body.appendChild container

  $focus = null
  exports.focus = ->
    body.style.height = '100%'
    body.className = 'bg'
    container.style.display = 'block'
    $focus.focus()

  loginHidden = false

  handleLogin = (e) ->
    e.preventDefault()
    e.stopPropagation()
    if loginHidden
      loginHidden = false
      l = doc.$ 'login-table'
      l.style.display = 'table'
      $('#login-user').focus()
      return
    user = doc.$ 'login-user'
    humane.error('hello world')

  handlePersistLogin = () ->
    if this.checked
      local['login.persist'] = '1'
    else
      local.removeItem 'login.persist'

  hideLogin = () ->
    loginHidden = true
    l = doc.$ 'login-table'
    l.style.display = 'none'

  exports.showHomeScreen = showHomeScreen = () ->
    validated = false
    loginPrev = local['login.prev'] or ''
    checkbox = id: 'login-persist', onclick: handlePersistLogin, tabindex: 3, type: 'checkbox'
    if local['login.persist']
      checkbox.checked = 'checked'
    data = [
      'div', id: 'home',
        ['a', href: '/', id: 'togethr', 'togethr'],
        ['form', id: 'login', onsubmit: handleLogin,
          ['table', id: 'login-table',
            ['tr',
              ['td', ['label', for: 'login-user', 'Email']],
              ['td', ['label', for: 'login-pass', 'Passphrase']]
            ],
            ['tr',
              ['td', ['input', id: 'login-user', tabindex: 1, value: loginPrev]],
              ['td', ['input', id: 'login-pass', tabindex: 2, type: 'password']]
            ],
            ['tr', id: 'login-custom',
              ['td', ['input', checkbox], ['label', for: 'login-persist', id: 'login-persist-label', 'Keep me logged in']],
              ['td', ['input', id: 'login-submit', tabindex: 4, type: 'submit', value: 'Login!']],
            ]
          ],
          ['hr', class: 'clear']
        ],
        ['form', id: 'signup',
          ['div', id: 'signup-title', 'Sign up!'],
          ['input', id: 'signup-name', onfocus: hideLogin, placeholder: 'Full Name', tabindex: 10],
          ['div', 'boofheosifheoifsehoifs']
          ['input', id: 'signup-email', placeholder: 'Email', tabindex: 11],
          ['input', id: 'signup-pass', placeholder: 'Passphrase', tabindex: 12, type: 'password'],
          ['input', id: 'signup-nick', placeholder: 'Nickname', tabindex: 13],
          ['input', id: 'signup-number', placeholder: 'Togethr Number (Optional)', tabindex: 14],
        ],
    ]
    domly data, container
    $focus = doc.$ 'login-user'

  exports.run = (incr) ->

    incr()

    if local["auth"] isnt "1"
      showHomeScreen()
