package main

import (
	//"encoding/json"
	"fmt"
	"io"
	//"io/ioutil"
	"net/http"
	//"os"
	"strings"
)
import circleci "github.com/ryanlower/go-circleci"

const TPL = "https://circle-artifacts.com/gh/FedericoCeratto/nim-ci/%d/artifacts/0/home/ubuntu/nim-ci/output/"

const http_redirect_cache_seconds = 10

var last_circleci_build_path = ""

func fetchBuildNum() {
	client := circleci.NewClient("")
	builds := client.RecentBuilds("FedericoCeratto", "nim-ci")
	for _, b := range builds {
		if b.Status == "success" {
			n := builds[0].Number
			last_circleci_build_path = fmt.Sprintf(TPL, n)
			println(fmt.Sprintf("Last build number: %d", n))
			println(fmt.Sprintf("Last build status: %s", b.Status))
			return
		}
	}
}

func hello(w http.ResponseWriter, r *http.Request) {
	io.WriteString(w, "Hello world!")
}

type myHandler struct{}

func (*myHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	path := r.URL.String()
	var url = ""
	if path == "/" {
		url = last_circleci_build_path + "nimble_install_report.html"
	} else {
		s := strings.Split(path, "/")
        // Path convention:
        //   <pkg_name> / version.svg
        //   <pkg_name> / [nimdevel|nimstable] / [status.svg|output.html]
		if len(s) == 4 {
			pkg_name, nim_kind, artifact := s[1], s[2], s[3]
			url = last_circleci_build_path + fmt.Sprintf("%s/%s/%s", pkg_name, nim_kind, artifact)
		}
	}

	if url == "" {
		io.WriteString(w, "Unexpected path.")
	} else {
		println("Redirecting " + path + " to " + url)
		http.Redirect(w, r, url, 307)  // Temporary redirect
	}
}

func main() {
	fetchBuildNum()
	server := http.Server{
		Addr:    "127.0.0.1:8702",
		Handler: &myHandler{},
		//ReadTimeout:    1 * time.Second,
		//WriteTimeout:   1 * time.Second,
		MaxHeaderBytes: 1 << 20,
	}

	server.ListenAndServe()
}
