#!/usr/bin/env bash
# Синхронизация proto-файлов по пинам из protodeps.yaml.
#
# Использование:
#   ./scripts/sync-proto.sh                          # сверить и при отличиях обновить proto
#   ./scripts/sync-proto.sh set-commit <name> <sha>  # обновить пин коммита у entry <name>
#
# Логи пишутся в stderr, на stdout печатается "changed" или "unchanged" —
# Makefile использует это, чтобы пропустить генерацию, если proto не менялся.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPS_FILE="$ROOT/protodeps.yaml"
CACHE_DIR="$ROOT/.protocache"

log() { echo "$*" >&2; }

# Парсим protodeps.yaml в строки "name|repo|file|commit|local|path"
# (yaml простой, поэтому обходимся без yq).
parse_deps() {
  awk '
    /^[[:space:]]*(#|$)/ { next }
    {
      line = $0
      if (line ~ /-[[:space:]]*name:/) {
        if (name != "") flush()
        name = trim(substr(line, index(line, ":") + 1))
        repo = ""; file = ""; commit = ""; local = ""; path = ""
      } else if (line ~ /^[[:space:]]*repo:/)   { repo   = trim(substr(line, index(line, ":") + 1)) }
      else if (line ~ /^[[:space:]]*file:/)     { file   = trim(substr(line, index(line, ":") + 1)) }
      else if (line ~ /^[[:space:]]*commit:/)   { commit = trim(substr(line, index(line, ":") + 1)) }
      else if (line ~ /^[[:space:]]*local:/)    { local  = trim(substr(line, index(line, ":") + 1)) }
      else if (line ~ /^[[:space:]]*path:/)     { path   = trim(substr(line, index(line, ":") + 1)) }
    }
    function trim(s) {
      sub(/[[:space:]]+#.*$/, "", s)   # отрезаем inline-комментарий после значения
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
      return s
    }
    function flush() { print name "|" repo "|" file "|" commit "|" local "|" path }
    END { if (name != "") flush() }
  ' "$DEPS_FILE"
}

# sync_entry <name> <repo> <file> <commit> <local> <path>
# Код возврата: 0 — proto обновлён, 1 — совпадает с пином.
sync_entry() {
  local name="$1" repo="$2" file="$3" commit="$4" local_path="$5" src_path="$6"
  local tmp new_hash old_hash

  if [[ -n "$src_path" ]]; then
    # Режим локального источника (proto лежит в соседнем чекауте) — без сети.
    if [[ ! -f "$ROOT/$src_path" ]]; then
      log "✗ $name: локальный источник $src_path не найден"
      exit 1
    fi
    tmp="$ROOT/$src_path"
  else
    local cache="$CACHE_DIR/$name"
    if [[ ! -d "$cache/.git" ]]; then
      log "→ $name: клонирую $repo ..."
      git clone --quiet "$repo" "$cache"
    else
      git -C "$cache" fetch --quiet --all --tags
    fi
    if ! git -C "$cache" cat-file -e "${commit}^{commit}" 2>/dev/null; then
      log "✗ $name: коммит $commit не найден в $repo (fetch --all --tags уже выполнен)"
      exit 1
    fi
    tmp="$cache/$name.proto"
    git -C "$cache" show "$commit:$file" > "$tmp"
  fi

  new_hash="$(shasum -a 256 "$tmp" | awk '{print $1}')"
  old_hash="$(shasum -a 256 "$ROOT/$local_path" 2>/dev/null | awk '{print $1}' || true)"

  if [[ -f "$ROOT/$local_path" && "$old_hash" == "$new_hash" ]]; then
    log "✓ $name: proto совпадает с пином $commit — обновление не требуется"
    return 1
  fi

  mkdir -p "$(dirname "$ROOT/$local_path")"
  cp "$tmp" "$ROOT/$local_path"
  local pin_info=""
  [[ -n "$commit" ]] && pin_info=" (пин $commit)"
  log "↻ $name: proto обновлён$pin_info"
  return 0
}

# set_commit <name> <sha> — переписываем commit внутри блока с этим name.
set_commit() {
  local name="$1" sha="$2" tmp="$DEPS_FILE.tmp"
  trap 'rm -f "$tmp"' RETURN
  awk -v name="$name" -v commit="$sha" '
    {
      line = $0
      if (line ~ /-[[:space:]]*name:/) {
        cur = line; sub(/.*name:[[:space:]]*/, "", cur)
        inblock = (cur == name)
      }
      if (inblock && line ~ /^[[:space:]]*commit:/) {
        print "    commit: " commit
        next
      }
      print line
    }
  ' "$DEPS_FILE" > "$tmp" && mv "$tmp" "$DEPS_FILE"
  trap - RETURN
}

any_changed=0
case "${1:-}" in
  set-commit)
    [[ $# -eq 3 ]] || { log "usage: $0 set-commit <name> <sha>"; exit 1; }
    set_commit "$2" "$3"
    log "✓ пин коммита для '$2' обновлён: $3"
    any_changed=1
    ;;
esac

while IFS='|' read -r name repo file commit local_path src_path; do
  [[ -z "$name" ]] && continue
  if sync_entry "$name" "$repo" "$file" "$commit" "$local_path" "$src_path"; then
    any_changed=1
  fi
done < <(parse_deps)

if [[ "$any_changed" -eq 1 ]]; then
  echo "changed"
else
  echo "unchanged"
fi
