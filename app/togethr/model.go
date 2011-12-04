// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

type Item struct { /* Parent: User */
	Created   int64    `json:"created"`
	Head      bool     `json:"-"`
	Index     []string `json:"-"` /* From, By, []To, []About, Aspect, Refs, Unpacked Value, Words in Message */
	Message   string   `json:"msg"`
	Parent1   string   `json:"-"`
	Parent2   string   `json:"-"`
	Parent3   string   `json:"-"`
	Value     []byte   `json:"-"`
	ValueType int      `json:"-"`
	Version   int      `json:"-"`
	To        string   `json:"to"`
	By        string   `json:"by"`
}
