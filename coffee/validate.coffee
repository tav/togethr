# Public Domain (-) 2012 The Togethr Authors.
# See the Togethr UNLICENSE file for details.

define 'togethr', (exports, root) ->

  # Validate an email address according to the format specified by [RFC
  # 5322](http://www.ietf.org/rfc/rfc5322.txt). Deprecated formats like
  # `foo."@\ spam\\"@bar.com` are not supported.
  exports.isEmail = (addr) ->

    # [RFC 2821](http://www.ietf.org/rfc/rfc2821.txt) specifies a maximum
    # forward-path field limit of 256 bytes for SMTP. Including the `<`
    # delimiters `>`, this leaves 254 bytes for the actual email address.
    if addr.length is 0 or unescape(encodeURIComponent(addr)).length > 254
      return false

    at = addr.lastIndexOf '@'
    if at < 1 or at > 64
      return false

    host = addr.substring at+1
    return false if host.length is 0

    local = addr.substring 0, at
    for i in [0...at]
        cp = local.charCodeAt i
        if (cp >= 94 and cp <= 126) or (cp >= 65 and cp <= 90) or (cp >= 48 and cp <= 57) or cp is 43
          continue
        if cp is 46
          if i is 0
            return false
          if prev is 46 or i is (at-1)
            return false
          continue
        if cp is 33 or (cp >= 35 and cp <= 39) or cp is 42 or cp is 45 or cp is 47 or cp is 61 or cp is 63
          continue
        return false
        prev = cp

    return validateHost host

  exports.validateHost = validateHost = (host) ->

    l = host.length
    return false if l > 255

    return true

  return
