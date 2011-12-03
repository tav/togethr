// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package togethr

import (
	"bytes"
)

type ArgoEncoder struct {
	b       *bytes.Buffer
	scratch []byte
}

func (enc *ArgoEncoder) WriteSize(val int) {
	i := 0
	for val >= 128 {
		enc.scratch[i] = byte(val) | 128
		val >>= 7
		i++
	}
	enc.scratch[i] = byte(val)
	enc.b.Write(enc.scratch[:i+1])
}

func (enc *ArgoEncoder) WriteString(val string) {
	enc.WriteSize(len(val))
	enc.b.Write([]byte(val))
}

func (enc *ArgoEncoder) WriteStringSlice(val []string) {
	enc.WriteSize(len(val))
	for _, elem := range val {
		enc.WriteSize(len(elem))
		enc.b.Write([]byte(elem))
	}
}
