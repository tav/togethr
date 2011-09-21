// Changes to this file by The Togethr Authors are in the Public Domain.
// See the Togethr UNLICENSE file for details.

// Copyright 2009 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// This fork of Go's standard rpc package implements support for exposing
// services over Google App Engine.
package rpc

import (
	"appengine"
	"gob"
	"log"
	"io"
	"os"
	"reflect"
	"strings"
	"sync"
	"unicode"
	"utf8"
)

// Precompute the reflect type for os.Error.  Can't use os.Error directly
// because Typeof takes an empty interface value.  This is annoying.
var unusedError *os.Error
var typeOfOsError = reflect.TypeOf(unusedError).Elem()

// Likewise for appengine.Context.
var unusedContext *appengine.Context
var typeOfContext = reflect.TypeOf(unusedContext).Elem()

type methodType struct {
	method    reflect.Method
	ArgType   reflect.Type
	ReplyType reflect.Type
}

type service struct {
	name   string                 // name of service
	rcvr   reflect.Value          // receiver of methods for the service
	typ    reflect.Type           // type of the receiver
	method map[string]*methodType // registered methods
}

// Request is a header written before every RPC call.  It is used internally
// but documented here as an aid to debugging, such as when analyzing
// network traffic.
type Request struct {
	ServiceMethod string   // format: "Service.Method"
	Seq           uint64   // sequence number chosen by client
	next          *Request // for free list in Server
}

// Response is a header written before every RPC return.  It is used internally
// but documented here as an aid to debugging, such as when analyzing
// network traffic.
type Response struct {
	ServiceMethod string    // echoes that of the Request
	Seq           uint64    // echoes that of the request
	Error         string    // error, if any.
	next          *Response // for free list in Server
}

// Server represents an RPC Server.
type Server struct {
	mu         sync.Mutex // protects the serviceMap
	serviceMap map[string]*service
	reqLock    sync.Mutex // protects freeReq
	freeReq    *Request
	respLock   sync.Mutex // protects freeResp
	freeResp   *Response
}

// NewServer returns a new Server.
func NewServer() *Server {
	return &Server{serviceMap: make(map[string]*service)}
}

// Is this an exported - upper case - name?
func isExported(name string) bool {
	rune, _ := utf8.DecodeRuneInString(name)
	return unicode.IsUpper(rune)
}

// Is this type exported or a builtin?
func isExportedOrBuiltinType(t reflect.Type) bool {
	for t.Kind() == reflect.Ptr {
		t = t.Elem()
	}
	// PkgPath will be non-empty even for an exported type,
	// so we need to check the type name as well.
	return isExported(t.Name()) || t.PkgPath() == ""
}

// Register publishes in the server the set of methods of the
// receiver value that satisfy the following conditions:
//	- exported method
//	- two arguments, both pointers to exported structs
//	- one return value, of type os.Error
// It returns an error if the receiver is not an exported type or has no
// suitable methods.
// The client accesses each method using a string of the form "Type.Method",
// where Type is the receiver's concrete type.
func (server *Server) Register(rcvr interface{}) os.Error {
	return server.register(rcvr, "", false)
}

// RegisterName is like Register but uses the provided name for the type 
// instead of the receiver's concrete type.
func (server *Server) RegisterName(name string, rcvr interface{}) os.Error {
	return server.register(rcvr, name, true)
}

func (server *Server) register(rcvr interface{}, name string, useName bool) os.Error {
	if server.serviceMap == nil {
		server.serviceMap = make(map[string]*service)
	}
	s := new(service)
	s.typ = reflect.TypeOf(rcvr)
	s.rcvr = reflect.ValueOf(rcvr)
	sname := reflect.Indirect(s.rcvr).Type().Name()
	if useName {
		sname = name
	}
	if sname == "" {
		log.Fatal("rpc: no service name for type", s.typ.String())
	}
	if !isExported(sname) && !useName {
		s := "rpc Register: type " + sname + " is not exported"
		log.Print(s)
		return os.NewError(s)
	}
	if _, present := server.serviceMap[sname]; present {
		return os.NewError("rpc: service already defined: " + sname)
	}
	s.name = sname
	s.method = make(map[string]*methodType)

	// Install the methods
	for m := 0; m < s.typ.NumMethod(); m++ {
		method := s.typ.Method(m)
		mtype := method.Type
		mname := method.Name
		if method.PkgPath != "" {
			continue
		}
		// Method needs four ins: receiver, ctx, *args, *reply.
		if mtype.NumIn() != 4 {
			log.Println("method", mname, "has wrong number of ins:", mtype.NumIn())
			continue
		}
		// First arg must be an appengine.Context.
		if ctxType := mtype.In(1); ctxType != typeOfContext {
			log.Println("method", mname, "first arg", ctxType.String(), "not appengine.Context")
			continue
		}
		// Second arg need not be a pointer.
		argType := mtype.In(2)
		if !isExportedOrBuiltinType(argType) {
			log.Println(mname, "argument type not exported or local:", argType)
			continue
		}
		// Third arg must be a pointer.
		replyType := mtype.In(3)
		if replyType.Kind() != reflect.Ptr {
			log.Println("method", mname, "reply type not a pointer:", replyType)
			continue
		}
		if !isExportedOrBuiltinType(replyType) {
			log.Println("method", mname, "reply type not exported or local:", replyType)
			continue
		}
		// Method needs one out: os.Error.
		if mtype.NumOut() != 1 {
			log.Println("method", mname, "has wrong number of outs:", mtype.NumOut())
			continue
		}
		if returnType := mtype.Out(0); returnType != typeOfOsError {
			log.Println("method", mname, "returns", returnType.String(), "not os.Error")
			continue
		}
		s.method[mname] = &methodType{method: method, ArgType: argType, ReplyType: replyType}
	}

	if len(s.method) == 0 {
		s := "rpc Register: type " + sname + " has no exported methods of suitable type"
		log.Print(s)
		return os.NewError(s)
	}
	server.serviceMap[s.name] = s
	return nil
}

// A value sent as a placeholder for the response when the server receives an invalid request.
type InvalidRequest struct{}

var invalidRequest = InvalidRequest{}

func (server *Server) sendResponse(sending *sync.Mutex, req *Request, reply interface{}, codec ServerCodec, errmsg string) {
	resp := server.getResponse()
	// Encode the response header
	resp.ServiceMethod = req.ServiceMethod
	if errmsg != "" {
		resp.Error = errmsg
		reply = invalidRequest
	}
	resp.Seq = req.Seq
	sending.Lock()
	err := codec.WriteResponse(resp, reply)
	if err != nil {
		log.Println("rpc: writing response:", err)
	}
	sending.Unlock()
	server.freeResponse(resp)
}

func (s *service) call(server *Server, sending *sync.Mutex, mtype *methodType, req *Request, argv, replyv reflect.Value, codec ServerCodec, ctx appengine.Context) {
	function := mtype.method.Func
	// Invoke the method, providing a new value for the reply.
	returnValues := function.Call([]reflect.Value{s.rcvr, reflect.ValueOf(ctx), argv, replyv})
	// The return value for the method is an os.Error.
	errInter := returnValues[0].Interface()
	errmsg := ""
	if errInter != nil {
		errmsg = errInter.(os.Error).String()
	}
	server.sendResponse(sending, req, replyv.Interface(), codec, errmsg)
	server.freeRequest(req)
}

type GobServerCodec struct {
	Conn io.ReadCloser
	Dec  *gob.Decoder
	Enc  *gob.Encoder
}

func (c *GobServerCodec) ReadRequestHeader(r *Request) os.Error {
	return c.Dec.Decode(r)
}

func (c *GobServerCodec) ReadRequestBody(body interface{}) os.Error {
	return c.Dec.Decode(body)
}

func (c *GobServerCodec) WriteResponse(r *Response, body interface{}) (err os.Error) {
	if err = c.Enc.Encode(r); err != nil {
		return
	}
	if err = c.Enc.Encode(body); err != nil {
		return
	}
	return
}

func (c *GobServerCodec) Close() os.Error {
	return c.Conn.Close()
}

// ServeRequest synchronously serves a single request.
// It does not close the codec upon completion.
func (server *Server) ServeRequest(codec ServerCodec, ctx appengine.Context) os.Error {
	sending := new(sync.Mutex)
	service, mtype, req, argv, replyv, err := server.readRequest(codec)
	if err != nil {
		if err == os.EOF || err == io.ErrUnexpectedEOF {
			return err
		}
		// send a response if we actually managed to read a header.
		if req != nil {
			server.sendResponse(sending, req, invalidRequest, codec, err.String())
			server.freeRequest(req)
		}
		return err
	}
	service.call(server, sending, mtype, req, argv, replyv, codec, ctx)
	return nil
}

func (server *Server) getRequest() *Request {
	server.reqLock.Lock()
	req := server.freeReq
	if req == nil {
		req = new(Request)
	} else {
		server.freeReq = req.next
		*req = Request{}
	}
	server.reqLock.Unlock()
	return req
}

func (server *Server) freeRequest(req *Request) {
	server.reqLock.Lock()
	req.next = server.freeReq
	server.freeReq = req
	server.reqLock.Unlock()
}

func (server *Server) getResponse() *Response {
	server.respLock.Lock()
	resp := server.freeResp
	if resp == nil {
		resp = new(Response)
	} else {
		server.freeResp = resp.next
		*resp = Response{}
	}
	server.respLock.Unlock()
	return resp
}

func (server *Server) freeResponse(resp *Response) {
	server.respLock.Lock()
	resp.next = server.freeResp
	server.freeResp = resp
	server.respLock.Unlock()
}

func (server *Server) readRequest(codec ServerCodec) (service *service, mtype *methodType, req *Request, argv, replyv reflect.Value, err os.Error) {
	service, mtype, req, err = server.readRequestHeader(codec)
	if err != nil {
		if err == os.EOF || err == io.ErrUnexpectedEOF {
			return
		}
		// discard body
		codec.ReadRequestBody(nil)
		return
	}

	// Decode the argument value.
	argIsValue := false // if true, need to indirect before calling.
	if mtype.ArgType.Kind() == reflect.Ptr {
		argv = reflect.New(mtype.ArgType.Elem())
	} else {
		argv = reflect.New(mtype.ArgType)
		argIsValue = true
	}
	// argv guaranteed to be a pointer now.
	if err = codec.ReadRequestBody(argv.Interface()); err != nil {
		return
	}
	if argIsValue {
		argv = argv.Elem()
	}

	replyv = reflect.New(mtype.ReplyType.Elem())
	return
}

func (server *Server) readRequestHeader(codec ServerCodec) (service *service, mtype *methodType, req *Request, err os.Error) {
	// Grab the request header.
	req = server.getRequest()
	err = codec.ReadRequestHeader(req)
	if err != nil {
		req = nil
		if err == os.EOF || err == io.ErrUnexpectedEOF {
			return
		}
		err = os.NewError("rpc: server cannot decode request: " + err.String())
		return
	}

	serviceMethod := strings.Split(req.ServiceMethod, ".", -1)
	if len(serviceMethod) != 2 {
		err = os.NewError("rpc: service/method request ill-formed: " + req.ServiceMethod)
		return
	}
	// Look up the request.
	service = server.serviceMap[serviceMethod[0]]
	if service == nil {
		err = os.NewError("rpc: can't find service " + req.ServiceMethod)
		return
	}
	mtype = service.method[serviceMethod[1]]
	if mtype == nil {
		err = os.NewError("rpc: can't find method " + req.ServiceMethod)
	}
	return
}

// A ServerCodec implements reading of RPC requests and writing of
// RPC responses for the server side of an RPC session.
// The server calls ReadRequestHeader and ReadRequestBody in pairs
// to read requests from the connection, and it calls WriteResponse to
// write a response back.  The server calls Close when finished with the
// connection. ReadRequestBody may be called with a nil
// argument to force the body of the request to be read and discarded.
type ServerCodec interface {
	ReadRequestHeader(*Request) os.Error
	ReadRequestBody(interface{}) os.Error
	WriteResponse(*Response, interface{}) os.Error

	Close() os.Error
}
