package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.Handle("/", noCache(http.FileServer(http.Dir("public"))))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
		log.Printf("Defaulting to port %s", port)
	}

	log.Printf("Listening on port %s", port)
	log.Fatal(http.ListenAndServe(fmt.Sprintf(":%s", port), nil))
}

func noCache(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control","no-store")
		next.ServeHTTP(w, r)
	})
}
