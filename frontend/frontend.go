// Public Domain (-) 2010-2011 The Ampify Authors.
// See the Ampify UNLICENSE file for details.

// Web Frontend
// ============
//
// The ``frontend`` app proxies requests to:
//
// 1. Google App Engine -- this is needed as App Engine doesn't yet support
//    HTTPS requests on custom domains.
//
// 2. The ``redstream`` app -- which, in turn, interacts with Redis.
//
package main

import (
	"amp/logging"
	"amp/optparse"
	"amp/runtime"
	"amp/tlsconf"
	"bufio"
	"crypto/rand"
	"crypto/tls"
	"fmt"
	"http"
	"io/ioutil"
	"mime"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	contentType      = "Content-Type"
	contentLength    = "Content-Length"
	redirectHTML     = `Please <a href="%s">click here if your browser doesn't redirect</a> automatically.`
	redirectURL      = "%s%s"
	redirectURLQuery = "%s%s?%s"
	textHTML         = "text/html; charset=utf-8"
)

var (
	debugMode      bool
	error502       []byte
	error503       []byte
	error502Length string
	error503Length string
)

type Redirector struct {
	hsts bool
	url  string
}

func (redirector *Redirector) ServeHTTP(conn http.ResponseWriter, req *http.Request) {

	var url string
	if len(req.URL.RawQuery) > 0 {
		url = fmt.Sprintf(redirectURLQuery, redirector.url, req.URL.Path, req.URL.RawQuery)
	} else {
		url = fmt.Sprintf(redirectURL, redirector.url, req.URL.Path)
	}

	if len(url) == 0 {
		url = "/"
	}

	if redirector.hsts {
		conn.Header().Set("Strict-Transport-Security", "max-age=50000000")
	}

	conn.Header().Set("Location", url)
	conn.WriteHeader(http.StatusMovedPermanently)
	fmt.Fprintf(conn, redirectHTML, url)
	logRequest(http.StatusMovedPermanently, req.Host, conn, req)

}

type Frontend struct {
	gaeAddr      string
	gaeHost      string
	gaeTLS       bool
	officialHost string
	redirectHTML []byte
	redirectURL  string
	staticFiles  map[string]*StaticFile
}

func (frontend *Frontend) ServeHTTP(conn http.ResponseWriter, req *http.Request) {

	if req.Host != frontend.officialHost {
		conn.Header().Set("Location", frontend.redirectURL)
		conn.WriteHeader(http.StatusMovedPermanently)
		conn.Write(frontend.redirectHTML)
		logRequest(http.StatusMovedPermanently, req.Host, conn, req)
		return
	}

	staticFile, ok := frontend.staticFiles[req.URL.Path]
	if ok {
		headers := conn.Header()
		headers.Set(contentType, staticFile.mimetype)
		headers.Set(contentLength, staticFile.size)
		conn.WriteHeader(http.StatusOK)
		conn.Write(staticFile.content)
		logRequest(http.StatusOK, req.Host, conn, req)
		return
	}

	originalHost := req.Host

	// Open a connection to the App Engine server.
	gaeConn, err := net.Dial("tcp", frontend.gaeAddr)
	if err != nil {
		if debugMode {
			fmt.Printf("Couldn't connect to remote %s: %v\n", frontend.gaeHost, err)
		}
		serveError502(conn, originalHost, req)
		return
	}

	var gae net.Conn

	if frontend.gaeTLS {
		gae = tls.Client(gaeConn, tlsconf.Config)
		defer gae.Close()
	} else {
		gae = gaeConn
	}

	// Modify the request Host: header.
	req.Host = frontend.gaeHost

	// Send the request to the App Engine server.
	err = req.Write(gae)
	if err != nil {
		if debugMode {
			fmt.Printf("Error writing to App Engine: %v\n", err)
		}
		serveError502(conn, originalHost, req)
		return
	}

	// Parse the response from App Engine.
	resp, err := http.ReadResponse(bufio.NewReader(gae), req.Method)
	if err != nil {
		if debugMode {
			fmt.Printf("Error parsing response from App Engine: %v\n", err)
		}
		serveError502(conn, originalHost, req)
		return
	}

	// Read the full response body.
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		if debugMode {
			fmt.Printf("Error reading response from App Engine: %v\n", err)
		}
		serveError502(conn, originalHost, req)
		resp.Body.Close()
		return
	}

	// Get the header.
	headers := conn.Header()

	// Set the received headers back to the initial connection.
	for k, values := range resp.Header {
		for _, v := range values {
			headers.Add(k, v)
		}
	}

	// Write the response body back to the initial connection.
	resp.Body.Close()
	conn.WriteHeader(resp.StatusCode)
	conn.Write(body)

	logRequest(resp.StatusCode, originalHost, conn, req)

}

func logRequest(status int, host string, conn http.ResponseWriter, request *http.Request) {
	var ip string
	splitPoint := strings.LastIndex(request.RemoteAddr, ":")
	if splitPoint == -1 {
		ip = request.RemoteAddr
	} else {
		ip = request.RemoteAddr[0:splitPoint]
	}
	logging.Info("fe", status, request.Method, host, request.RawURL,
		ip, request.UserAgent, request.Referer)
}

func filterRequestLog(record *logging.Record) (write bool, data []interface{}) {
	itemLength := len(record.Items)
	if itemLength > 1 {
		switch record.Items[0].(type) {
		case string:
			if record.Items[0].(string) == "fe" {
				return true, record.Items[1 : itemLength-2]
			}
		}
	}
	return true, data
}

func serveError502(conn http.ResponseWriter, host string, request *http.Request) {
	headers := conn.Header()
	headers.Set(contentType, textHTML)
	headers.Set(contentLength, error502Length)
	conn.WriteHeader(http.StatusBadGateway)
	conn.Write(error502)
	logRequest(http.StatusBadGateway, host, conn, request)
}

func joinPath(instanceDirectory, path string) string {
	if filepath.IsAbs(path) {
		return path
	}
	return filepath.Join(instanceDirectory, filepath.Clean(path))
}

func getErrorInfo(directory, filename string) ([]byte, string) {
	path := filepath.Join(directory, filename)
	file, err := os.Open(path)
	if err != nil {
		runtime.StandardError(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		runtime.StandardError(err)
	}
	buffer := make([]byte, info.Size)
	_, err = file.Read(buffer[:])
	if err != nil && err != os.EOF {
		runtime.StandardError(err)
	}
	return buffer, fmt.Sprintf("%d", info.Size)
}

type StaticFile struct {
	content  []byte
	mimetype string
	size     string
}

func getFiles(directory string, mapping map[string]*StaticFile, root string) {
	if debugMode {
		fmt.Printf("Caching static files in: %s\n", directory)
	}
	path, err := os.Open(directory)
	if err != nil {
		runtime.StandardError(err)
	}
	for {
		items, err := path.Readdir(100)
		if err != nil || len(items) == 0 {
			break
		}
		for _, item := range items {
			name := item.Name
			key := fmt.Sprintf("%s/%s", root, name)
			if item.IsDirectory() {
				getFiles(filepath.Join(directory, name), mapping, key)
			} else {
				content := make([]byte, item.Size)
				file, err := os.Open(filepath.Join(directory, name))
				if err != nil {
					runtime.StandardError(err)
				}
				_, err = file.Read(content[:])
				if err != nil && err != os.EOF {
					runtime.StandardError(err)
				}
				mimetype := mime.TypeByExtension(filepath.Ext(name))
				if mimetype == "" {
					mimetype = "application/octet-stream"
				}
				mapping[key] = &StaticFile{
					content:  content,
					mimetype: mimetype,
					size:     fmt.Sprintf("%d", len(content)),
				}
			}
		}
	}
}

func main() {

	// Define the options for the command line and config file options parser.
	opts := optparse.Parser(
		"Usage: frontend <config.yaml> [options]\n",
		"frontend 0.0.0")

	debug := opts.Bool([]string{"-d", "--debug"}, false,
		"enable debug mode")

	frontendHost := opts.StringConfig("frontend-host", "",
		"the host to bind the Frontend Server to")

	frontendPort := opts.IntConfig("frontend-port", 9040,
		"the port to bind the Frontend Server to [9040]")

	certFile := opts.StringConfig("cert-file", "cert/frontend.cert",
		"the path to the TLS certificate [cert/frontend.cert]")

	keyFile := opts.StringConfig("key-file", "cert/frontend.key",
		"the path to the TLS key [cert/frontend.key]")

	officialHost := opts.StringConfig("official-host", "localhost:9040",
		"limit Frontend Server to specified host [localhost:9040]")

	staticDirectory := opts.StringConfig("static-dir", "www",
		"the path to serve static files from [www]")

	errorDirectory := opts.StringConfig("error-dir", "error",
		"the path for HTTP error files [error]")

	noRedirect := opts.BoolConfig("no-redirect", false,
		"disable the HTTP Redirector [false]")

	httpHost := opts.StringConfig("http-host", "",
		"the host to bind the HTTP Redirector to")

	httpPort := opts.IntConfig("http-port", 9080,
		"the port to bind the HTTP Redirector to [9080]")

	redirectURL := opts.StringConfig("redirect-url", "",
		"the URL that the HTTP Redirector redirects to")

	enableHSTS := opts.BoolConfig("enable-hsts", false,
		"enable HTTP Strict Transport Security on redirects [false]")

	gaeHost := opts.StringConfig("gae-host", "localhost",
		"the App Engine host to connect to [localhost]")

	gaePort := opts.IntConfig("gae-port", 8080,
		"the App Engine port to connect to [8080]")

	gaeTLS := opts.BoolConfig("gae-tls", false,
		"use TLS when connecting to App Engine [false]")

	logRotate := opts.StringConfig("log-rotate", "never",
		"specify one of 'hourly', 'daily' or 'never' [never]")

	noConsoleLog := opts.BoolConfig("no-console-log", false,
		"disable logging to stdout/stderr [false]")

	os.Args[0] = "frontend"
	args := opts.Parse(os.Args)

	debugMode = *debug

	var instanceDirectory string
	var configPath string
	var err os.Error

	// If a config file is provided, assume its parent directory as the instance
	// directory, otherwise assume the current working directory as the instance
	// directory.
	if len(args) >= 1 {
		if args[0] == "help" {
			opts.PrintUsage()
			runtime.Exit(0)
		}
		configPath, err = filepath.Abs(filepath.Clean(args[0]))
		if err != nil {
			runtime.StandardError(err)
		}
		err = opts.ParseConfig(configPath, os.Args)
		if err != nil {
			runtime.StandardError(err)
		}
		instanceDirectory, _ = filepath.Split(configPath)
	} else {
		instanceDirectory, err = os.Getwd()
		if err != nil {
			runtime.StandardError(err)
		}
	}

	// Fail fast if the directory containing the 50x.html files isn't present.
	errorPath := joinPath(instanceDirectory, *errorDirectory)
	dirInfo, err := os.Stat(errorPath)
	if err == nil {
		if !dirInfo.IsDirectory() {
			runtime.Error("ERROR: %q is not a directory\n", errorPath)
		}
	} else {
		runtime.StandardError(err)
	}

	error502, error502Length = getErrorInfo(errorPath, "502.html")
	error503, error503Length = getErrorInfo(errorPath, "503.html")

	logPath := joinPath(instanceDirectory, "log")
	err = os.MkdirAll(logPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	runPath := joinPath(instanceDirectory, "run")
	err = os.MkdirAll(runPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	_, err = runtime.GetLock(runPath, "frontend")
	if err != nil {
		runtime.Error("ERROR: Couldn't successfully acquire a process lock:\n\n\t%s\n\n", err)
	}

	go runtime.CreatePidFile(filepath.Join(runPath, "frontend.pid"))

	var exitProcess bool
	if *certFile == "" {
		fmt.Printf("ERROR: The cert-file config value hasn't been specified.\n")
		exitProcess = true
	}
	if *keyFile == "" {
		fmt.Printf("ERROR: The key-file config value hasn't been specified.\n")
		exitProcess = true
	}
	if *officialHost == "" {
		fmt.Printf("ERROR: The official-host config value hasn't been specified.\n")
		exitProcess = true
	}
	if exitProcess {
		runtime.Exit(1)
	}

	staticPath := joinPath(instanceDirectory, *staticDirectory)
	dirInfo, err = os.Stat(staticPath)
	if err == nil {
		if !dirInfo.IsDirectory() {
			runtime.Error("ERROR: %q is not a directory\n", staticPath)
		}
	} else {
		runtime.StandardError(err)
	}

	// Load up all static files into a mapping.
	staticFiles := make(map[string]*StaticFile)
	getFiles(staticPath, staticFiles, "")

	// Initialise the Ampify runtime -- which will run ``frontend`` on multiple
	// processors if possible.
	runtime.Init()

	// Initialise the TLS config.
	tlsconf.Init()
	gaeAddr := fmt.Sprintf("%s:%d", *gaeHost, *gaePort)

	frontendAddr := fmt.Sprintf("%s:%d", *frontendHost, *frontendPort)
	frontendConn, err := net.Listen("tcp", frontendAddr)
	if err != nil {
		runtime.Error("ERROR: Cannot listen on %s: %v\n", frontendAddr, err)
	}

	certPath := joinPath(instanceDirectory, *certFile)
	keyPath := joinPath(instanceDirectory, *keyFile)
	tlsConfig := &tls.Config{
		NextProtos: []string{"http/1.1"},
		Rand:       rand.Reader,
		Time:       time.Seconds,
	}

	tlsConfig.Certificates = make([]tls.Certificate, 1)
	tlsConfig.Certificates[0], err = tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		runtime.Error("ERROR: Couldn't load certificate/key pair: %s\n", err)
	}

	frontendListener := tls.NewListener(frontendConn, tlsConfig)
	frontendURL := "https://" + *officialHost
	redirectHTML := []byte(fmt.Sprintf(redirectHTML, frontendURL))

	_ = staticDirectory

	if *httpHost == "" {
		*httpHost = "localhost"
	}

	httpAddrURL := fmt.Sprintf("http://%s:%d/", *httpHost, *httpPort)

	var httpAddr string
	var httpListener net.Listener

	if !*noRedirect {
		if *redirectURL == "" {
			*redirectURL = frontendURL
		}
		httpAddr = fmt.Sprintf("%s:%d", *httpHost, *httpPort)
		httpListener, err = net.Listen("tcp", httpAddr)
		if err != nil {
			runtime.Error("ERROR: Cannot listen on %s: %v\n", httpAddr, err)
		}
	}

	var rotate int

	switch *logRotate {
	case "daily":
		rotate = logging.RotateDaily
	case "hourly":
		rotate = logging.RotateHourly
	case "never":
		rotate = logging.RotateNever
	default:
		runtime.Error("ERROR: Unknown log rotation format %q\n", *logRotate)
	}

	if !*noConsoleLog {
		logging.AddConsoleLogger()
		logging.AddFilter(filterRequestLog)
	}

	_, err = logging.AddFileLogger("frontend", logPath, rotate)
	if err != nil {
		runtime.Error("ERROR: Couldn't initialise logfile: %s\n", err)
	}

	fmt.Printf("Running frontend with %d CPUs:\n", runtime.CPUCount)

	if !*noRedirect {
		redirector := &Redirector{url: *redirectURL, hsts: *enableHSTS}
		go func() {
			err = http.Serve(httpListener, redirector)
			if err != nil {
				runtime.Error("ERROR serving HTTP Redirector: %s\n", err)
			}
		}()
		fmt.Printf("* HTTP Redirector running on %s -> %s\n", httpAddrURL, *redirectURL)
	}

	frontend := &Frontend{
		gaeAddr:      gaeAddr,
		gaeHost:      *gaeHost,
		gaeTLS:       *gaeTLS,
		officialHost: *officialHost,
		redirectHTML: redirectHTML,
		redirectURL:  frontendURL,
		staticFiles:  staticFiles,
	}

	fmt.Printf("* Frontend Server running on %s\n", frontendURL)

	err = http.Serve(frontendListener, frontend)
	if err != nil {
		runtime.Error("ERROR serving Frontend Server: %s\n", err)
	}

}
