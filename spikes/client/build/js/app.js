(function(a) {
    var b = function(a, b) {
        return function() {
            return a.apply(b, arguments);
        };
    }, c = Array.prototype.indexOf || function(a) {
        for (var b = 0, c = this.length; b < c; b++) if (this[b] === a) return b;
        return -1;
    };
    a.namespace("model", function(d) {
        var e;
        e = [ "neighborhood", "sublocality", "administrative_area_level_3", "locality" ], d.Location = Backbone.Model.extend({
            initialize: function() {
                if (!this.get("location")) return this.getLocation();
            },
            getLocation: function() {
                return a.geolocation.find(b(function(a) {
                    return this.store(a, function() {
                        return alert("no location: app must explode in balls of flame");
                    });
                }, this));
            },
            store: function(a) {
                var c, d;
                c = new google.maps.Geocoder, d = new google.maps.LatLng(a.latitude, a.longitude);
                return c.geocode({
                    latLng: d
                }, b(function(b, c) {
                    var d;
                    c === google.maps.GeocoderStatus.OK ? d = this._getLabel(b) : d = !1;
                    return this._setLocation(a, d);
                }, this));
            },
            _getLabel: function(a) {
                var b, d, f, g, h, i, j, k, l, m;
                for (g = 0, j = e.length; g < j; g++) {
                    d = e[g];
                    for (h = 0, k = a.length; h < k; h++) {
                        f = a[h], m = f.address_components;
                        for (i = 0, l = m.length; i < l; i++) {
                            b = m[i];
                            if (c.call(b.types, d) >= 0) return b.long_name;
                        }
                    }
                }
                return !1;
            },
            _setLocation: function(a, b) {
                this.set({
                    location: a,
                    label: b || "" + a.latitude + "," + a.longitude
                });
                return this.view.render();
            }
        });
        return d.Search = Backbone.Model.extend({});
    }), a.namespace("view", function(b) {
        return b.LocationButton = Backbone.View.extend({
            el: a("#location-button"),
            events: {
                click: "changeLocation"
            },
            initialize: function() {
                _.bindAll(this, "render", "changeLocation"), this.model.bind("change", this.render);
                return this.model.view = this;
            },
            render: function() {
                a(this.el.text("+" + this.model.get("label")));
                return this;
            },
            changeLocation: function() {
                return alert("show set location dialog ...");
            }
        });
    }), a.namespace("route", function(a) {});
    var d, e;
    d = new model.Location, e = new view.LocationButton({
        model: d
    });
})(jQuery);