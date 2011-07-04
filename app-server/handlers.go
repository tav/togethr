// Public Domain (-) 2011 The Ampify Authors.
// See the Ampify UNLICENSE file for details.

package main

import (
	"amp/weblite"
)

func Hello(ctx *weblite.Context) (resp weblite.Response) {
	return "Hello world!"
}

func Query(ctx *weblite.Context) (resp weblite.Response) {
	return map[string]interface{}{
		"results":  5,
		"location": []string{"57.24967", "31.13108"},
	}
}

func SaveSettings(ctx *weblite.Context) (resp weblite.Response) {
	user := ctx.GetUser()
	return "Saved settings data for " + user
}
