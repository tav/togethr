// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package gaestore

import (
	"amp/model"
	ae "appengine"
	"appengine/datastore"
	"os"
)

type DB struct{}

func (db *DB) CreateItem(ctx ae.Context, item *model.Item, ref *string) (err os.Error) {
	key, err := datastore.Put(ctx, datastore.NewIncompleteKey("ZItem"), item)
	if err != nil {
		return
	}
	*ref = key.String()
	return
}
