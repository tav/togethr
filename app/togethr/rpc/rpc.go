// Public Domain (-) 2011 The Togethr Authors.
// See the Togethr UNLICENSE file for details.

package rpc

import (
	"bytes"
	"fmt"
	"http"
	"io/ioutil"
	"json"
	"reflect"
	"sync"
)

var (
	ctxType = reflect.TypeOf(&Context{})
	free    *Context
	mutex   sync.Mutex
)

type Header map[string]interface{}

type Context struct {
	Header     Header
	RespHeader Header
	buf        *bytes.Buffer
	enc        *json.Encoder
	meth       string
	next       *Context
	r          *http.Request
	req        *request
}

func (ctx *Context) Redirect(location string) {
	panic(redirect(location))
}

func (ctx *Context) Error(format string, a ...interface{}) {
	panic(fmt.Errorf(format, a...))
}

func getContext() *Context {
	mutex.Lock()
	ctx := free
	if ctx == nil {
		mutex.Unlock()
		ctx = &Context{}
		ctx.buf = &bytes.Buffer{}
		ctx.enc = json.NewEncoder(ctx.buf)
		ctx.req = &request{}
	} else {
		free = ctx.next
		mutex.Unlock()
		ctx.buf.Reset()
		*ctx.req = request{}
	}
	*ctx.req = request{}
	return ctx
}

func freeContext(ctx *Context) {
	mutex.Lock()
	ctx.next = free
	free = ctx
	mutex.Unlock()
}

type service struct {
	args   []reflect.Type
	in     int
	meth   reflect.Value
	stream bool
}

func (s *service) Anon() *service {
	return s
}

type redirect string

type request struct {
	Header Header             `json:"header"`
	Call   []*json.RawMessage `json:"call"`
}

type response struct {
	Header Header        `json:"header"`
	Reply  []interface{} `json:"reply"`
}

var (
	errOpen = []byte(`{"error":`)
	errEnc  = []byte(`"runtime error: couldn't encode JSON response"`)
	errEnd  = []byte(`}`)
)

func Error(format string, a ...interface{}) {
	panic(fmt.Errorf(format, a...))
}

func HandleStream(path string, w http.ResponseWriter, r *http.Request) {
}

func Handle(path string, w http.ResponseWriter, r *http.Request) {

	var (
		ctx  *Context
		resp []byte
	)

	defer func() {
		if ctx != nil {
			freeContext(ctx)
		}
		if e := recover(); e != nil {
			if redir, yes := e.(redirect); yes {
				http.Redirect(w, r, string(redir), http.StatusFound)
				return
			}
			msg, err := json.Marshal(fmt.Sprint(e))
			if err != nil {
				msg = errEnc
			}
			w.Write(errOpen)
			w.Write(msg)
			w.Write(errEnd)
		} else {
			w.Write(resp)
		}
	}()

	if r.Method != "POST" {
		Error("bad request: required POST, received %s", r.Method)
	}

	body, err := ioutil.ReadAll(r.Body)
	r.Body.Close()
	if err != nil {
		panic(err)
	}

	body = []byte(`{"header": {"user": "tav"}, "call": ["test.spam", "hello", 5]}`)

	ctx = getContext()
	if json.Unmarshal(body, ctx.req) != nil {
		panic("bad request: error parsing JSON request")
	}

	call := ctx.req.Call
	if call == nil {
		panic("bad request: missing 'call' parameter")
	}

	if json.Unmarshal(*call[0], &ctx.meth) != nil {
		panic("bad request: first element of 'call' needs to be a string")
	}

	s, exists := services[ctx.meth]
	if !exists {
		Error("service not found: %s", ctx.meth)
	}

	call = call[1:]
	if s.in != len(call) {
		Error("bad request: %s takes %d arguments, got %d", ctx.meth, s.in, len(call))
	}

	args := make([]reflect.Value, s.in+1)
	for i, req := range call {
		var rv reflect.Value
		typ := s.args[i]
		ptr := typ.Kind() == reflect.Ptr
		if ptr {
			rv = reflect.New(typ.Elem())
		} else {
			rv = reflect.New(typ)
		}
		if err = json.Unmarshal(*req, rv.Interface()); err != nil {
			panic("bad request: " + err.String())
		}
		if !ptr {
			rv = rv.Elem()
		}
		args[i+1] = rv
	}

	ctx.Header = ctx.req.Header
	ctx.RespHeader = make(Header)

	args[0] = reflect.ValueOf(ctx)
	rargs := s.meth.Call(args)

	res := &response{ctx.RespHeader, make([]interface{}, len(rargs))}
	for i, arg := range rargs {
		res.Reply[i] = arg.Interface()
	}

	if err = ctx.enc.Encode(res); err != nil {
		panic(err)
	}

	resp = ctx.buf.Bytes()

}

var services = map[string]*service{}

func register(name string, v interface{}, stream bool) *service {
	rv := reflect.ValueOf(v)
	rt := rv.Type()
	if rt.Kind() != reflect.Func {
		panic("rpc: attempted to register `" + rt.Kind().String() + "` object as `" + name + "`")
	}
	in := rt.NumIn() - 1
	if rt.NumIn() == -1 || rt.In(0) != ctxType {
		panic("rpc: the first argument for `" + name + "` needs to be *rpc.Context")
	}
	args := make([]reflect.Type, in)
	for i := 0; i < in; i++ {
		args[i] = rt.In(i + 1)
	}
	s := &service{
		args:   args,
		meth:   rv,
		in:     in,
		stream: stream,
	}
	services[name] = s
	return s
}

func Register(name string, v interface{}) *service {
	return register(name, v, false)
}

func RegisterStream(name string, v interface{}) *service {
	return register(name, v, true)
}

type Namespace string

func (ns Namespace) Register(name string, v interface{}) *service {
	return register(string(ns)+"."+name, v, false)
}

func (ns Namespace) RegisterStream(name string, v interface{}) *service {
	return register(string(ns)+"."+name, v, true)
}
