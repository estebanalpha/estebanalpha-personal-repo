# Shared helpers for the shizuku-semi-auto commands. Sourced, never run.

: "${PREFIX:=/data/data/com.termux/files/usr}"
SA_HOME=/data/data/com.termux/files/home
SA_ADB="$PREFIX/bin/adb"
SA_TMP="$SA_HOME/.local/tmp"
SA_CONF="$SA_HOME/.config/shizuku-semi-auto/config"
SA_STATE_FILE="$SA_TMP/adb-serial.txt"
SA_WPORT_FILE="$SA_TMP/wireless-port.txt"
SA_FIXED_SERIAL="127.0.0.1:5555"

mkdir -p "$SA_TMP" 2>/dev/null

# --- language: one language per run, repo-wide convention ---
LANG_CONF="$PREFIX/etc/estebanalpha-repo/lang.conf"
if [ -f "$LANG_CONF" ]; then
    _LANG="$(cat "$LANG_CONF")"
else
    case "${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}" in
        es*) _LANG=es ;;
        *)   _LANG=en ;;
    esac
fi

# sa_t "spanish" "english" -> prints the text for the selected language
sa_t() { if [ "$_LANG" = es ]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }
sa_say() { printf '%s\n' "$(sa_t "$1" "$2")"; }

# --- configuration ---
sa_sdk() {
    local s
    s=$(/system/bin/getprop ro.build.version.sdk 2>/dev/null)
    case "$s" in ''|*[!0-9]*) s=0 ;; esac
    printf '%s' "$s"
}

sa_default_mode() {
    if [ "$(sa_sdk)" -ge 30 ]; then printf wireless; else printf cable; fi
}

# Reads KEY=value lines (no shell evaluation). Unknown keys are ignored.
sa_load_config() {
    local k v
    SA_MODE=""
    SA_PRIMING=auto
    SA_NOTIFY=1
    SA_PORT_APP="de.hohnepeople.keepadb"
    SA_PORT_PATTERN=""
    if [ -f "$SA_CONF" ]; then
        while IFS='=' read -r k v; do
            case "$k" in
                MODE)         SA_MODE="$v" ;;
                PRIMING)      SA_PRIMING="$v" ;;
                NOTIFY)       SA_NOTIFY="$v" ;;
                PORT_APP)     SA_PORT_APP="$v" ;;
                PORT_PATTERN) SA_PORT_PATTERN="$v" ;;
            esac
        done < "$SA_CONF"
    fi
    case "$SA_MODE" in wireless|cable) ;; *) SA_MODE="$(sa_default_mode)" ;; esac
    case "$SA_PRIMING" in auto|on|off) ;; *) SA_PRIMING=auto ;; esac
    return 0
}

# --- logging: consecutive identical messages are collapsed ---
# 1st and 2nd occurrence: one line each. From the 3rd on, the second line
# is rewritten with an "xN" suffix (N = repetitions after the first).
SA_LOG=""
SA_LAST_MSG=""
SA_LAST_N=0

sa_log_init() {
    SA_LOG="$1"
    : > "$SA_LOG"
    SA_LAST_MSG=""
    SA_LAST_N=0
}

sa_log() {
    local msg="$1" ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    if [ "$msg" = "$SA_LAST_MSG" ]; then
        SA_LAST_N=$((SA_LAST_N + 1))
        if [ "$SA_LAST_N" -ge 3 ]; then
            sed -i '$d' "$SA_LOG"
            printf '[%s] %s x%d\n' "$ts" "$msg" $((SA_LAST_N - 1)) >> "$SA_LOG"
        else
            printf '[%s] %s\n' "$ts" "$msg" >> "$SA_LOG"
        fi
    else
        SA_LAST_MSG="$msg"
        SA_LAST_N=1
        printf '[%s] %s\n' "$ts" "$msg" >> "$SA_LOG"
    fi
    if [ -t 1 ]; then printf '[%s] %s\n' "$ts" "$msg"; fi
    return 0
}

# sa_logt "spanish" "english"
sa_logt() { sa_log "$(sa_t "$1" "$2")"; }

# --- single instance + cleanup of background children ---
SA_LOCK_DIR=""

sa_cleanup() {
    local j
    j=$(jobs -p)
    [ -n "$j" ] && kill $j 2>/dev/null
    [ -n "$SA_LOCK_DIR" ] && rm -rf "$SA_LOCK_DIR"
    return 0
}

# sa_lock NAME -> 0 if acquired, 1 if another live instance holds it
sa_lock() {
    local name="$1" dir pid
    dir="$SA_TMP/$name.lock"
    if ! mkdir "$dir" 2>/dev/null; then
        pid=$(cat "$dir/pid" 2>/dev/null)
        if [ -n "$pid" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null \
            && tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q "$name"; then
            return 1
        fi
        rm -rf "$dir"
        mkdir "$dir" 2>/dev/null || return 1
    fi
    echo "$$" > "$dir/pid"
    SA_LOCK_DIR="$dir"
    trap sa_cleanup EXIT
    trap 'exit 143' TERM INT HUP
    return 0
}

# --- status notifications: one per state change, never repeated ---
# Needs Termux:API; silently does nothing without it or with NOTIFY=0.
declare -A SA_NSTATE

sa_notify_ready() {
    [ "$SA_NOTIFY" = 1 ] && command -v termux-notification >/dev/null 2>&1
}

# sa_notify_set ID STATE TITLE CONTENT
sa_notify_set() {
    local id="$1" state="$2"
    [ "${SA_NSTATE[$id]:-}" = "$state" ] && return 0
    SA_NSTATE[$id]="$state"
    sa_notify_ready || return 0
    timeout 10 termux-notification --id "$id" --title "$3" --content "$4" >/dev/null 2>&1
    return 0
}

sa_notify_clear() {
    local id="$1" prev="${SA_NSTATE[$id]:-}"
    SA_NSTATE[$id]=healthy
    case "$prev" in ''|healthy) return 0 ;; esac
    [ "$SA_NOTIFY" = 1 ] && command -v termux-notification-remove >/dev/null 2>&1 || return 0
    timeout 10 termux-notification-remove "$id" >/dev/null 2>&1
    return 0
}

# Everything is fine: an informational "restarted" notice stays until the
# user dismisses it; error notices are removed.
sa_notify_healthy() {
    local id="$1" prev="${SA_NSTATE[$id]:-}"
    case "$prev" in
        ''|healthy) ;;
        restarted) SA_NSTATE[$id]=healthy ;;
        *) sa_notify_clear "$id" ;;
    esac
    return 0
}

# --- adb helpers ---
sa_port_open() {
    timeout 1 bash -c "echo > /dev/tcp/127.0.0.1/$1" 2>/dev/null
}

# A real shell round-trip: "get-state" can report "device" with a frozen shell.
sa_alive() {
    [ "$(timeout 5 "$SA_ADB" -s "$1" shell echo ping 2>/dev/null)" = "ping" ]
}

# --- wireless debugging port discovery ---
# Candidate ports found in notifications, best first, one per line.
# Order: custom pattern, "Puerto"/"Port" followed by 4-5 digits, then (only
# for notifications that mention adb/debugging) any 5-digit number.
# Built-in patterns only accept the ephemeral range 32768-60999.
sa_notif_ports() {
    command -v termux-notification-list >/dev/null 2>&1 || return 1
    timeout 20 termux-notification-list 2>/dev/null \
        | PORT_APP="$SA_PORT_APP" PORT_PATTERN="$SA_PORT_PATTERN" awk '
        function val(s,   t) {
            t = s
            sub(/^[^:]*:[ \t]*"/, "", t)
            sub(/",?[ \t]*$/, "", t)
            gsub(/\\"/, "\"", t)
            return t
        }
        function add(list, run, lo, hi,   n) {
            n = run + 0
            if (n < lo || n > hi) return
            if (!(run in seen)) { seen[run] = 1; ord[list, ++cnt[list]] = run }
        }
        function runs(text, kwre, list,   rest, run) {
            while (match(text, kwre)) {
                rest = substr(text, RSTART + RLENGTH)
                if (match(rest, /^[0-9]+/)) {
                    run = substr(rest, RSTART, RLENGTH)
                    if (length(run) >= 4 && length(run) <= 5) add(list, run, 32768, 60999)
                }
                text = rest
            }
        }
        function any5(text, list,   run) {
            while (match(text, /[0-9]+/)) {
                run = substr(text, RSTART, RLENGTH)
                if (length(run) == 5) add(list, run, 32768, 60999)
                text = substr(text, RSTART + RLENGTH)
            }
        }
        function flush(   text, m, last, run) {
            if (pkg != "" && (app == "" || pkg == app)) {
                text = title " " content
                if (custom != "" && match(text, custom)) {
                    m = substr(text, RSTART, RLENGTH); last = ""
                    while (match(m, /[0-9]+/)) {
                        run = substr(m, RSTART, RLENGTH)
                        if (length(run) >= 4 && length(run) <= 5) last = run
                        m = substr(m, RSTART + RLENGTH)
                    }
                    if (last != "") add(1, last, 1024, 65535)
                }
                runs(text, "[Pp][Uu][Ee][Rr][Tt][Oo][^0-9]*", 2)
                runs(text, "[Pp][Oo][Rr][Tt][^0-9]*", 3)
                if (text ~ /[Aa][Dd][Bb]|[Dd][Ee][Pp][Uu][Rr][Aa]|[Dd][Ee][Bb][Uu][Gg]|[Ww][Ii][Rr][Ee][Ll][Ee][Ss][Ss]|[Ii][Nn][Aa][Ll]/) any5(text, 4)
            }
            pkg = ""; title = ""; content = ""
        }
        BEGIN { app = ENVIRON["PORT_APP"]; custom = ENVIRON["PORT_PATTERN"] }
        /"packageName":[ \t]*"/ { pkg = val($0); next }
        /"title":[ \t]*"/       { title = val($0); next }
        /"content":[ \t]*"/     { content = val($0); next }
        /^[ \t]*\},?[ \t]*$/    { flush(); next }
        END {
            flush()
            for (l = 1; l <= 4; l++) for (i = 1; i <= cnt[l]; i++) print ord[l, i]
        }'
}

# Connect to a wireless-debugging TLS port and confirm with a real shell.
sa_try_port() {
    local p="$1"
    timeout 8 "$SA_ADB" connect "127.0.0.1:$p" >/dev/null 2>&1
    sa_alive "127.0.0.1:$p" && return 0
    timeout 5 "$SA_ADB" disconnect "127.0.0.1:$p" >/dev/null 2>&1
    return 1
}

# Pin adbd to the fixed loopback port 5555 (independent of Wi-Fi) and save
# the serial the daemons should use. Falls back to the TLS port itself.
# Sets SA_PINNED (1/0) and SA_SERIAL_USED.
sa_pin_save() {
    local p="$1" tls="127.0.0.1:$1"
    timeout 8 "$SA_ADB" -s "$tls" tcpip 5555 >/dev/null 2>&1
    sleep 2
    timeout 10 "$SA_ADB" connect "$SA_FIXED_SERIAL" >/dev/null 2>&1
    if sa_alive "$SA_FIXED_SERIAL"; then
        SA_PINNED=1
        SA_SERIAL_USED="$SA_FIXED_SERIAL"
    else
        SA_PINNED=0
        SA_SERIAL_USED="$tls"
    fi
    echo "$SA_SERIAL_USED" > "$SA_STATE_FILE"
    echo "$p" > "$SA_WPORT_FILE"
}

# Non-interactive wireless connection: last known port (only if it still
# accepts connections), then ports read from notifications; at most 5 tries.
# Sets SA_WREASON (ok | no_port | connect_failed) and SA_WPORT.
sa_wireless_connect() {
    local cands="" p n=0
    SA_WREASON=no_port
    SA_WPORT=""
    if [ -s "$SA_WPORT_FILE" ]; then
        p=$(head -n1 "$SA_WPORT_FILE")
        case "$p" in ''|*[!0-9]*) ;; *) cands="$p" ;; esac
    fi
    for p in $(sa_notif_ports); do
        case " $cands " in *" $p "*) ;; *) cands="$cands $p" ;; esac
    done
    for p in $cands; do
        [ "$n" -ge 5 ] && break
        sa_port_open "$p" || continue
        n=$((n + 1))
        SA_WPORT="$p"
        SA_WREASON=connect_failed
        if sa_try_port "$p"; then
            sa_pin_save "$p"
            SA_WREASON=ok
            return 0
        fi
    done
    return 1
}
