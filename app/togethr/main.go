// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

import (
	"http"
	"togethr/backend"
	"togethr/rpc"
)

func render(c []byte, w http.ResponseWriter) {
	w.Header().Set("X-Frame-Options", "SAMEORIGIN")
	w.Header().Set("X-XSS-Protection", "0")
	w.Write(c)
}

func handle(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Path
	// Fast path the root request.
	if path == "/" {
		render(chromeBytes, w)
		return
	}
	switch path[1] {
	case '.':
		switch path {
		case "/.rpc":
			rpc.Handle(path, w, r)
		case "/.test":
			render(testChromeBytes, w)
		default:
			rpc.HandleStream(path[2:], w, r)
		}
	case '_':
		switch path {
		case "/_ah/start":
			backend.Start(w, r)
		case "/_ah/stop":
			backend.Stop(w, r)
		default:
			http.NotFound(w, r)
		}
	default:
		render(chromeBytes, w)
	}
}

func init() {
	http.DefaultServeMux.Handle("/", http.HandlerFunc(handle))
}
