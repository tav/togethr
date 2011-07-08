/*
  
  a)  http://stackoverflow.com/questions/973875/jquery-check-if-browser-support-position-fixed
  b)  run it after 20ms, as per jquery mobile's silent scroll, otherwise it 
      returns a false positive in mobile safari
  c)  provides the option to set a default scrollTop
  
*/
(function($) {
  $.support.fixedPosition = function (callback, endScrollTop) {
    setTimeout(
      function () {
        var container = document.body;
        if (document.createElement && container && container.appendChild && container.removeChild) {
          var el = document.createElement('div');
          if (!el.getBoundingClientRect) return null;
          el.innerHTML = 'x';
          el.style.cssText = 'position:fixed;top:1px;';
          container.appendChild(el);
          var originalHeight = container.style.height,
              originalScrollTop = container.scrollTop;
          container.style.height = '3000px';
          container.scrollTop = 2;
          var elementTop = el.getBoundingClientRect().top;
          var isSupported = !!(elementTop === 1);
          container.style.height = originalHeight;
          container.removeChild(el);
          if (typeof endScrollTop !== "undefined" && endScrollTop !== null) {
            container.scrollTop = endScrollTop;
          } 
          else {
            container.scrollTop = originalScrollTop;
          }
          callback(isSupported);
        }
        else {
          callback(null);
        }
      }, 
      20
    );
  }
})(jQuery);
