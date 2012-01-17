// Public Domain (-) 2011-2012 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package model

type Item struct {
	// Core structure.
	About      string      `json:"about"`
	Aspect     string      `json:"aspect"`
	By         string      `json:"by"`
	ByTime     int64       `json:"by_time"`
	Created    int64       `json:"created"`
	From       string      `json:"from"`
	FromGeo    string      `json:"from_geo"`
	Hidden     bool        `json:"hidden"`
	Language   string      `json:"lang"`
	Message    string      `json:"msg"`
	MessageDOM string      `json:"msg_dom"`
	Meta       string      `json:"meta"`
	Parents    []string    `json:"parents"` /* history | reply | via | source */
	To         []string    `json:"to"`
	Value      interface{} `json:"value"`
	ValueType  int         `json:"value_type"`
	// Backend metadata.
	Index   [][]byte `json:"-"`
	Status  []string `json:"-"` /* break-top40 */
	Version int      `json:"-"`
}

// func (item *Item) Load(c <-chan Property) os.Error {
// 	return item.version
// }

// func (item *Item) Save(c chan<- Property) os.Error {
// 	return item.version
// }

type ItemContent struct {
	// Core structure.
	Content string `json:"content"`
	Title   string `json:"title"`
	Type    string `json:"type"`
	// Backend metadata.
	Version int
}

type Transcoding struct {
	// Core structure.
	Error   string `json:"error"`
	Status  int    `json:"status"`
	Path    string `json:"path"`
	Type    string `json:"type"`
	Updated int64  `json:"updated"`
	// Backend metadata.
	Version int
}
