// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package gaestore

import (
	"appengine"
	"bytes"
	"crypto/subtle"
	"fmt"
	"gob"
	"http"
	"io"
	"rpc"
)

var rpcServer = rpc.NewServer()

func handleRequest(w http.ResponseWriter, r *http.Request) {

	// Provide an informative message for all non-POST requests, e.g. GETs.
	if r.Method != "POST" {
		fmt.Fprint(w, "Welcome to the Datastore API endpoint.")
		return
	}

	// Ensure that the shared secret key is provided as a query param, i.e.
	// ?key= and that it matches.
	params := r.URL.Query()
	keys, ok := params["key"]
	if !ok {
		w.WriteHeader(401)
		return
	}
	key := []byte(keys[0])
	if len(key) != len(secret) {
		w.WriteHeader(401)
		return
	}
	if subtle.ConstantTimeCompare(key, secret) != 1 {
		w.WriteHeader(401)
		return
	}

	// Handle the request body as an RPC request.
	buf := &bytes.Buffer{}
	codec := &rpc.GobServerCodec{r.Body, gob.NewDecoder(r.Body), gob.NewEncoder(buf)}
	rpcServer.ServeRequest(codec, appengine.NewContext(r))

	// Write the response out to the underlying HTTP response.
	io.Copy(w, buf)

}

func init() {
	rpcServer.RegisterName("db", &DB{})
	http.HandleFunc("/", handleRequest)
}
