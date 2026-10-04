// Package grpcclient — gRPC-клиенты к сервису LikeWhat (TobaccoService,
// ManufactureService, UserService, RecipeService).
package grpcclient

import (
	"context"
	"time"

	likewhat "github.com/Parnishkaspb/LikeWhat/pkg/like_what"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Clients объединяет клиентов всех сервисов из like_what.proto
// поверх одного gRPC-соединения.
type Clients struct {
	Conn        *grpc.ClientConn
	Tobacco     likewhat.TobaccoServiceClient
	Manufacture likewhat.ManufactureServiceClient
	User        likewhat.UserServiceClient
	Recipe      likewhat.RecipeServiceClient
	callTimeout time.Duration
}

// New создаёт клиентов gRPC-сервисов по адресу addr (например "localhost:50051").
// Соединение устанавливается лениво: GraphQL поднимется, даже если
// gRPC-бэкенд ещё не запущен, — ошибка проявится в конкретном запросе.
func New(ctx context.Context, addr string) (*Clients, error) {
	conn, err := grpc.NewClient(addr,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	)
	if err != nil {
		return nil, err
	}

	return &Clients{
		Conn:        conn,
		Tobacco:     likewhat.NewTobaccoServiceClient(conn),
		Manufacture: likewhat.NewManufactureServiceClient(conn),
		User:        likewhat.NewUserServiceClient(conn),
		Recipe:      likewhat.NewRecipeServiceClient(conn),
		callTimeout: 10 * time.Second,
	}, nil
}

// Close закрывает gRPC-соединение.
func (c *Clients) Close() error {
	return c.Conn.Close()
}

// CallCtx оборачивает ctx входящего запроса таймаутом на gRPC-вызов.
func (c *Clients) CallCtx(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, c.callTimeout)
}
