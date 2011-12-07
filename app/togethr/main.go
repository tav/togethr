// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

import (
	"appengine"
	"appengine/datastore"
	"bytes"
	"fmt"
	"http"
	"io"
	"json"
	"os"
	"strings"
	"time"
	"togethr/rpc"
)

const (
	BY_HEADER   = "by:"
	TO_HEADER   = "to:"
	WORD_HEADER = "wd:"
)

var (
	PUBLISH   = []byte{0}
	SUBSCRIBE = []byte{1}
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
			if strings.HasPrefix(path, "/.get/") {
				rpc.HandleGet(path[6:], w, r)
			} else {
				http.NotFound(w, r)
			}
		}
	case '_':
		switch path {
		case "/_ah/start":
			startBackend(w, r)
		case "/_ah/stop":
			stopBackend(w, r)
		default:
			http.NotFound(w, r)
		}
	default:
		render(chromeBytes, w)
	}
}

func create(w http.ResponseWriter, r *http.Request) {

	by := r.FormValue("by")
	toRaw := r.FormValue("to")
	to := strings.Split(strings.TrimSpace(strings.ToLower(toRaw)), " ")
	msg := r.FormValue("msg")

	words := strings.Split(strings.TrimSpace(strings.ToLower(msg)), " ")
	index := make([]string, len(to)+len(words)+1)

	i := 1
	for _, val := range to {
		if len(val) != 0 {
			index[i] = TO_HEADER + val
			i++
		}
	}
	for _, val := range words {
		if len(val) != 0 {
			index[i] = WORD_HEADER + val
			i++
		}
	}
	index[0] = BY_HEADER + by

	item := &Item{
		By:      by,
		Created: time.Nanoseconds(),
		Index:   index[:i],
		Message: msg,
		To:      toRaw,
	}

	ctx := appengine.NewContext(r)
	key, err := datastore.Put(ctx, datastore.NewIncompleteKey(ctx, "M999", nil), item)
	if err != nil {
		fmt.Fprint(w, `{"failure": true}`)
		return
	}

	buf := &bytes.Buffer{}
	enc := ArgoEncoder{buf, make([]byte, 11)}

	buf.Write(PUBLISH)
	enc.WriteString(key.String())
	enc.WriteStringSlice(item.Index)

	w.Header().Set("X-Live", fmt.Sprintf("%d", buf.Len()))
	w.Write(buf.Bytes())

	fmt.Fprintf(w, `{"success": "%s"}`, key.String())

}

func search(w http.ResponseWriter, r *http.Request) {

	ctx := appengine.NewContext(r)
	q := strings.Split(strings.ToLower(r.FormValue("q")), " ")
	terms := make([]string, len(q))
	sqid := r.FormValue("sqid")

	i := 0
buildTerms:
	for _, term := range q {
		if strings.HasPrefix(term, "by:") {
			term = BY_HEADER + term[3:]
		} else if strings.HasPrefix(term, "to:") {
			term = TO_HEADER + term[3:]
		} else {
			term = WORD_HEADER + term
		}
		for j := 0; j <= i; j++ {
			if terms[j] == term {
				continue buildTerms
			}
		}
		terms[i] = term
		i++
	}

	var err os.Error
	results := make([]Item, 0)

	by := r.FormValue("by")
	if len(by) == 0 {
		results, err = getResults(ctx, terms, by, results)
	} else {
		users := strings.Split(by, ",")
		for i := 0; i < len(users); i++ {
			results, err = getResults(ctx, terms, users[i], results)
			if err != nil {
				break
			}
		}
	}

	if err != nil {
		fmt.Fprint(w, `{"failure": true}`)
		return
	}

	buf := &bytes.Buffer{}
	enc := ArgoEncoder{buf, make([]byte, 11)}

	buf.Write(SUBSCRIBE)
	enc.WriteString(sqid)
	enc.WriteStringSlice(terms)

	w.Header().Set("X-Live", fmt.Sprintf("%d", buf.Len()))

	jenc := json.NewEncoder(buf)
	jenc.Encode(map[string]interface{}{"success": true, "results": results})

	io.Copy(w, buf)

}

func getResults(ctx appengine.Context, terms []string, by string, results []Item) ([]Item, os.Error) {
	query := datastore.NewQuery("M999")
	for i := 0; i < len(terms); i++ {
		query.Filter("Index =", terms[i])
	}
	if len(by) != 0 {
		query.Filter("Index =", BY_HEADER+by)
	}
	query.Order("-Created")
	for iterator := query.Run(ctx); ; {
		var item Item
		_, err := iterator.Next(&item)
		if err == datastore.Done {
			break
		}
		if err != nil {
			return nil, err
		}
		results = append(results, item)
	}
	return results, nil
}

func init() {
	http.DefaultServeMux.Handle("/", http.HandlerFunc(handle))
	http.HandleFunc("/create", create)
	http.HandleFunc("/search", search)
}
