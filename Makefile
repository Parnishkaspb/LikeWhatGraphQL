MODULE      := github.com/Parnishkaspb/LikeWhatGraphQL
PROTO_FILES := $(wildcard *.proto)
# Для каждого like_what.proto кладём сгенерированное в pkg/like_what,
# независимо от go_package, прописанного в исходном proto.
GO_MFLAGS   := $(foreach f,$(PROTO_FILES),\
                 --go_opt=M$(f)=$(MODULE)/pkg/$(basename $(f)) \
                 --go-grpc_opt=M$(f)=$(MODULE)/pkg/$(basename $(f)))

.PHONY: generate proto-update

## generate: сверить proto с пинами и перегенерировать код, только если proto изменился
generate:
	@state=$$(./scripts/sync-proto.sh) || exit 1; \
	if [ "$$state" != "changed" ]; then \
		echo "==> proto не изменились, генерация пропущена"; \
		exit 0; \
	fi; \
	echo "==> proto обновлены: protoc + gqlgen"; \
	protoc --go_out=. --go_opt=module=$(MODULE) \
		--go-grpc_out=. --go-grpc_opt=module=$(MODULE) \
		$(GO_MFLAGS) $(PROTO_FILES); \
	go run github.com/99designs/gqlgen generate; \
	echo "==> генерация завершена"

## proto-update: поднять пин коммита и перегенерировать (make proto-update COMMIT=<sha>)
proto-update:
	@test -n "$(COMMIT)" || { echo "usage: make proto-update COMMIT=<sha> [NAME=like_what]"; exit 1; }
	@./scripts/sync-proto.sh set-commit "$(NAME)" "$(COMMIT)" >/dev/null
	@$(MAKE) generate
