// LikeWhatGraphQL — GraphQL-шлюз над gRPC-сервисом LikeWhat.
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/99designs/gqlgen/graphql/handler"
	"github.com/99designs/gqlgen/graphql/handler/transport"
	"github.com/99designs/gqlgen/graphql/playground"

	"github.com/Parnishkaspb/LikeWhatGraphQL/graph"
	"github.com/Parnishkaspb/LikeWhatGraphQL/internal/grpcclient"
)

func main() {
	addr := os.Getenv("GRPC_ADDR")
	if addr == "" {
		addr = "localhost:50051"
	}
	httpAddr := os.Getenv("HTTP_ADDR")
	if httpAddr == "" {
		httpAddr = ":8080"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	clients, err := grpcclient.New(ctx, addr)
	if err != nil {
		log.Fatalf("failed to connect to gRPC service at %s: %v", addr, err)
	}
	defer clients.Close()

	srv := handler.New(graph.NewExecutableSchema(graph.Config{Resolvers: &graph.Resolver{
		Clients: clients,
	}}))
	srv.AddTransport(transport.Options{})
	srv.AddTransport(transport.GET{})
	srv.AddTransport(transport.POST{})

	http.Handle("/query", srv)
	http.Handle("/", playground.Handler("LikeWhat GraphQL", "/query"))

	log.Printf("GraphQL playground: http://localhost%s/ (gRPC backend: %s)", httpAddr, addr)
	if err := http.ListenAndServe(httpAddr, nil); err != nil {
		log.Fatalf("http server: %v", err)
	}
}
