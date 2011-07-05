(function($){
    var __slice = Array.prototype.slice;
    $.namespace = function(target, name, block) {
      var item, top, _i, _len, _ref, _ref2;
      if (arguments.length < 3) {
        _ref = [(typeof exports !== 'undefined' ? exports : window)].concat(__slice.call(arguments)), target = _ref[0], name = _ref[1], block = _ref[2];
      }
      top = target;
      _ref2 = name.split('.');
      for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
        item = _ref2[_i];
        target = target[item] || (target[item] = {});
      }
      return block(target, top);
    };
  }
)(jQuery);