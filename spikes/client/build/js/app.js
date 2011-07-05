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
        var e, f, g, h, i, j, k, l, m, n;
        n = Backbone.Model.extend({
            defaults: {
                is_authenticated: !1,
                is_admin: !1,
                username: "guest",
                displayName: "Guest User",
                profileImage: "..."
            }
        }), l = Backbone.Model.extend, d.User = n, d.Settings = l, i = Backbone.Model.extend({
            defaults: {
                lat: 0,
                lon: 0,
                bbox: [],
                label: ""
            },
            setToHere: function(c, d) {
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
        }), j = Backbone.Collection.extend({
            model: i
        }), d.Location = i, d.Locations = j, m = Backbone.Model.extend({
            defaults: {
                user: {},
                challenge: {},
                hashtags: [],
                keywords: []
            }
        }), k = Backbone.Model.extend({
            defaults: {
                from_user: {},
                from_location: {},
                to_location: {},
                to_space: {},
                on: "",
                actions: [],
                body: "",
                data: {}
            }
        }), g = Backbone.Model.extend({
            defaults: {
                from_user: {},
                from_location: {},
                to_message: {},
                on: "",
                message: "",
                data: {}
            }
        }), d.Space = m, d.Message = k, d.Comment = g, h = Backbone.Model.extend({
            defaults: {
                location: {},
                space: {}
            }
        }), d.Context = h, e = Backbone.Model.extend({
            defaults: {
                context: {},
                alias: ""
            }
        }), f = Backbone.Collection.extend({
            model: e
        }), d.Bookmark = e;
        return d.Bookmarks = f;
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
        var b, c, d, e, f, g, h, i, j, k, l, m, n;
        n = null, g = null, h = null, m = null, c = null, d = null, j = null, k = null, e = null, f = null, b = Backbone.Router.extend({
            routes: {
                "": "home",
                space: "space",
                "message/:msgid": "message",
                "dialog/location": "setLocation"
            },
            home: function() {},
            space: function() {},
            message: function() {},
            setLocation: function() {},
            initialize: function() {
                d = new view.ContextView({
                    model: c
                }), k = new view.MessageView({
                    model: j
                }), f = new view.DialogView({
                    model: e
                });
                return Backbone.history.start({
                    pushState: !0
                });
            }
        }), l = new b, i = function(a) {
            var b, c, d, e, f, i, k, l;
            n = new model.User((d = a.user) != null ? d : {}), h = new model.Location((e = a.location) != null ? e : {}), b = new model.Location((f = a.here) != null ? f : {}), m = new model.Space((i = a.space) != null ? i : {}), j = new model.Message((k = a.message) != null ? k : {}), c = new model.Messages((l = a.messages) != null ? l : []);
            return a.here ? g = b : b.setToHere(function() {
                return g = b;
            });
        }, a.router = l;
        return a.main = i;
    });
})(jQuery);