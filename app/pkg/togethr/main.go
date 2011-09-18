// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

import (
	"fmt"
	"http"
)

func handle(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, "hello")
}

func init() {
	http.HandleFunc("/", handle)
}