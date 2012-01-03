// Public Domain (-) 2011-2012 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

import (
	"json"
)

const ShardFactor = 2

type Item struct {
	// Core structure.
	About      string           `json:"about"`
	Aspect     string           `json:"aspect"`
	By         string           `json:"by"`
	Created    int64            `json:"created"`
	From       string           `json:"from"`
	FromGeo    string           `json:"from_geo"`
	Hidden     bool             `json:"hidden"`
	Message    string           `json:"msg"`
	MessageDOM *json.RawMessage `json:"msg_dom"`
	Meta       *json.RawMessage `json:"meta"`
	Parents    []string         `json:"parents"`
	To         []string         `json:"to"`
	Value      interface{}      `json:"value"`
	ValueType  int              `json:"value_type"`
	// Backend metadata.
	version int
}

func (item *Item) Version() int {
	return item.version
}
