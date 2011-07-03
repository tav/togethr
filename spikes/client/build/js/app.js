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
        var e, f, g, h, i, j, k, l, m, n, o;
        o = Backbone.Model.extend({
            defaults: {
                is_authenticated: !1,
                is_admin: !1,
                username: "guest",
                displayName: "Guest User",
                profileImage: "..."
            }
        }), m = Backbone.Model.extend, d.User = o, d.Settings = m, k = Backbone.Model.extend({
            defaults: {
                lat: 0,
                lon: 0,
                bbox: [],
                label: "",
                level: ""
            },
            setToCurrent: function(c, d) {
                return a.geolocation.find(b(function(a) {
                    return this.store(a, c);
                }, this), d);
            },
            store: function(a, c) {
                var d, e;
                d = new google.maps.Geocoder, e = new google.maps.LatLng(a.latitude, a.longitude);
                return d.geocode({
                    latLng: e
                }, b(function(b, d) {
                    var e;
                    d === google.maps.GeocoderStatus.OK ? e = this._getLabel(b) : e = !1, this._setLocation(a, e);
                    return c();
                }, this));
            },
            _levels: [ "neighborhood", "sublocality", "administrative_area_level_3", "locality" ],
            _getLabel: function(a) {
                var b, d, e, f, g, h, i, j, k, l, m;
                l = this._levels;
                for (f = 0, i = l.length; f < i; f++) {
                    d = l[f];
                    for (g = 0, j = a.length; g < j; g++) {
                        e = a[g], m = e.address_components;
                        for (h = 0, k = m.length; h < k; h++) {
                            b = m[h];
                            if (c.call(b.types, d) >= 0) return b.long_name;
                        }
                    }
                }
                return !1;
            },
            _setLocation: function(a, b) {
                return this.set({
                    lat: a.latitude,
                    lon: a.longitude,
                    label: b || "" + a.latitude + "," + a.longitude
                });
            }
        }), l = Backbone.Collection.extend({
            model: k
        }), d.Location = k, d.Locations = l, n = Backbone.Model.extend({
            defaults: {
                user: {},
                challenge: {},
                hashtags: [],
                keywords: []
            }
        }), e = Backbone.Model.extend({
            defaults: {
                from_user: {},
                from_location: {},
                to_location: {},
                to_space: {},
                on: "",
                actions: [],
                message: "",
                data: {}
            }
        }), h = Backbone.Model.extend({
            defaults: {
                from_user: {},
                from_location: {},
                to_message: {},
                on: "",
                message: "",
                data: {}
            }
        }), d.Space = n, d.ActionMessage = e, d.Comment = h, i = Backbone.Model.extend({
            defaults: {
                location: {},
                space: {}
            }
        }), j = Backbone.Collection.extend({
            model: i
        }), d.Context = i, d.Contexts = j, f = Backbone.Model.extend({
            defaults: {
                context: {},
                alias: ""
            }
        }), g = Backbone.Collection.extend({
            model: f
        }), d.Bookmark = f;
        return d.Bookmarks = g;
    }), a.namespace("view", function(b) {
        return b.LocationButton = Backbone.View.extend({
            el: a("#location-button"),
            events: {
                click: "changeLocation"
            },
            initialize: function() {
                _.bindAll(this, "render", "changeLocation"), this.model.bind("change", this.render), this.model.view = this;
                return this.render();
            },
            render: function() {
                a(this.el.text("+" + this.model.get("label")));
                return this;
            },
            changeLocation: function() {
                return alert("show set location dialog ...");
            }
        });
    }), a.namespace("app", function(a) {
        var b, c, d, e, f, g, h;
        e = null, d = null, f = null, b = Backbone.Router.extend({
            routes: {
                "/": "home"
            },
            home: function() {},
            setLocation: function() {}
        }), h = new b, c = function() {
            f = new view.LocationButton({
                model: d
            });
            return Backbone.history.start({
                pushState: !0
            });
        }, g = function(a) {
            var b;
            e = new model.User((b = a.user) != null ? b : {}), d = new model.Location;
            if (a.location) {
                d.set(a.location);
                return c();
            }
            return d.setToCurrent(function() {
                return c();
            }, function() {
                return h.setLocation();
            });
        };
        return a.main = g;
    });
})(jQuery);