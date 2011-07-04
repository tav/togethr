// Public Domain (-) 2011 The Ampify Authors.
// See the Ampify UNLICENSE file for details.

package main

import (
	"amp/weblite"
)

func main() {

	app, opts := weblite.App("app-server", "0.1")

	facebookAppID := opts.StringConfig("facebook-app-id", "",
		"the facebook application ID")

	facebookSecret := opts.StringConfig("facebook-secret", "",
		"the facebook application secret key")

	app.ParseOpts()
	app.Register("/", Hello, "some-template", "site-template")
	app.Register("/api/query", Query).DisableXSRF()
	app.Register("/app/settings.save", SaveSettings, "settings-template").AuthOnly()

	app.Init(map[string]string{
		"FACEBOOK_APP_ID": *facebookAppID,
		"FACEBOOK_SECRET": *facebookSecret,
	})

}
