var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __indexOf = Array.prototype.indexOf || function(item) {
  for (var i = 0, l = this.length; i < l; i++) {
    if (this[i] === item) return i;
  }
  return -1;
};
(function($) {
  var Location, LocationView, location, location_button;
  Location = Backbone.Model.extend({
    _levels: ['neighborhood', 'sublocality', 'administrative_area_level_3', 'locality'],
    initialize: function() {
      if (!this.get("location")) {
        return this.getLocation();
      }
    },
    getLocation: function() {
      return $.geolocation.find(__bind(function(location) {
        return this.store(location, function() {
          return alert("no location: app must explode in balls of flame");
        });
      }, this));
    },
    store: function(location) {
      var geocoder, ll;
      geocoder = new google.maps.Geocoder;
      ll = new google.maps.LatLng(location.latitude, location.longitude);
      return geocoder.geocode({
        latLng: ll
      }, __bind(function(results, status) {
        var label;
        if (status === google.maps.GeocoderStatus.OK) {
          label = this._getLabel(results);
        } else {
          label = false;
        }
        return this._setLocation(location, label);
      }, this));
    },
    _getLabel: function(results) {
      var component, level, result, _i, _j, _k, _len, _len2, _len3, _ref, _ref2;
      _ref = this._levels;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        level = _ref[_i];
        for (_j = 0, _len2 = results.length; _j < _len2; _j++) {
          result = results[_j];
          _ref2 = result.address_components;
          for (_k = 0, _len3 = _ref2.length; _k < _len3; _k++) {
            component = _ref2[_k];
            if (__indexOf.call(component.types, level) >= 0) {
              return component.long_name;
            }
          }
        }
      }
      return false;
    },
    _setLocation: function(location, label) {
      this.set({
        location: location,
        label: label || ("" + location.latitude + "," + location.longitude)
      });
      return this.view.render();
    }
  });
  LocationView = Backbone.View.extend({
    el: $('#location-button'),
    events: {
      click: 'changeLocation'
    },
    initialize: function() {
      _.bindAll(this, 'render', 'changeLocation');
      this.model.bind('change', this.render);
      return this.model.view = this;
    },
    render: function() {
      $(this.el.text("+" + (this.model.get('label'))));
      return this;
    },
    changeLocation: function() {
      return alert('show set location dialog ...');
    }
  });
  location = new Location;
  return location_button = new LocationView({
    model: location
  });
})(jQuery);
