# Public Domain (-) 2012 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  # Validate an email address according to the format specified by [RFC
  # 5322](http://www.ietf.org/rfc/rfc5322.txt). Deprecated formats like
  # `foobar."@\ spam\\"@baz.com` are not supported. Returns `0` if it's
  # definitely not an email address, `1` if it definitely is and `2` if it may
  # be one.
  exports.isEmail = (addr) ->

    # [RFC 2821](http://www.ietf.org/rfc/rfc2821.txt) specifies a maximum
    # forward-path field limit of 256 bytes for SMTP. Including the `<`
    # delimiters `>`, this leaves 254 bytes for the actual email address.
    if addr.length is 0 or unescape(encodeURIComponent(addr)).length > 254
      return 0

    at = addr.lastIndexOf '@'
    if at < 1 or at > 64
      return 0

    host = addr.substring at+1
    return 0 if host.length is 0

    local = addr.substring 0, at
    for i in [0...at]
        cp = local.charCodeAt i
        if (cp >= 94 and cp <= 126) or (cp >= 65 and cp <= 90) or (cp >= 48 and cp <= 57) or cp is 43
          continue
        if cp is 46
          if i is 0
            return 0
          if prev is 46 or i is (at-1)
            return 0
          continue
        if cp is 33 or (cp >= 35 and cp <= 39) or cp is 42 or cp is 45 or cp is 47 or cp is 61 or cp is 63
          continue
        if cp > 126
          return 0
        return 2
        prev = cp

    return validateHost host

  exports.validateHost = validateHost = (host) ->

    l = host.length
    return 0 if l > 255

    return 1

  return
