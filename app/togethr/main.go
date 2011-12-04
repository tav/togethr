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
	"strings"
	"time"
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

func handle(w http.ResponseWriter, r *http.Request) {
	fmt.Fprint(w, chrome)
}

func create(w http.ResponseWriter, r *http.Request) {

	by := r.FormValue("by")
	toRaw := r.FormValue("to")
	to := strings.Split(strings.ToLower(toRaw), " ")
	msg := r.FormValue("msg")

	words := strings.Split(strings.ToLower(msg), " ")
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
		// http.Error(w, err.String(), http.StatusInternalServerError)
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

	q := strings.Split(strings.ToLower(r.FormValue("q")), " ")
	index := make(map[string]bool)
	sqid := r.FormValue("sqid")

	for _, term := range q {
		if strings.HasPrefix(term, "by:") {
			term = BY_HEADER + term[3:]
		} else if strings.HasPrefix(term, "to:") {
			term = TO_HEADER + term[3:]
		} else {
			term = WORD_HEADER + term
		}
		if len(term) > 1 {
			index[term] = true
		}
	}

	ctx := appengine.NewContext(r)
	query := datastore.NewQuery("M999")
	for _, term := range index {
		query.Filter("Index =", term)
	}
	query.Order("-Created")
	results := make([]*Item, 0)

	for iterator := query.Run(ctx); ; {
		var item *Item
		_, err := iterator.Next(item)
		if err == datastore.Done {
			break
		}
		if err != nil {
			fmt.Fprint(w, `{"failure": true}`)
			return
		}
		results = append(results, item)
	}

	buf := &bytes.Buffer{}
	enc := ArgoEncoder{buf, make([]byte, 11)}

	buf.Write(SUBSCRIBE)
	enc.WriteString(sqid)

	realIndex := make([]string, len(index))
	i := 0
	for term := range index {
		realIndex[i] = term
		i++
	}
	enc.WriteStringSlice(realIndex)

	// fmt.Fprintf(w, "%d", buf.Len())
	// return
	w.Header().Set("X-Live", fmt.Sprintf("%d", buf.Len()))

	jenc := json.NewEncoder(buf)
	jenc.Encode(map[string][]*Item{"success": results})

	io.Copy(w, buf)

}

func init() {
	http.DefaultServeMux.Handle("/", http.HandlerFunc(handle))
	http.HandleFunc("/create", create)
	http.HandleFunc("/search", search)
}
