// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

/* From, By, []To, []About, Aspect, Refs, Unpacked Value, Words in Message */

type Item struct { /* Parent: User */
	Created   int64 `json:"created"`
	Head      bool
	Index     []string
	Message   string `json:"msg"`
	Parent1   string
	Parent2   string
	Parent3   string
	Value     []byte
	ValueType int
	Version   int
	To        string `json:"to"`
	By        string `json:"by"`
}
