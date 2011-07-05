(function(a) {
    var b = function(a, b) {
        return function() {
            return a.apply(b, arguments);
        };
    };
    a.namespace("app", function(c) {
        var d;
        d = function() {
            function c(c) {
                var d, e, f, g;
                this.user = new user.User((e = c.user) != null ? e : {}), this.query = new query.Query((f = c.query) != null ? f : {}), this.location = new loc.Location((g = c.location) != null ? g : {
                    bbox: [ "1", "2", "3", "4" ]
                }), d = a("div"), d.live("pagecreate", b(function(a) {
                    return this.create(a, a.target);
                }, this)), d.live("pagebeforeshow", b(function(a, b) {
                    return this.startup(a, a.target, b.prevPage);
                }, this)), d.live("pagebeforehide", b(function(a, b) {
                    return this.shutdown(a, a.target, b.nextPage);
                }, this)), d.live("pageshow", b(function(a, b) {
                    return this.show(a, a.target, b.prevPage);
                }, this)), d.live("pagehide", b(function(a, b) {
                    return this.hide(a, a.target, b.nextPage);
                }, this));
            }
            c.prototype.create = function(a, b) {
                console.log("create", b.id);
                switch (b.id) {
                  case "query":
                    return this.queryView = new query.QueryPage({
                        el: b,
                        query: this.query,
                        location: this.location
                    });
                }
            }, c.prototype.startup = function(b, c, d) {
                var e, f;
                console.log("startup", c.id);
                switch (c.id) {
                  case "query":
                    e = (f = a.parseQuery().q) != null ? f : "XXX", this.query.set({
                        value: e
                    });
                    return console.log("set q to ", e);
                }
            }, c.prototype.shutdown = function(a, b, c) {
                return console.log("shutdown", b.id);
            }, c.prototype.show = function(a, b, c) {
                return console.log("show", b.id);
            }, c.prototype.hide = function(a, b, c) {
                return console.log("hide", b.id);
            };
            return c;
        }();
        return c.Controller = d;
    });
    var c = Object.prototype.hasOwnProperty, d = function(a, b) {
        function e() {
            this.constructor = a;
        }
        for (var d in b) c.call(b, d) && (a[d] = b[d]);
        e.prototype = b.prototype, a.prototype = new e, a.__super__ = b.prototype;
        return a;
    };
    a.namespace("loc", function(b) {
        var c, e;
        c = function() {
            function a() {
                a.__super__.constructor.apply(this, arguments);
            }
            d(a, Backbone.Model);
            return a;
        }(), e = function() {
            function b() {
                b.__super__.constructor.apply(this, arguments);
            }
            d(b, Backbone.View), b.prototype.events = {
                click: "changeLocation"
            }, b.prototype.initialize = function() {
                _.bindAll(this, "render", "changeLocation"), this.model.bind("change", this.render), this.model.view = this;
                return this.render();
            }, b.prototype.render = function() {
                return a(this.el.text("+" + this.model.get("label")));
            }, b.prototype.changeLocation = function() {
                a.mobile.changePage("#location");
                return !1;
            };
            return b;
        }(), b.Location = c;
        return b.LocationView = e;
    });
    var c = Object.prototype.hasOwnProperty, d = function(a, b) {
        function e() {
            this.constructor = a;
        }
        for (var d in b) c.call(b, d) && (a[d] = b[d]);
        e.prototype = b.prototype, a.prototype = new e, a.__super__ = b.prototype;
        return a;
    };
    a.namespace("message", function(b) {
        var c, e, f, g;
        g = {
            messageEntry: _.template('<a href="#messages/<%= id %>">\n  <%= content %>\n</a>'),
            messagePage: _.template('<div data-role="page" id="message/<%= id %>" data-add-back-btn="true">\n  <div data-role="header" data-position="inline">\n    <h1>Message</h1>\n  </div>\n  <div data-role="content">  \n    <p>Message</p>\n    <p>\n      <%= content %>\n    </p>\n  </div>\n  <div data-role="footer">\n    <h4>Page Footer</h4>\n  </div>\n</div>')
        }, c = function() {
            function a() {
                a.__super__.constructor.apply(this, arguments);
            }
            d(a, Backbone.Model);
            return a;
        }(), e = function() {
            function b() {
                b.__super__.constructor.apply(this, arguments);
            }
            d(b, Backbone.View), b.prototype.className = "message-entry", b.prototype.events = {
                "click a": "createPage"
            }, b.prototype.initialize = function() {
                _.bindAll(this, "render", "createPage"), this.model.bind("change", this.render);
                return this.render();
            }, b.prototype.render = function() {
                return a(this.el).html(g.messageEntry({
                    id: this.model.id,
                    content: this.model.get("content")
                }));
            }, b.prototype.createPage = function() {
                var b, c;
                b = new f({
                    model: this.model
                }), c = b.$("div").first(), c.appendTo(a.mobile.pageContainer).page(), c.jqmData("url", "" + c.attr("id")), a.mobile.changePage(c);
                return !1;
            };
            return b;
        }(), f = function() {
            function b() {
                b.__super__.constructor.apply(this, arguments);
            }
            d(b, Backbone.View), b.prototype.className = "message-page", b.prototype.initialize = function() {
                _.bindAll(this, "render"), this.model.bind("change", this.render);
                return this.render();
            }, b.prototype.render = function() {
                return a(this.el).html(g.messagePage({
                    id: this.model.id,
                    content: this.model.get("content")
                }));
            };
            return b;
        }(), b.Message = c, b.MessageEntry = e;
        return b.MessagePage = f;
    });
    var c = Object.prototype.hasOwnProperty, d = function(a, b) {
        function e() {
            this.constructor = a;
        }
        for (var d in b) c.call(b, d) && (a[d] = b[d]);
        e.prototype = b.prototype, a.prototype = new e, a.__super__ = b.prototype;
        return a;
    };
    a.namespace("query", function(b) {
        var c, e, f;
        f = {
            titleBar: _.template('<div data-role="toolbar" data-position="inline">\n  <a href="#" data-rel="back"></a>\n  <h1><%= title %></h1>\n</div>')
        }, c = function() {
            function a() {
                a.__super__.constructor.apply(this, arguments);
            }
            d(a, Backbone.Model);
            return a;
        }(), e = function() {
            function b() {
                b.__super__.constructor.apply(this, arguments);
            }
            d(b, Backbone.View), b.prototype.initialize = function() {
                _.bindAll(this, "render"), this.query = this.options.query, this.location = this.options.location, this.query.bind("change", this.render), this.location.bind("change", this.render);
                return this.locationView = new loc.LocationView({
                    el: a("#location-button"),
                    model: this.location
                });
            }, b.prototype.render = function() {
                var a, b, c, d, e, g, h, i, j, k;
                if (this.location.has("bbox")) {
                    d = [ {
                        id: "msg-1",
                        content: "message 1"
                    }, {
                        id: "msg-2",
                        content: "message 2"
                    } ], e = this.query.get("value"), g = this.$(".title-bar"), e ? (g.html(f.titleBar({
                        title: e
                    })), g.trigger("enhance"), g.show()) : g.hide(), c = this.$(".main-window"), c.html(""), k = [];
                    for (i = 0, j = d.length; i < j; i++) a = d[i], b = new message.Message(a), h = new message.MessageEntry({
                        model: b
                    }), c.append(h.el), k.push(c.trigger("enhance"));
                    return k;
                }
                return console.log("missing query or location");
            };
            return b;
        }(), b.Query = c;
        return b.QueryPage = e;
    });
    var c = Object.prototype.hasOwnProperty, d = function(a, b) {
        function e() {
            this.constructor = a;
        }
        for (var d in b) c.call(b, d) && (a[d] = b[d]);
        e.prototype = b.prototype, a.prototype = new e, a.__super__ = b.prototype;
        return a;
    };
    a.namespace("user", function(a) {
        var b;
        b = function() {
            function a() {
                a.__super__.constructor.apply(this, arguments);
            }
            d(a, Backbone.Model);
            return a;
        }();
        return a.User = b;
    });
})(jQuery);