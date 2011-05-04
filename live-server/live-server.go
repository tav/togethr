// Public Domain (-) 2010-2011 The Ampify Authors.
// See the Ampify UNLICENSE file for details.

// Live Server
// ===========
//
package main

import (
	"amp/argo"
	"amp/logging"
	"amp/optparse"
	"amp/refmap"
	"amp/runtime"
	"amp/tlsconf"
	"bufio"
	"bytes"
	"compress/gzip"
	"crypto/rand"
	"crypto/sha1"
	"crypto/tls"
	"encoding/base64"
	"fmt"
	"http"
	"io"
	"io/ioutil"
	"mime"
	"net"
	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
	"websocket"
)

const (
	contentType      = "Content-Type"
	contentLength    = "Content-Length"
	redirectHTML     = `Please <a href="%s">click here if your browser doesn't redirect</a> automatically.`
	redirectURL      = "%s%s"
	redirectURLQuery = "%s%s?%s"
	textPlain        = "text/plain"
	textHTML         = "text/html; charset=utf-8"
)

const (
	nodeIDLength = 32
	selfRef      = "\xff"
)

// Constants for the different log event types.
const (
	HTTP_PING = iota
	HTTP_REDIRECT
	HTTPS_COMET
	HTTPS_INTERNAL_ERROR
	HTTPS_MAINTENANCE
	HTTPS_PROXY_ERROR
	HTTPS_REDIRECT
	HTTPS_STATIC
	HTTPS_UPSTREAM
	HTTPS_WEBSOCKET
)

var (
	acceptorKey    []byte
	cookieKey      []byte
	debugMode      bool
	error500       []byte
	error502       []byte
	error503       []byte
	error500Length string
	error502Length string
	error503Length string
	selfID         []byte
)

var (
	pingResponse       = []byte("pong")
	pingResponseLength = fmt.Sprintf("%d", len(pingResponse))
)

// -----------------------------------------------------------------------------
// X-Live Handler
// -----------------------------------------------------------------------------

var liveChannel = make(chan []byte, 100)

func handleLiveMessages() {
	for message := range liveChannel {
		cmd := message[0]
		switch cmd {
		case 0:
			go publish(message[1:])
		case 1:
			go subscribe(message[1:])
		default:
			logging.Error("Got unexpected X-Live payload: %s", message)
		}
	}
}

// -----------------------------------------------------------------------------
// PubSub Data Types
// -----------------------------------------------------------------------------

var pubsub = NewPubSub()
var sqidMap = refmap.New()

type Subscription struct {
	seen  int64
	sqid  uint64
	tally int
}

type PubSub struct {
	mutex sync.RWMutex
	subs  map[string][]*Subscription
}

func (pubsub *PubSub) Subscribe(keys []string, tally int, ref uint64, now int64) {
	data := pubsub.subs
	pubsub.mutex.Lock()
	for _, key := range keys {
		sub := &Subscription{
			seen:  now,
			sqid:  ref,
			tally: tally,
		}
		subs, found := data[key]
		if found {
			data[key] = append(subs, sub)
		} else {
			data[key] = []*Subscription{sub}
		}
	}
	pubsub.mutex.Unlock()
}

func NewPubSub() *PubSub {
	subs := make(map[string][]*Subscription)
	return &PubSub{subs: subs}
}

// -----------------------------------------------------------------------------
// PubSub Payload Handlers
// -----------------------------------------------------------------------------

// The publish message is of the format::
//
//     <item-id> [<key>, ...]
//
func publish(message []byte) {
	buffer := bytes.NewBuffer(message)
	decoder := &argo.Decoder{buffer}
	itemID, err := decoder.ReadString()
	if err != nil {
		logging.Error("Error decoding X-Live Publish ItemID %q: %s", message, err)
		return
	}
	if itemID == "" {
		return
	}
	keys, err := decoder.ReadStringArray()
	if err != nil {
		logging.Error("Error decoding X-Live Publish Keys %q: %s", message, err)
		return
	}
	count := len(keys)
	if count == 0 {
		return
	}
	_ = itemID
}

// The subscribe message is of the format::
//
//     <sqid> [<key>, ...] [<key>, ...]
//
// The two sets of keys are assumed to be disjoint sets, i.e. they have no
// elements in common.
func subscribe(message []byte) {
	buffer := bytes.NewBuffer(message)
	decoder := &argo.Decoder{buffer}
	sqid, err := decoder.ReadString()
	if err != nil {
		logging.Error("Error decoding X-Live Subscribe SQID %q: %s", message, err)
		return
	}
	if sqid == "" {
		return
	}
	keys1, err := decoder.ReadStringArray()
	if err != nil {
		logging.Error("Error decoding X-Live Subscribe Keys-1 %q: %s", message, err)
		return
	}
	var keys2 []string
	if buffer.Len() > 0 {
		keys2, err = decoder.ReadStringArray()
		if err != nil {
			logging.Error("Error decoding X-Live Subscribe Keys-2 %q: %s", message, err)
			return
		}
	}
	tally := len(keys1)
	keys2Len := len(keys2)
	refCount := tally + keys2Len
	if refCount == 0 {
		return
	}
	now := time.Seconds()
	ref := sqidMap.Incref(sqid, refCount)
	if keys2Len > 0 {
		tally += 1
	}
	pubsub.Subscribe(keys1, tally, ref, now)
	pubsub.Subscribe(keys2, tally, ref, now)
}

// -----------------------------------------------------------------------------
// HTTP Redirector
// -----------------------------------------------------------------------------

type Redirector struct {
	hsts     string
	pingPath string
	url      string
}

func (redirector *Redirector) ServeHTTP(conn http.ResponseWriter, req *http.Request) {

	if req.URL.Path == redirector.pingPath {
		headers := conn.Header()
		headers.Set(contentType, textPlain)
		headers.Set(contentLength, pingResponseLength)
		conn.WriteHeader(http.StatusOK)
		conn.Write(pingResponse)
		logRequest(HTTP_PING, http.StatusOK, req.Host, req)
		return
	}

	var url string
	if len(req.URL.RawQuery) > 0 {
		url = fmt.Sprintf(redirectURLQuery, redirector.url, req.URL.Path, req.URL.RawQuery)
	} else {
		url = fmt.Sprintf(redirectURL, redirector.url, req.URL.Path)
	}

	if len(url) == 0 {
		url = "/"
	}

	if redirector.hsts != "" {
		conn.Header().Set("Strict-Transport-Security", redirector.hsts)
	}

	conn.Header().Set("Location", url)
	conn.WriteHeader(http.StatusMovedPermanently)
	fmt.Fprintf(conn, redirectHTML, url)
	logRequest(HTTP_REDIRECT, http.StatusMovedPermanently, req.Host, req)

}

// -----------------------------------------------------------------------------
// HTTPS Frontend
// -----------------------------------------------------------------------------

type Frontend struct {
	cometPrefix     string
	liveMode        bool
	maintenanceMode bool
	redirectHTML    []byte
	redirectURL     string
	staticCache     string
	staticFiles     map[string]*StaticFile
	staticMaxAge    int64
	upstreamAddr    string
	upstreamHost    string
	upstreamTLS     bool
	validAddress    string
	validWildcard   bool
	websocketPrefix string
}

// The ``isValidHost`` method validates a request Host against any specified
// valid address/wildcard.
func (frontend *Frontend) isValidHost(host string) (valid bool) {
	if frontend.validAddress == "" {
		return true
	}
	if frontend.validWildcard {
		splitHost := strings.Split(host, ".", 2)
		if len(splitHost) != 2 {
			return
		}
		if splitHost[1] == frontend.validAddress {
			return true
		}
		return
	}
	if host == frontend.validAddress {
		return true
	}
	return
}

func (frontend *Frontend) ServeHTTP(conn http.ResponseWriter, req *http.Request) {

	originalHost := req.Host

	// Redirect all requests to the "official" public host if the Host header
	// doesn't match.
	if !frontend.isValidHost(originalHost) {
		conn.Header().Set("Location", frontend.redirectURL)
		conn.WriteHeader(http.StatusMovedPermanently)
		conn.Write(frontend.redirectHTML)
		logRequest(HTTPS_REDIRECT, http.StatusMovedPermanently, originalHost, req)
		return
	}

	// Return the HTTP 503 error page if we're in maintenance mode.
	if frontend.maintenanceMode {
		headers := conn.Header()
		headers.Set(contentType, textHTML)
		headers.Set(contentLength, error503Length)
		conn.WriteHeader(http.StatusServiceUnavailable)
		conn.Write(error503)
		logRequest(HTTPS_MAINTENANCE, http.StatusServiceUnavailable, originalHost, req)
		return
	}

	reqPath := req.URL.Path

	// Handle requests for any files exposed within the static directory.
	if staticFile, ok := frontend.staticFiles[reqPath]; ok {
		expires := time.SecondsToUTC(time.Seconds() + frontend.staticMaxAge)
		headers := conn.Header()
		headers.Set("Expires", expires.Format(http.TimeFormat))
		headers.Set("Cache-Control", frontend.staticCache)
		headers.Set("Etag", staticFile.etag)
		if req.Header.Get("If-None-Match") == staticFile.etag {
			conn.WriteHeader(http.StatusNotModified)
			logRequest(HTTPS_STATIC, http.StatusNotModified, originalHost, req)
			return
		}
		headers.Set(contentType, staticFile.mimetype)
		headers.Set(contentLength, staticFile.size)
		conn.WriteHeader(http.StatusOK)
		conn.Write(staticFile.content)
		logRequest(HTTPS_STATIC, http.StatusOK, originalHost, req)
		return
	}

	if frontend.liveMode {

		// Handle WebSocket requests.
		if strings.HasPrefix(reqPath, frontend.websocketPrefix) {
			websocket.Handler(handleWebSocket).ServeHTTP(conn, req)
			return
		}

		// Handle long-polling Comet requests.
		if strings.HasPrefix(reqPath, frontend.cometPrefix) {
			logRequest(HTTPS_COMET, http.StatusOK, originalHost, req)
			return
		}

	}

	// Open a connection to the upstream server.
	upstreamConn, err := net.Dial("tcp", frontend.upstreamAddr)
	if err != nil {
		logging.Error("Couldn't connect to upstream: %s", err)
		serveError502(conn, originalHost, req)
		return
	}

	var clientIP string
	var upstream net.Conn

	splitPoint := strings.LastIndex(req.RemoteAddr, ":")
	if splitPoint == -1 {
		clientIP = req.RemoteAddr
	} else {
		clientIP = req.RemoteAddr[0:splitPoint]
	}

	if frontend.upstreamTLS {
		upstream = tls.Client(upstreamConn, tlsconf.Config)
		defer upstream.Close()
	} else {
		upstream = upstreamConn
	}

	// Modify the request Host: and User-Agent: headers.
	req.Host = frontend.upstreamHost
	req.UserAgent = fmt.Sprintf("%s, %s, %s", req.UserAgent, clientIP, originalHost)

	// Send the request to the upstream server.
	err = req.Write(upstream)
	if err != nil {
		logging.Error("Error writing to the upstream server: %s", err)
		serveError502(conn, originalHost, req)
		return
	}

	// Parse the response from upstream.
	resp, err := http.ReadResponse(bufio.NewReader(upstream), req.Method)
	if err != nil {
		logging.Error("Error parsing response from upstream: %s", err)
		serveError502(conn, originalHost, req)
		return
	}

	defer resp.Body.Close()

	// Get the original request header.
	headers := conn.Header()

	// Set a variable to hold the X-Live header value if present.
	var liveLength int

	if frontend.liveMode {
		xLive := resp.Header.Get("X-Live")
		if xLive != "" {
			// If the X-Live header was set, parse it into an int.
			liveLength, err = strconv.Atoi(xLive)
			if err != nil {
				logging.Error("Error converting X-Live header value %q: %s", xLive, err)
				serveError500(conn, originalHost, req)
				return
			}
			resp.Header.Del("X-Live")
		}
	}

	var body []byte

	if liveLength > 0 {

		var gzipSet bool
		var respBody io.ReadCloser

		// Check Content-Encoding to see if upstream sent gzipped content.
		if resp.Header.Get("Content-Encoding") == "gzip" {
			gzipSet = true
			respBody, err = gzip.NewReader(resp.Body)
			if err != nil {
				logging.Error("Error reading gzipped response from upstream: %s", err)
				serveError500(conn, originalHost, req)
				return
			}
			defer respBody.Close()
		} else {
			respBody = resp.Body
		}

		// Read the X-Live content from the response body.
		liveMessage := make([]byte, liveLength)
		n, err := respBody.Read(liveMessage)
		if n != liveLength || err != nil {
			logging.Error("Error reading X-Live response from upstream: %s", err)
			serveError500(conn, originalHost, req)
			return
		}

		// Read the response to send back to the original request.
		body, err = ioutil.ReadAll(respBody)
		if err != nil {
			logging.Error("Error reading non X-Live response from upstream: %s", err)
			serveError500(conn, originalHost, req)
			return
		}

		// Re-encode the response if it had been gzipped by upstream.
		if gzipSet {
			buffer := &bytes.Buffer{}
			encoder, err := gzip.NewWriter(buffer)
			if err != nil {
				logging.Error("Error creating a new gzip Writer: %s", err)
				serveError500(conn, originalHost, req)
				return
			}
			n, err = encoder.Write(body)
			if n != len(body) || err != nil {
				logging.Error("Error writing to the gzip Writer: %s", err)
				serveError500(conn, originalHost, req)
				return
			}
			err = encoder.Close()
			if err != nil {
				logging.Error("Error finalising the write to the gzip Writer: %s", err)
				serveError500(conn, originalHost, req)
				return
			}
			body = buffer.Bytes()
		}

		resp.Header.Set(contentLength, fmt.Sprintf("%d", len(body)))
		liveChannel <- liveMessage

	} else {
		// Read the full response body.
		body, err = ioutil.ReadAll(resp.Body)
		if err != nil {
			logging.Error("Error reading response from upstream: %s", err)
			serveError502(conn, originalHost, req)
			return
		}
	}

	// Set the received headers back to the initial connection.
	for k, values := range resp.Header {
		for _, v := range values {
			headers.Add(k, v)
		}
	}

	// Write the response body back to the initial connection.
	conn.WriteHeader(resp.StatusCode)
	conn.Write(body)
	logRequest(HTTPS_UPSTREAM, resp.StatusCode, originalHost, req)

}

func serveError502(conn http.ResponseWriter, host string, request *http.Request) {
	headers := conn.Header()
	headers.Set(contentType, textHTML)
	headers.Set(contentLength, error502Length)
	conn.WriteHeader(http.StatusBadGateway)
	conn.Write(error502)
	logRequest(HTTPS_PROXY_ERROR, http.StatusBadGateway, host, request)
}

func serveError500(conn http.ResponseWriter, host string, request *http.Request) {
	headers := conn.Header()
	headers.Set(contentType, textHTML)
	headers.Set(contentLength, error500Length)
	conn.WriteHeader(http.StatusInternalServerError)
	conn.Write(error500)
	logRequest(HTTPS_INTERNAL_ERROR, http.StatusInternalServerError, host, request)
}

// -----------------------------------------------------------------------------
// WebSocket Handler
// -----------------------------------------------------------------------------

func handleWebSocket(conn *websocket.Conn) {
	defer func() {
		conn.Close()
		logRequest(HTTPS_WEBSOCKET, http.StatusOK, conn.Request.Host, conn.Request)
	}()
	if conn.Request.Header.Get("User-Agent") == "Safari" {
		fmt.Printf("boo")
	}
}

// -----------------------------------------------------------------------------
// Logging
// -----------------------------------------------------------------------------

func logRequest(proto, status int, host string, request *http.Request) {
	var ip string
	splitPoint := strings.LastIndex(request.RemoteAddr, ":")
	if splitPoint == -1 {
		ip = request.RemoteAddr
	} else {
		ip = request.RemoteAddr[0:splitPoint]
	}
	logging.InfoData("ls", proto, status, request.Method, host, request.RawURL,
		ip, request.UserAgent, request.Referer)
}

func filterRequestLog(record *logging.Record) (write bool, data []interface{}) {
	items := record.Items
	itemLength := len(items)
	if itemLength > 1 {
		identifier := items[0]
		switch identifier.(type) {
		case string:
			switch identifier.(string) {
			case "ls":
				return true, items[2 : itemLength-2]
			case "m":
				return true, items[1:itemLength]
			}
		}
	}
	return true, data
}

// -----------------------------------------------------------------------------
// Utility Functions
// -----------------------------------------------------------------------------

// The ``joinPath`` utility function joins the given ``path`` with the
// ``instanceDirectory`` unless it happens to be an absolute path, in which case
// it returns the path exactly as it was given.
func joinPath(instanceDirectory, path string) string {
	if filepath.IsAbs(path) {
		return path
	}
	return filepath.Join(instanceDirectory, filepath.Clean(path))
}

// The ``getErrorInfo`` utility function loads the specified error file from the
// given directory and returns its content and file size.
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

// The ``StaticFile`` type holds the data needed to serve a static file via the
// HTTPS Frontend.
type StaticFile struct {
	content  []byte
	etag     string
	mimetype string
	size     string
}

// The ``getFiles`` utility function populates the given ``mapping`` with
// ``StaticFile`` instances for all files found within a given ``directory``.
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
				hash := sha1.New()
				hash.Write(content)
				buffer := &bytes.Buffer{}
				encoder := base64.NewEncoder(base64.URLEncoding, buffer)
				encoder.Write(hash.Sum())
				encoder.Close()
				mapping[key] = &StaticFile{
					content:  content,
					etag:     fmt.Sprintf(`"%s"`, buffer.String()),
					mimetype: mimetype,
					size:     fmt.Sprintf("%d", len(content)),
				}
			}
		}
	}
}

// The ``initFrontend`` utility function abstracts away the various checks and
// steps involved in setting up and running a new HTTPS Frontend.
func initFrontend(status, host string, port int, publicAddress, validAddress, cert, key, cometPrefix, websocketPrefix, instanceDirectory, upstreamHost string, upstreamPort int, upstreamTLS, maintenanceMode, liveMode bool, staticCache string, staticFiles map[string]*StaticFile, staticMaxAge int64) *Frontend {

	var err os.Error

	// Exit if the config values for the paths of the server's certificate or
	// key haven't been specified.
	if cert == "" {
		runtime.Error("ERROR: The %s-cert config value hasn't been specified.\n", status)
	}
	if key == "" {
		runtime.Error("ERROR: The %s-key config value hasn't been specified.\n", status)
	}

	// Initialise a fresh TLS Config.
	tlsConfig := &tls.Config{
		NextProtos: []string{"http/1.1"},
		Rand:       rand.Reader,
		Time:       time.Seconds,
	}

	// Load the certificate and private key into the TLS config.
	certPath := joinPath(instanceDirectory, cert)
	keyPath := joinPath(instanceDirectory, key)
	tlsConfig.Certificates = make([]tls.Certificate, 1)
	tlsConfig.Certificates[0], err = tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		runtime.Error("ERROR: Couldn't load %s certificate/key pair: %s\n",
			status, err)
	}

	// Instantiate the associated variables and listener for the HTTPS Frontend.
	upstreamAddr := fmt.Sprintf("%s:%d", upstreamHost, upstreamPort)
	frontendAddr := fmt.Sprintf("%s:%d", host, port)
	frontendConn, err := net.Listen("tcp", frontendAddr)
	if err != nil {
		runtime.Error("ERROR: Cannot listen on %s: %v\n", frontendAddr, err)
	}

	frontendListener := tls.NewListener(frontendConn, tlsConfig)

	// Compute the variables related to detecting valid hosts.
	var validWildcard bool
	if strings.HasPrefix(validAddress, "*.") {
		validAddress = validAddress[2:]
		validWildcard = true
	}

	// Compute the variables related to redirects.
	redirectURL := "https://" + publicAddress
	redirectHTML := []byte(fmt.Sprintf(redirectHTML, redirectURL))

	// Instantiate a ``Frontend`` object for use by the HTTPS Frontend.
	frontend := &Frontend{
		cometPrefix:     cometPrefix,
		liveMode:        liveMode,
		maintenanceMode: maintenanceMode,
		redirectHTML:    redirectHTML,
		redirectURL:     redirectURL,
		staticCache:     staticCache,
		staticFiles:     staticFiles,
		staticMaxAge:    staticMaxAge,
		upstreamAddr:    upstreamAddr,
		upstreamHost:    upstreamHost,
		upstreamTLS:     upstreamTLS,
		validAddress:    validAddress,
		validWildcard:   validWildcard,
		websocketPrefix: websocketPrefix,
	}

	// Start the HTTPS Frontend.
	go func() {
		err = http.Serve(frontendListener, frontend)
		if err != nil {
			runtime.Error("ERROR serving %s HTTPS Frontend: %s\n", status, err)
		}
	}()

	var frontendURL string
	if host == "" {
		frontendURL = fmt.Sprintf("https://localhost:%d", port)
	} else {
		frontendURL = fmt.Sprintf("https://%s:%d", host, port)
	}

	fmt.Printf("* HTTPS Frontend %s running on %s\n", status, frontendURL)

	return frontend

}

// The ``initProcess`` utility function acquires a process lock and writes the
// PID file for the current process.
func initProcess(typeName, runPath string) {

	pidFile := fmt.Sprintf("%s.pid", typeName)

	// Get the runtime lock to ensure we only have one live-server process of
	// any given type running within the same instance directory at any time.
	_, err := runtime.GetLock(runPath, typeName)
	if err != nil {
		runtime.Error("ERROR: Couldn't successfully acquire a process lock:\n\n\t%s\n\n", err)
	}

	// Write the process ID into a file for use by external scripts.
	go runtime.CreatePidFile(filepath.Join(runPath, pidFile))

}

// -----------------------------------------------------------------------------
// Main Runner
// -----------------------------------------------------------------------------

func main() {

	// Define the options for the command line and config file options parser.
	opts := optparse.Parser(
		"Usage: live-server <config.yaml> [options]\n",
		"live-server 0.0.1")

	debug := opts.Bool([]string{"-d", "--debug"}, false,
		"enable debug mode")

	genConfig := opts.Bool([]string{"-g", "--gen-config"}, false,
		"show the default yaml config")

	frontendHost := opts.StringConfig("frontend-host", "",
		"the host to bind the HTTPS Frontends to")

	frontendPort := opts.IntConfig("frontend-port", 9040,
		"the base port for the HTTPS Frontends [9040]")

	publicAddress := opts.StringConfig("public-address", "",
		"the official public address for the HTTPS Frontends")

	primaryHosts := opts.StringConfig("primary-hosts", "",
		"limit the primary HTTPS Frontend to the specified host pattern")

	primaryCert := opts.StringConfig("primary-cert", "cert/primary.cert",
		"the path to the primary host's TLS certificate [cert/primary.cert]")

	primaryKey := opts.StringConfig("primary-key", "cert/primary.key",
		"the path to the primary host's TLS key [cert/primary.key]")

	noSecondary := opts.BoolConfig("no-secondary", false,
		"disable the secondary HTTPS Frontend [false]")

	secondaryHosts := opts.StringConfig("secondary-hosts", "",
		"limit the secondary HTTPS Frontend to the specified host pattern")

	secondaryCert := opts.StringConfig("secondary-cert", "cert/secondary.cert",
		"the path to the secondary host's TLS certificate [cert/secondary.cert]")

	secondaryKey := opts.StringConfig("secondary-key", "cert/secondary.key",
		"the path to the secondary host's TLS key [cert/secondary.key]")

	errorDirectory := opts.StringConfig("error-dir", "error",
		"the path to the HTTP error files directory [error]")

	logDirectory := opts.StringConfig("log-dir", "log",
		"the path to the log directory [log]")

	runDirectory := opts.StringConfig("run-dir", "run",
		"the path to the run directory to store locks, pid files, etc. [run]")

	staticDirectory := opts.StringConfig("static-dir", "www",
		"the path to the static files directory [www]")

	staticMaxAge := opts.IntConfig("static-max-age", 86400,
		"max-age cache header value when serving the static files [86400]")

	noLivequery := opts.BoolConfig("no-livequery", false,
		"disable the LiveQuery node and WebSocket/Comet support [false]")

	websocketPrefix := opts.StringConfig("websocket-prefix", "/.ws/",
		"URL path prefix for WebSocket requests [/.ws/]")

	cometPrefix := opts.StringConfig("comet-prefix", "/.live/",
		"URL path prefix for Comet requests [/.live/]")

	livequeryHost := opts.StringConfig("livequery-host", "",
		"the host to bind the LiveQuery node to")

	livequeryPort := opts.IntConfig("livequery-port", 9050,
		"the port (both UDP and TCP) to bind the LiveQuery node to [9050]")

	livequeryExpiry := opts.IntConfig("livequery-expiry", 40,
		"maximum number of seconds a LiveQuery subscription is valid [40]")

	cookieKeyPath := opts.StringConfig("cookie-key", "cert/cookie.key",
		"the path to the file containing the key used to sign cookies [cert/cookie.key]")

	cookieName := opts.StringConfig("cookie-name", "user",
		"the property name of the cookie containing the user id [user]")

	acceptors := opts.StringConfig("acceptor-nodes", "localhost:9060",
		"comma-separated addresses of Acceptor nodes [localhost:9060]")

	acceptorKeyPath := opts.StringConfig("acceptor-key", "cert/acceptor.key",
		"the path to the file containing the Acceptor secret key [cert/acceptor.key]")

	runAcceptor := opts.BoolConfig("run-as-acceptor", false,
		"run as an Acceptor node [false]")

	acceptorIndex := opts.IntConfig("acceptor-index", 0,
		"this node's index in the Acceptor nodes address list [0]")

	leaseExpiry := opts.IntConfig("lease-expiry", 7,
		"maximum number of seconds a lease from an Acceptor node is valid [7]")

	noRedirect := opts.BoolConfig("no-redirect", false,
		"disable the HTTP Redirector [false]")

	httpHost := opts.StringConfig("http-host", "",
		"the host to bind the HTTP Redirector to")

	httpPort := opts.IntConfig("http-port", 9080,
		"the port to bind the HTTP Redirector to [9080]")

	redirectURL := opts.StringConfig("redirect-url", "",
		"the URL that the HTTP Redirector redirects to")

	pingPath := opts.StringConfig("ping-path", "/.ping",
		`URL path for a "ping" request [/.ping]`)

	enableHSTS := opts.BoolConfig("enable-hsts", false,
		"enable HTTP Strict Transport Security (HSTS) on redirects [false]")

	hstsMaxAge := opts.IntConfig("hsts-max-age", 50000000,
		"max-age value of HSTS in number of seconds [50000000]")

	upstreamHost := opts.StringConfig("upstream-host", "localhost",
		"the upstream host to connect to [localhost]")

	upstreamPort := opts.IntConfig("upstream-port", 8080,
		"the upstream port to connect to [8080]")

	upstreamTLS := opts.BoolConfig("upstream-tls", false,
		"use TLS when connecting to upstream [false]")

	logRotate := opts.StringConfig("log-rotate", "never",
		"specify one of 'hourly', 'daily' or 'never' [never]")

	noConsoleLog := opts.BoolConfig("no-console-log", false,
		"disable server requests being logged to the console [false]")

	maintenanceMode := opts.BoolConfig("maintenance", false,
		"start up in maintenance mode [false]")

	extraConfig := opts.StringConfig("extra-config", "",
		"path to a YAML config file with additional options")

	// Parse the command line options.
	os.Args[0] = "live-server"
	args := opts.Parse(os.Args)

	// Print the default YAML config file if the ``-g`` flag was specified.
	if *genConfig {
		opts.PrintDefaultConfigFile()
		runtime.Exit(0)
	}

	// Set the debug mode flag if the ``-d`` flag was specified.
	debugMode = *debug

	var instanceDirectory string
	var configPath string
	var err os.Error

	// Assume the parent directory of the config as the instance directory.
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
		opts.PrintUsage()
		runtime.Exit(0)
	}

	// Load the extra config file with additional options if one has been
	// specified.
	if *extraConfig != "" {
		extraConfigPath, err := filepath.Abs(filepath.Clean(*extraConfig))
		if err != nil {
			runtime.StandardError(err)
		}
		extraConfigPath = joinPath(instanceDirectory, extraConfigPath)
		err = opts.ParseConfig(extraConfigPath, os.Args)
		if err != nil {
			runtime.StandardError(err)
		}
	}

	// Create the log directory if it doesn't exist.
	logPath := joinPath(instanceDirectory, *logDirectory)
	err = os.MkdirAll(logPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	// Create the run directory if it doesn't exist.
	runPath := joinPath(instanceDirectory, *runDirectory)
	err = os.MkdirAll(runPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	// Initialise the Ampify runtime -- which will run ``live-server`` on
	// multiple processors if possible.
	runtime.Init()

	// Handle running as an Acceptor node if ``--run-as-acceptor`` was
	// specified.
	if *runAcceptor {

		// Exit if the `--acceptor-index`` is negative.
		if *acceptorIndex < 0 {
			runtime.Error("ERROR: The --acceptor-index cannot be negative.\n")
		}

		var index int
		var selfAddress string
		var acceptorNodes []string

		// Generate a list of all the acceptor node addresses and exit if we
		// couldn't find the address four ourselves at the given index.
		for _, acceptor := range strings.Split(*acceptors, ",", -1) {
			acceptor = strings.TrimSpace(acceptor)
			if acceptor != "" {
				if index == *acceptorIndex {
					selfAddress = acceptor
				} else {
					acceptorNodes = append(acceptorNodes, acceptor)
				}
			}
			index += 1
		}

		if selfAddress == "" {
			runtime.Error("ERROR: Couldn't determine the address for the acceptor.\n")
		}

		// Initialise the process-related resources.
		initProcess(fmt.Sprintf("acceptor-%d", *acceptorIndex), runPath)

		return

	}

	// Initialise the process-related resources.
	initProcess("live-server", runPath)

	// Ensure that the directory containing static files exists.
	staticPath := joinPath(instanceDirectory, *staticDirectory)
	dirInfo, err := os.Stat(staticPath)
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

	// Pre-format the Cache-Control header for static files.
	staticCache := fmt.Sprintf("public, max-age=%d", *staticMaxAge)
	staticMaxAge64 := int64(*staticMaxAge)

	// Exit if the directory containing the 50x.html files isn't present.
	errorPath := joinPath(instanceDirectory, *errorDirectory)
	dirInfo, err = os.Stat(errorPath)
	if err == nil {
		if !dirInfo.IsDirectory() {
			runtime.Error("ERROR: %q is not a directory\n", errorPath)
		}
	} else {
		runtime.StandardError(err)
	}

	// Load the content for the HTTP ``502`` and ``503`` errors.
	error500, error500Length = getErrorInfo(errorPath, "500.html")
	error502, error502Length = getErrorInfo(errorPath, "502.html")
	error503, error503Length = getErrorInfo(errorPath, "503.html")

	// Initialise the TLS config.
	tlsconf.Init()

	// Setup the file and console logging.
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
		logging.AddConsoleFilter(filterRequestLog)
	}

	_, err = logging.AddFileLogger("live-server", logPath, rotate, logging.InfoLog)
	if err != nil {
		runtime.Error("ERROR: Couldn't initialise logfile: %s\n", err)
	}

	_, err = logging.AddFileLogger("error", logPath, rotate, logging.ErrorLog)
	if err != nil {
		runtime.Error("ERROR: Couldn't initialise logfile: %s\n", err)
	}

	var liveMode bool

	// Setup the live support as long as it hasn't been disabled.
	if !*noLivequery {
		go handleLiveMessages()
		acceptorKey, err = ioutil.ReadFile(joinPath(instanceDirectory, *acceptorKeyPath))
		if err != nil {
			runtime.StandardError(err)
		}
		cookieKey, err = ioutil.ReadFile(joinPath(instanceDirectory, *cookieKeyPath))
		if err != nil {
			runtime.StandardError(err)
		}
		liveMode = true
		_ = *livequeryHost
		_ = *livequeryPort
		_ = *livequeryExpiry
		_ = *cookieName
		_ = *leaseExpiry
	}

	// Create a container for the Frontend instances.
	frontends := make([]*Frontend, 0)

	// Create a channel which is used to toggle the state of the live-server's
	// maintenance mode based on process signals.
	maintenanceChannel := make(chan bool, 1)

	// Fork a goroutine which toggles the maintenance mode in a single place and
	// thus ensures "thread safety".
	go func() {
		for {
			enabledState := <-maintenanceChannel
			for _, frontend := range frontends {
				if enabledState {
					frontend.maintenanceMode = true
				} else {
					frontend.maintenanceMode = false
				}
			}
		}
	}()

	// Register the signal handlers for SIGUSR1 and SIGUSR2.
	runtime.RegisterSignalHandler(signal.SIGUSR1, func() {
		maintenanceChannel <- true
	})

	runtime.RegisterSignalHandler(signal.SIGUSR2, func() {
		maintenanceChannel <- false
	})

	// Let the user know how many CPUs we're currently running on.
	fmt.Printf("Running live-server with %d CPUs:\n", runtime.CPUCount)

	// If ``--public-address`` hasn't been specified, generate it from the given
	// frontend host and base port values -- assuming ``localhost`` for a blank
	// host.
	publicAddr := *publicAddress
	if publicAddr == "" {
		if *frontendHost == "" {
			publicAddr = fmt.Sprintf("localhost:%d", *frontendPort)
		} else {
			publicAddr = fmt.Sprintf("%s:%d", *frontendHost, *frontendPort)
		}
	}

	// Setup and run the primary HTTPS Frontend.
	frontends = append(frontends, initFrontend("primary", *frontendHost,
		*frontendPort, publicAddr, *primaryHosts, *primaryCert, *primaryKey,
		*cometPrefix, *websocketPrefix, instanceDirectory, *upstreamHost,
		*upstreamPort, *upstreamTLS, *maintenanceMode, liveMode, staticCache,
		staticFiles, staticMaxAge64))

	// Setup and run the secondary HTTPS Frontend.
	if !*noSecondary {
		frontends = append(frontends, initFrontend("secondary", *frontendHost,
			*frontendPort+1, publicAddr, *secondaryHosts, *secondaryCert,
			*secondaryKey, *cometPrefix, *websocketPrefix, instanceDirectory,
			*upstreamHost, *upstreamPort, *upstreamTLS, *maintenanceMode,
			liveMode, staticCache, staticFiles, staticMaxAge64))
	}

	// Enter a wait loop if the HTTP Redirector has been disabled.
	if *noRedirect {
		loopForever := make(chan bool, 1)
		<-loopForever
	}

	// Otherwise, setup the HTTP Redirector.
	if *httpHost == "" {
		*httpHost = "localhost"
	}

	if *redirectURL == "" {
		*redirectURL = "https://" + publicAddr
	}

	httpAddr := fmt.Sprintf("%s:%d", *httpHost, *httpPort)
	httpListener, err := net.Listen("tcp", httpAddr)
	if err != nil {
		runtime.Error("ERROR: Cannot listen on %s: %v\n", httpAddr, err)
	}

	hsts := ""
	if *enableHSTS {
		hsts = fmt.Sprintf("max-age=%d", *hstsMaxAge)
	}

	redirector := &Redirector{
		hsts:     hsts,
		pingPath: *pingPath,
		url:      *redirectURL,
	}

	// Start a goroutine which runs the HTTP redirector.
	go func() {
		err = http.Serve(httpListener, redirector)
		if err != nil {
			runtime.Error("ERROR serving HTTP Redirector: %s\n", err)
		}
	}()

	fmt.Printf("* HTTP Redirector running on http://%s:%d -> %s\n",
		*httpHost, *httpPort, *redirectURL)

	// Enter the wait loop for the process to be killed.
	loopForever := make(chan bool, 1)
	<-loopForever

}
