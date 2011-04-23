// Public Domain (-) 2010-2011 The Ampify Authors.
// See the Ampify UNLICENSE file for details.

// Live Server
// ===========
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
	"os/signal"
	"path/filepath"
	"strings"
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

// Constants for the different log event types.
const (
	HTTP_PING = iota
	HTTP_REDIRECT
	HTTPS_COMET
	HTTPS_MAINTENANCE
	HTTPS_PROXY_ERROR
	HTTPS_REDIRECT
	HTTPS_STATIC
	HTTPS_UPSTREAM
	HTTPS_WEBSOCKET
)

var (
	debugMode      bool
	error502       []byte
	error503       []byte
	error502Length string
	error503Length string
)

var (
	pingResponse       = []byte("pong")
	pingResponseLength = fmt.Sprintf("%d", len(pingResponse))
)

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

type Frontend struct {
	cometPrefix     string
	maintenance     bool
	officialHost    string
	redirectHTML    []byte
	redirectURL     string
	live            bool
	staticFiles     map[string]*StaticFile
	upstreamAddr    string
	upstreamHost    string
	upstreamTLS     bool
	websocketPrefix string
}

func (frontend *Frontend) ServeHTTP(conn http.ResponseWriter, req *http.Request) {

	originalHost := req.Host

	// Redirect all requests to the official host if the Host header doesn't
	// match.
	if originalHost != frontend.officialHost {
		conn.Header().Set("Location", frontend.redirectURL)
		conn.WriteHeader(http.StatusMovedPermanently)
		conn.Write(frontend.redirectHTML)
		logRequest(HTTPS_REDIRECT, http.StatusMovedPermanently, originalHost, req)
		return
	}

	// Return the HTTP 503 error page if we're in maintenance mode.
	if frontend.maintenance {
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
		headers := conn.Header()
		headers.Set(contentType, staticFile.mimetype)
		headers.Set(contentLength, staticFile.size)
		conn.WriteHeader(http.StatusOK)
		conn.Write(staticFile.content)
		logRequest(HTTPS_STATIC, http.StatusOK, originalHost, req)
		return
	}

	if frontend.live {

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
		if debugMode {
			fmt.Printf("Couldn't connect to remote %s: %v\n", frontend.upstreamHost, err)
		}
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
		if debugMode {
			fmt.Printf("Error writing to the upstream server: %v\n", err)
		}
		serveError502(conn, originalHost, req)
		return
	}

	// Parse the response from upstream.
	resp, err := http.ReadResponse(bufio.NewReader(upstream), req.Method)
	if err != nil {
		if debugMode {
			fmt.Printf("Error parsing response from upstream: %v\n", err)
		}
		serveError502(conn, originalHost, req)
		return
	}

	// Read the full response body.
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		if debugMode {
			fmt.Printf("Error reading response from upstream: %v\n", err)
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

	logRequest(HTTPS_UPSTREAM, resp.StatusCode, originalHost, req)

}

func handleWebSocket(conn *websocket.Conn) {
	defer func() {
		conn.Close()
		logRequest(HTTPS_WEBSOCKET, http.StatusOK, conn.Request.Host, conn.Request)
	}()
	if conn.Request.Header.Get("User-Agent") == "Safari" {
		fmt.Printf("boo")
	}
}

func logRequest(proto, status int, host string, request *http.Request) {
	var ip string
	splitPoint := strings.LastIndex(request.RemoteAddr, ":")
	if splitPoint == -1 {
		ip = request.RemoteAddr
	} else {
		ip = request.RemoteAddr[0:splitPoint]
	}
	logging.Info("ls", proto, status, request.Method, host, request.RawURL,
		ip, request.UserAgent, request.Referer)
}

func filterRequestLog(record *logging.Record) (write bool, data []interface{}) {
	items := record.Items
	itemLength := len(items)
	if itemLength > 1 {
		switch items[0].(type) {
		case string:
			if items[0].(string) == "ls" {
				return true, items[1 : itemLength-2]
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
	logRequest(HTTPS_PROXY_ERROR, http.StatusBadGateway, host, request)
}

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
		"Usage: live-server <config.yaml> [options]\n",
		"live-server 0.0.1")

	debug := opts.Bool([]string{"-d", "--debug"}, false,
		"enable debug mode")

	genConfig := opts.Bool([]string{"-g", "--gen-config"}, false,
		"show the default yaml config")

	frontendHost := opts.StringConfig("frontend-host", "",
		"the host to bind the HTTPS Frontend to")

	frontendPort := opts.IntConfig("frontend-port", 9040,
		"the port to bind the HTTPS Frontend to [9040]")

	officialHost := opts.StringConfig("official-host", "",
		"limit the HTTPS Frontend to the specified host")

	certFile := opts.StringConfig("cert-file", "cert/live-server.cert",
		"the path to the TLS certificate [cert/live-server.cert]")

	keyFile := opts.StringConfig("key-file", "cert/live-server.key",
		"the path to the TLS key [cert/live-server.key]")

	staticDirectory := opts.StringConfig("static-dir", "www",
		"the path to the static files directory [www]")

	errorDirectory := opts.StringConfig("error-dir", "error",
		"the path to the HTTP error files directory [error]")

	disableLive := opts.BoolConfig("disable-live", false,
		"disable the live Keyspace and WebSockets/Comet support [false]")

	websocketPrefix := opts.StringConfig("websocket-prefix", "/.ws/",
		"URL path prefix for WebSocket requests [/.ws/]")

	cometPrefix := opts.StringConfig("comet-prefix", "/.live/",
		"URL path prefix for Comet requests [/.live/]")

	redisConfig := opts.StringConfig("redis-conf", "redis.conf",
		"the path to the Redis config file [redis.conf]")

	redisSocket := opts.StringConfig("redis-socket", "run/redis.sock",
		"the path to the Redis Unix domain socket [run/redis.sock]")

	keyspaceHost := opts.StringConfig("keyspace-host", "",
		"the host to bind the Keyspace node to")

	keyspacePort := opts.IntConfig("keyspace-port", 9060,
		"the port to bind the Keyspace node to [9050]")

	keyspaceKey := opts.StringConfig("keyspace-keyfile", "cert/keyspace.key",
		"the path to the Keyspace shared secret key [cert/keyspace.key]")

	acceptors := opts.StringConfig("acceptor-nodes", "localhost:9060",
		"comma-separated list of Keyspace acceptor addresses [localhost:9060]")

	runAcceptor := opts.BoolConfig("run-as-acceptor", false,
		"run this node as a Keyspace acceptor [false]")

	acceptorIndex := opts.IntConfig("acceptor-index", 0,
		"this node's index in the Keyspace acceptor addresses list [0]")

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
	logPath := joinPath(instanceDirectory, "log")
	err = os.MkdirAll(logPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	// Create the run directory if it doesn't exist.
	runPath := joinPath(instanceDirectory, "run")
	err = os.MkdirAll(runPath, 0755)
	if err != nil {
		runtime.StandardError(err)
	}

	// Get the runtime lock to ensure we only have one live-server process
	// running within the same instance directory at any time.
	_, err = runtime.GetLock(runPath, "live-server")
	if err != nil {
		runtime.Error("ERROR: Couldn't successfully acquire a process lock:\n\n\t%s\n\n", err)
	}

	// Write the process ID into a file for use by external scripts.
	go runtime.CreatePidFile(filepath.Join(runPath, "live-server.pid"))

	// Handle running as a Keyspace acceptor node if ``--run-acceptor`` was
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

		return

	}

	// Exit if the ``cert-file`` or ``key-file`` config values haven't been
	// specified.
	var exitProcess bool
	if *certFile == "" {
		fmt.Printf("ERROR: The cert-file config value hasn't been specified.\n")
		exitProcess = true
	}
	if *keyFile == "" {
		fmt.Printf("ERROR: The key-file config value hasn't been specified.\n")
		exitProcess = true
	}
	if exitProcess {
		runtime.Exit(1)
	}

	// If ``--official-host`` hasn't been specified, generate it from the given
	// frontend host and port values -- assuming ``localhost`` for a blank host.
	if *officialHost == "" {
		if *frontendHost == "" {
			*officialHost = fmt.Sprintf("localhost:%d", *frontendPort)
		} else {
			*officialHost = fmt.Sprintf("%s:%d", *frontendHost, *frontendPort)
		}
	}

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
	error502, error502Length = getErrorInfo(errorPath, "502.html")
	error503, error503Length = getErrorInfo(errorPath, "503.html")

	// Initialise the Ampify runtime -- which will run ``live-server`` on
	// multiple processors if possible.
	runtime.Init()

	// Initialise the TLS config.
	tlsconf.Init()
	tlsConfig := &tls.Config{
		NextProtos: []string{"http/1.1"},
		Rand:       rand.Reader,
		Time:       time.Seconds,
	}

	// Load the certificate and private key into the TLS config.
	certPath := joinPath(instanceDirectory, *certFile)
	keyPath := joinPath(instanceDirectory, *keyFile)
	tlsConfig.Certificates = make([]tls.Certificate, 1)
	tlsConfig.Certificates[0], err = tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		runtime.Error("ERROR: Couldn't load certificate/key pair: %s\n", err)
	}

	// Instantiate the associated variables and listeners for the HTTPS Frontend
	// and HTTP Redirector.
	upstreamAddr := fmt.Sprintf("%s:%d", *upstreamHost, *upstreamPort)
	frontendAddr := fmt.Sprintf("%s:%d", *frontendHost, *frontendPort)
	frontendConn, err := net.Listen("tcp", frontendAddr)
	if err != nil {
		runtime.Error("ERROR: Cannot listen on %s: %v\n", frontendAddr, err)
	}

	frontendListener := tls.NewListener(frontendConn, tlsConfig)
	frontendURL := "https://" + *officialHost
	redirectHTML := []byte(fmt.Sprintf(redirectHTML, frontendURL))

	if *httpHost == "" {
		*httpHost = "localhost"
	}

	httpAddrURL := fmt.Sprintf("http://%s:%d", *httpHost, *httpPort)

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

	_, err = logging.AddFileLogger("live-server", logPath, rotate)
	if err != nil {
		runtime.Error("ERROR: Couldn't initialise logfile: %s\n", err)
	}

	var live bool

	// Setup the live support as long as it hasn't been disabled.
	if !*disableLive {
		_ = *keyspaceHost
		_ = *keyspacePort
		_ = *keyspaceKey
		_ = *redisConfig
		_ = *redisSocket
		live = true
	}

	// Instantiate a ``Frontend`` object for use by the HTTPS Frontend.
	frontend := &Frontend{
		cometPrefix:     *cometPrefix,
		live:            live,
		maintenance:     *maintenanceMode,
		officialHost:    *officialHost,
		redirectHTML:    redirectHTML,
		redirectURL:     frontendURL,
		staticFiles:     staticFiles,
		upstreamAddr:    upstreamAddr,
		upstreamHost:    *upstreamHost,
		upstreamTLS:     *upstreamTLS,
		websocketPrefix: *websocketPrefix,
	}

	// Create a channel which is used to toggle the state of the live-server's
	// maintenance mode based on process signals.
	maintenanceChannel := make(chan bool, 1)

	// Fork a goroutine which toggles the maintenance mode in a single place and
	// thus ensures "thread safety".
	go func() {
		for {
			enabledState := <-maintenanceChannel
			if enabledState {
				frontend.maintenance = true
			} else {
				frontend.maintenance = false
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

	// Start a goroutine which runs the HTTP redirector as long as it hasn't
	// been disabled.
	if !*noRedirect {
		hsts := ""
		if *enableHSTS {
			hsts = fmt.Sprintf("max-age=%d", *hstsMaxAge)
		}
		redirector := &Redirector{
			hsts:     hsts,
			pingPath: *pingPath,
			url:      *redirectURL,
		}
		go func() {
			err = http.Serve(httpListener, redirector)
			if err != nil {
				runtime.Error("ERROR serving HTTP Redirector: %s\n", err)
			}
		}()
		fmt.Printf("* HTTP Redirector running on %s -> %s\n", httpAddrURL, *redirectURL)
	}

	// Start the HTTPS Frontend.
	fmt.Printf("* HTTPS Frontend running on %s\n", frontendURL)
	err = http.Serve(frontendListener, frontend)
	if err != nil {
		runtime.Error("ERROR serving HTTPS Frontend: %s\n", err)
	}

}
