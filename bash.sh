#!/usr/bin/env bash
# ================================================================
#  SysManager v3.2 -- Disk & App Manager
#  Optimiert fuer: VS Code Terminal / WSL / Git Bash
# ================================================================

# ── Farben ───────────────────────────────────────────────────────
R='\033[0;31m'
G='\033[0;32m'
Y='\033[1;33m'
C='\033[0;36m'
W='\033[1;37m'
D='\033[2m'
B='\033[1m'
N='\033[0m'

# ── Logging ──────────────────────────────────────────────────────
LOG_FILE="$HOME/.sysmanager.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${*:2}" >> "$LOG_FILE"; }

# ================================================================
#  HILFSFUNKTIONEN
# ================================================================

ok()      { printf "  ${G}[OK]${N}  %s\n" "$1"; log "OK"   "$1"; }
err()     { printf "  ${R}[!!]${N}  %s\n" "$1"; log "ERR"  "$1"; }
info()    { printf "  ${C}[i]${N}   %s\n" "$1"; log "INFO" "$1"; }
warn()    { printf "  ${Y}[!]${N}   %s\n" "$1"; log "WARN" "$1"; }
enter()   { echo ""; printf "  ${D}[Enter druecken...]${N}\n"; read -r _; }
divider() { printf "  ${D}%s${N}\n" "$(printf -- '-%.0s' {1..56})"; }
section() { echo ""; printf "  ${Y}${B}>>> %s${N}\n" "$1"; echo ""; }

header() {
    clear
    echo ""
    printf "  ${C}${B}%s${N}\n" "+------------------------------------------------------+"
    printf "  ${C}${B}%s${N}\n" "|          SYSMANAGER v3.2  --  Disk & App            |"
    printf "  ${C}${B}%s${N}\n" "+------------------------------------------------------+"
    echo ""
}

confirm() {
    echo ""
    printf "  ${Y}%s${N}\n" "$1"
    printf "  Bestaetigen? [j/N]: "
    read -r ans
    [[ "$ans" =~ ^[jJyY]$ ]]
}

require_cmd() {
    command -v "$1" &>/dev/null || { err "'$1' nicht gefunden."; return 1; }
}

validate_path() {
    [[ -z "$1" ]] && { err "Kein Pfad angegeben.";        return 1; }
    [[ -e "$1" ]] || { err "Pfad existiert nicht: $1";    return 1; }
    [[ -r "$1" ]] || { err "Kein Lesezugriff auf: $1";    return 1; }
    return 0
}

detect_os() {
    [[ "$OSTYPE" == "darwin"* ]]  && { echo "macos";  return; }
    command -v apt    &>/dev/null && { echo "debian"; return; }
    command -v dnf    &>/dev/null && { echo "fedora"; return; }
    command -v pacman &>/dev/null && { echo "arch";   return; }
    echo "unknown"
}

OS=$(detect_os)

# ── Zentrale Paketmanager-Funktion ───────────────────────────────
run_pkg_manager() {
    local action="$1"
    local pkg="${2:-}"
    case "$OS:$action" in
        debian:info)
            dpkg -l "$pkg" 2>/dev/null | tail -1 \
                | awk '{printf "  Name:    %s\n  Version: %s\n", $2, $3}'
            dpkg -l "$pkg" &>/dev/null || warn "Nicht via dpkg gefunden."
            ;;
        debian:list)
            apt-mark showmanual 2>/dev/null | sort \
                | while IFS= read -r p; do
                    ver=$(dpkg -l "$p" 2>/dev/null | awk 'END{print $3}')
                    printf "  ${G}%-40s${N} ${D}%s${N}\n" "$p" "$ver"
                  done
            ;;
        debian:clean)
            sudo apt clean 2>/dev/null     && ok "apt cache geleert"
            sudo apt autoclean 2>/dev/null && ok "apt autoclean fertig"
            ;;
        debian:remove)
            sudo apt purge -y "$pkg" 2>/dev/null \
                && ok "apt purge erfolgreich" \
                || warn "Nicht via apt gefunden"
            sudo apt autoremove -y 2>/dev/null
            ;;
        arch:info)
            pacman -Qi "$pkg" 2>/dev/null \
                | grep -E "^Name|^Version|^Installed Size" \
                | while IFS= read -r l; do printf "  %s\n" "$l"; done
            ;;
        arch:list)
            pacman -Qe 2>/dev/null \
                | while IFS= read -r line; do printf "  ${G}%s${N}\n" "$line"; done
            ;;
        arch:clean)
            sudo pacman -Sc --noconfirm 2>/dev/null && ok "pacman cache geleert"
            ;;
        arch:remove)
            sudo pacman -Rns "$pkg" 2>/dev/null \
                && ok "pacman -Rns erfolgreich" \
                || warn "Nicht via pacman gefunden"
            ;;
        fedora:info)
            rpm -qi "$pkg" 2>/dev/null | head -5 \
                | while IFS= read -r l; do printf "  %s\n" "$l"; done
            ;;
        fedora:list)
            dnf list installed 2>/dev/null | tail -n +2 \
                | while IFS= read -r line; do printf "  ${G}%s${N}\n" "$line"; done
            ;;
        fedora:clean)
            sudo dnf clean all 2>/dev/null && ok "dnf cache geleert"
            ;;
        fedora:remove)
            sudo dnf remove -y "$pkg" 2>/dev/null \
                && ok "dnf remove erfolgreich" \
                || warn "Nicht via dnf gefunden"
            ;;
        macos:info)
            command -v brew &>/dev/null \
                && brew info "$pkg" 2>/dev/null | head -5 \
                | while IFS= read -r l; do printf "  %s\n" "$l"; done
            ;;
        macos:list)
            if command -v brew &>/dev/null; then
                brew list 2>/dev/null \
                    | while IFS= read -r p; do printf "  ${G}%s${N}\n" "$p"; done
            else
                warn "Homebrew nicht installiert"
            fi
            echo ""
            printf "  ${W}Apps in /Applications:${N}\n"
            echo ""
            ls /Applications/*.app 2>/dev/null \
                | while IFS= read -r app; do
                    printf "  ${C}%s${N}\n" "$(basename "$app" .app)"
                  done
            ;;
        macos:clean)
            command -v brew &>/dev/null \
                && brew cleanup 2>/dev/null && ok "brew cleanup fertig"
            ;;
        macos:remove)
            command -v brew &>/dev/null && {
                brew uninstall "$pkg" 2>/dev/null \
                    && ok "brew uninstall erfolgreich" \
                    || warn "Nicht via brew gefunden"
            }
            ;;
        *)
            warn "Aktion '$action' fuer OS '$OS' nicht unterstuetzt"
            ;;
    esac
}

# ================================================================
#  LOGIN
# ================================================================

PASSWORD_HASH="963bfa11b2dc4cb0303e360c8aa4c239542e93b03a4cd17cba834f1090ceb2a2"
MAX_VERSUCHE=3

login() {
    local versuche=0
    while (( versuche < MAX_VERSUCHE )); do
        clear
        echo ""
        printf "  ${C}${B}%s${N}\n" "+------------------------------------------------------+"
        printf "  ${C}${B}%s${N}\n" "|          SYSMANAGER v3.2  --  Login                 |"
        printf "  ${C}${B}%s${N}\n" "+------------------------------------------------------+"
        echo ""

        if (( versuche > 0 )); then
            printf "  ${R}[!!]  Falsches Passwort. Versuch %d von %d.${N}\n" "$versuche" "$MAX_VERSUCHE"
            echo ""
        fi

        printf "  Passwort: "
        read -rs eingabe
        echo ""

        local eingabe_hash
        eingabe_hash=$(echo -n "$eingabe" | sha256sum | cut -d' ' -f1)

        if [[ "$eingabe_hash" == "$PASSWORD_HASH" ]]; then
            echo ""
            ok "Anmeldung erfolgreich. Willkommen!"
            log "INFO" "Erfolgreiche Anmeldung"
            sleep 1
            return 0
        fi

        log "WARN" "Fehlgeschlagener Anmeldeversuch $((versuche + 1))"
        (( versuche++ ))
        sleep 1
    done

    echo ""
    err "Zu viele Fehlversuche. Zugriff verweigert."
    echo ""
    log "WARN" "Zugriff nach $MAX_VERSUCHE Fehlversuchen gesperrt"
    exit 1
}

# ================================================================
#  1 -- FESTPLATTEN ANZEIGEN
# ================================================================

show_disks() {
    header
    section "FESTPLATTEN UEBERSICHT"

    if [[ "$OS" == "macos" ]]; then
        require_cmd diskutil || { enter; return; }
        diskutil list
    else
        if require_cmd lsblk; then
            printf "  ${W}Laufwerke:${N}\n"
            echo ""
            printf "  ${D}%-20s %7s %-8s %-20s %-10s${N}\n" \
                "NAME" "SIZE" "TYPE" "MOUNTPOINT" "FSTYPE"
            divider
            lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE 2>/dev/null \
                | tail -n +2 \
                | while IFS= read -r line; do
                    name=$(  echo "$line" | awk '{print $1}')
                    size=$(  echo "$line" | awk '{print $2}')
                    type=$(  echo "$line" | awk '{print $3}')
                    mount=$( echo "$line" | awk '{print $4}')
                    fs=$(    echo "$line" | awk '{print $5}')
                    printf "  ${G}%-20s${N} ${W}%7s${N} ${C}%-8s${N} ${D}%-20s %-10s${N}\n" \
                        "$name" "$size" "$type" "$mount" "$fs"
                  done
        fi
    fi

    section "SPEICHERNUTZUNG"
    printf "  ${D}%-28s %7s %7s %7s %5s  %-20s${N}\n" \
        "Dateisystem" "Gesamt" "Belegt" "Frei" "%" "Mountpoint"
    divider

    df -h 2>/dev/null | grep -vE "tmpfs|udev|loop" | tail -n +2 \
        | while IFS= read -r line; do
            fs=$(    echo "$line" | awk '{print $1}')
            size=$(  echo "$line" | awk '{print $2}')
            used=$(  echo "$line" | awk '{print $3}')
            avail=$( echo "$line" | awk '{print $4}')
            pct=$(   echo "$line" | awk '{print $5}' | tr -d '%')
            mount=$( echo "$line" | awk '{print $6}')

            if   (( pct >= 90 )) 2>/dev/null; then
                printf "  \033[0;31m%-28s %7s %7s %7s %4s%%  %-20s\033[0m\n" \
                    "$fs" "$size" "$used" "$avail" "$pct" "$mount"
            elif (( pct >= 70 )) 2>/dev/null; then
                printf "  \033[1;33m%-28s %7s %7s %7s %4s%%  %-20s\033[0m\n" \
                    "$fs" "$size" "$used" "$avail" "$pct" "$mount"
            else
                printf "  \033[0;32m%-28s %7s %7s %7s %4s%%  %-20s\033[0m\n" \
                    "$fs" "$size" "$used" "$avail" "$pct" "$mount"
            fi
        done

    echo ""
    printf "  ${D}Legende:  ${R}>=90%% kritisch${N}  ${D}|  ${Y}>=70%% Warnung${N}  ${D}|  ${G}<70%% OK${N}\n"
    enter
}

# ================================================================
#  2 -- PARTITIONEN ANZEIGEN
# ================================================================

show_partitions() {
    header
    section "PARTITIONEN DETAIL"

    if [[ "$OS" == "macos" ]]; then
        diskutil list
        echo ""
        df -h | grep -v tmpfs
    else
        if require_cmd fdisk; then
            printf "  ${W}fdisk (benoetigt sudo):${N}\n"
            echo ""
            sudo fdisk -l 2>/dev/null | grep -E "^Disk |^/dev/" \
                | while IFS= read -r line; do
                    if [[ "$line" == Disk* ]]; then
                        printf "  ${C}${B}%s${N}\n" "$line"
                    else
                        printf "  ${W}  %s${N}\n" "$line"
                    fi
                done
        fi

        section "MOUNT-PUNKTE"
        printf "  ${D}%-22s  %-24s  %-10s${N}\n" "Partition" "Mountpoint" "Typ"
        divider
        mount | grep "^/dev" \
            | while IFS= read -r line; do
                part=$(  echo "$line" | awk '{print $1}')
                mount=$( echo "$line" | awk '{print $3}')
                type=$(  echo "$line" | awk '{print $5}')
                printf "  ${W}%-22s${N}  ${C}%-24s${N}  ${D}%-10s${N}\n" "$part" "$mount" "$type"
              done

        section "BLKID -- UUIDs und Typen"
        sudo blkid 2>/dev/null | while IFS= read -r line; do
            printf "  ${D}%s${N}\n" "$line"
        done
    fi

    enter
}

# ================================================================
#  3 -- SPEICHER-ANALYSE
# ================================================================

storage_analysis() {
    header
    section "SPEICHER-ANALYSE"

    printf "  ${C}[1]${N}  Home-Verzeichnis (~)\n"
    printf "  ${C}[2]${N}  Ganzes System (/)  -- langsamer\n"
    printf "  ${C}[3]${N}  Eigenen Pfad eingeben\n"
    printf "  ${R}[0]${N}  Zurueck\n"
    echo ""
    printf "  Auswahl: "
    read -r ch

    local path
    case $ch in
        1) path="$HOME" ;;
        2) path="/" ;;
        3) printf "  Pfad eingeben: "; read -r path ;;
        0) return ;;
        *) err "Ungueltige Auswahl"; enter; return ;;
    esac

    validate_path "$path" || { enter; return; }

    echo ""
    info "Analysiere: $path"
    echo ""

    section "TOP 20 -- GROESSTE VERZEICHNISSE"
    printf "  ${D}%-12s  %s${N}\n" "Groesse" "Verzeichnis"
    divider
    du -sh -- "$path"/*/  2>/dev/null | sort -rh | head -20 \
        | while IFS= read -r line; do
            size=$(awk '{print $1}' <<< "$line")
            dir=$( awk '{print $2}' <<< "$line")
            case "${size: -1}" in
                G) printf "  \033[0;31m\033[1m%-12s\033[0m  \033[1;37m%s\033[0m\n" "$size" "$dir" ;;
                M) printf "  \033[1;33m%-12s\033[0m  %s\n"                          "$size" "$dir" ;;
                *) printf "  \033[0;32m%-12s\033[0m  \033[2m%s\033[0m\n"            "$size" "$dir" ;;
            esac
        done

    section "TOP 10 -- GROESSTE DATEIEN"
    printf "  ${D}%-12s  %s${N}\n" "Groesse" "Datei"
    divider
    find "$path" -type f \
        -not -path "*/proc/*" \
        -not -path "*/sys/*" \
        2>/dev/null \
        | xargs du -sh 2>/dev/null \
        | sort -rh | head -10 \
        | while IFS= read -r line; do
            size=$(awk '{print $1}' <<< "$line")
            file=$(awk '{print $2}' <<< "$line")
            printf "  ${Y}%-12s${N}  %s\n" "$size" "$file"
          done

    enter
}

# ================================================================
#  4 -- INSTALLIERTE PROGRAMME
# ================================================================

list_programs() {
    header
    section "INSTALLIERTE PROGRAMME"

    printf "  ${D}%-40s  %s${N}\n" "Paketname" "Version"
    divider
    run_pkg_manager list
    echo ""

    if [[ "$OS" == "debian" ]]; then
        local total
        total=$(apt-mark showmanual 2>/dev/null | wc -l)
        info "Gesamt: $total manuell installierte Pakete"
    fi
    enter
}

# ================================================================
#  5 -- PROGRAMM KOMPLETT DEINSTALLIEREN
# ================================================================

uninstall_program() {
    header
    section "PROGRAMM KOMPLETT ENTFERNEN"

    printf "  Programmname eingeben: "
    read -r pkg

    if [[ -z "$pkg" ]]; then
        err "Kein Name eingegeben."
        enter; return
    fi

    if [[ "$pkg" =~ [[:space:]/\\\"\'\`\$\;\&\|\(\)\<\>] ]]; then
        err "Ungueltige Zeichen im Paketnamen: $pkg"
        log "SECURITY" "Ungueltiger Paketname abgelehnt: $pkg"
        enter; return
    fi

    echo ""
    info "Suche nach '$pkg' ..."
    log "INFO" "Deinstallation gestartet fuer: $pkg"

    section "[1/5]  PAKET-INFORMATIONEN"
    run_pkg_manager info "$pkg"

    section "[2/5]  ZUGEHOERIGE DATEIEN SUCHEN"

    declare -a found=()

    chk() {
        local target="$1"
        if [[ -e "$target" ]]; then
            local sz
            sz=$(du -sh -- "$target" 2>/dev/null | cut -f1)
            printf "  ${G}[GEFUNDEN]${N}  %-45s ${D}(%s)${N}\n" "$target" "$sz"
            found+=("$target")
        else
            printf "  ${D}[--]       %s${N}\n" "$target"
        fi
    }

    printf "  ${W}Konfigurationen:${N}\n"
    chk "$HOME/.config/$pkg"
    chk "$HOME/.$pkg"
    chk "$HOME/.${pkg}rc"
    chk "/etc/$pkg"
    chk "/etc/${pkg}.conf"
    chk "/etc/${pkg}.d"

    echo ""
    printf "  ${W}Cache und Daten:${N}\n"
    chk "$HOME/.cache/$pkg"
    chk "$HOME/.local/share/$pkg"
    chk "$HOME/.local/lib/$pkg"
    chk "/var/cache/$pkg"
    chk "/var/lib/$pkg"
    chk "/var/log/$pkg"
    chk "/var/log/${pkg}.log"

    echo ""
    printf "  ${W}Binaries und Bibliotheken:${N}\n"
    chk "/usr/bin/$pkg"
    chk "/usr/local/bin/$pkg"
    chk "/usr/lib/$pkg"
    chk "/usr/share/$pkg"
    chk "/usr/share/doc/$pkg"
    chk "/usr/share/man/man1/${pkg}.1"
    chk "/opt/$pkg"

    echo ""
    printf "  ${W}Systemd Services:${N}\n"
    chk "/etc/systemd/system/${pkg}.service"
    chk "/lib/systemd/system/${pkg}.service"
    chk "/usr/lib/systemd/system/${pkg}.service"

    echo ""
    divider
    info "Gefunden: ${#found[@]} Pfade mit Daten von '$pkg'"

    section "[3/5]  ZUSAMMENFASSUNG"

    if (( ${#found[@]} > 0 )); then
        printf "  ${Y}Folgende Pfade werden permanent geloescht:${N}\n"
        echo ""
        for p in "${found[@]}"; do
            local sz
            sz=$(du -sh -- "$p" 2>/dev/null | cut -f1)
            printf "  ${R}  ->  ${W}%-45s${N}  ${D}(%s)${N}\n" "$p" "$sz"
        done
    else
        printf "  ${D}  Keine zusaetzlichen Konfigurationsdateien gefunden.${N}\n"
    fi

    echo ""
    divider

    section "[4/5]  PAKET DEINSTALLIEREN"

    if ! confirm "Paket '$pkg' jetzt deinstallieren?"; then
        info "Abgebrochen."
        log "INFO" "Deinstallation von '$pkg' abgebrochen"
        enter; return
    fi

    echo ""
    printf "  ${C}Entferne Paket via Paketmanager ...${N}\n"
    echo ""
    run_pkg_manager remove "$pkg"

    for svc in \
        "/etc/systemd/system/${pkg}.service" \
        "/lib/systemd/system/${pkg}.service" \
        "/usr/lib/systemd/system/${pkg}.service"
    do
        if [[ -e "$svc" ]]; then
            echo ""
            printf "  ${C}Stoppe und deaktiviere systemd-Service ...${N}\n"
            sudo systemctl stop    "$pkg" 2>/dev/null && ok "Service gestoppt"
            sudo systemctl disable "$pkg" 2>/dev/null && ok "Service deaktiviert"
            break
        fi
    done

    section "[5/5]  KONFIGURATIONEN UND RESTE LOESCHEN"

    if (( ${#found[@]} == 0 )); then
        info "Keine Reste zu loeschen."
    else
        printf "  ${Y}Diese %d Pfade werden jetzt geloescht:${N}\n" "${#found[@]}"
        echo ""
        for p in "${found[@]}"; do
            printf "  ${D}  * %s${N}\n" "$p"
        done
        echo ""
        divider

        if confirm "Alle gefundenen Reste permanent loeschen?"; then
            echo ""
            local deleted=0 failed=0
            for p in "${found[@]}"; do
                [[ -e "$p" ]] || continue
                if sudo rm -rf -- "$p" 2>/dev/null; then
                    ok "Geloescht: $p"
                    log "OK" "Geloescht: $p"
                    (( deleted++ ))
                else
                    err "Fehler beim Loeschen: $p"
                    log "ERR" "Fehler beim Loeschen: $p"
                    (( failed++ ))
                fi
            done
            echo ""
            divider
            info "Geloescht: $deleted  |  Fehler: $failed"
        else
            info "Reste-Loeschung uebersprungen -- Paket dennoch deinstalliert."
            log "INFO" "Reste-Loeschung fuer '$pkg' uebersprungen"
        fi
    fi

    echo ""
    divider
    ok "'$pkg' wurde vollstaendig entfernt!"
    log "INFO" "Deinstallation von '$pkg' abgeschlossen"
    enter
}

# ================================================================
#  6 -- JUNK CLEANER
# ================================================================

junk_cleaner() {
    header
    section "JUNK CLEANER"

    printf "  ${C}[1]${N}  Alles bereinigen\n"
    printf "  ${C}[2]${N}  Package-Manager Cache\n"
    printf "  ${C}[3]${N}  Temp-Dateien (/tmp)\n"
    printf "  ${C}[4]${N}  Alte Logs (aelter als 7 Tage)\n"
    printf "  ${C}[5]${N}  Thumbnail-Cache\n"
    printf "  ${C}[6]${N}  Papierkorb\n"
    printf "  ${R}[0]${N}  Zurueck\n"
    echo ""
    printf "  Auswahl: "
    read -r ch

    local free_before
    free_before=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}')

    _clean_pkg() {
        confirm "Package-Manager Cache leeren?" || return
        echo ""
        run_pkg_manager clean
    }

    _clean_tmp() {
        confirm "/tmp und ~/.tmp leeren?" || return
        echo ""
        local sz
        sz=$(du -sh /tmp 2>/dev/null | cut -f1)
        sudo rm -rf /tmp/* 2>/dev/null
        ok "/tmp geleert  (war: $sz)"
        log "OK" "/tmp geleert (war: $sz)"
        if [[ -d "$HOME/.tmp" ]]; then
            rm -rf -- "$HOME/.tmp"/* 2>/dev/null
            ok "~/.tmp geleert"
        fi
    }

    _clean_logs() {
        confirm "Alte Logs loeschen (aelter als 7 Tage)?" || return
        echo ""
        if command -v journalctl &>/dev/null; then
            sudo journalctl --vacuum-time=7d 2>/dev/null
            ok "Systemlogs > 7 Tage geloescht"
            log "OK" "journalctl vacuum-time=7d"
        fi
        sudo find /var/log -name "*.gz" -o -name "*.old" -o -name "*.[0-9]" \
            -delete 2>/dev/null
        ok "Komprimierte und alte Logs geloescht"
    }

    _clean_thumbs() {
        confirm "Thumbnail-Cache leeren?" || return
        echo ""
        local sz
        sz=$(du -sh "$HOME/.cache/thumbnails" 2>/dev/null | cut -f1)
        rm -rf -- "$HOME/.cache/thumbnails"/* 2>/dev/null
        ok "Thumbnails geleert  (war: ${sz:-0})"
        log "OK" "Thumbnails geleert (war: ${sz:-0})"
    }

    _clean_trash() {
        confirm "Papierkorb dauerhaft leeren? (nicht wiederherstellbar)" || return
        echo ""
        local sz
        sz=$(du -sh "$HOME/.local/share/Trash" 2>/dev/null | cut -f1)
        rm -rf -- "$HOME/.local/share/Trash"/* "$HOME/.Trash"/* 2>/dev/null
        ok "Papierkorb geleert  (war: ${sz:-0})"
        log "OK" "Papierkorb geleert (war: ${sz:-0})"
    }

    case $ch in
        1)
            confirm "Wirklich ALLES bereinigen?" && {
                _clean_pkg; _clean_tmp; _clean_logs; _clean_thumbs; _clean_trash
            }
            ;;
        2) _clean_pkg ;;
        3) _clean_tmp ;;
        4) _clean_logs ;;
        5) _clean_thumbs ;;
        6) _clean_trash ;;
        0) return ;;
        *) err "Ungueltige Auswahl"; enter; return ;;
    esac

    local free_after
    free_after=$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
    echo ""
    divider
    printf "  ${C}[i]${N}   Freier Speicher  vorher: ${W}%s${N}  ->  nachher: ${W}%s${N}\n" \
        "$free_before" "$free_after"
    enter
}

# ================================================================
#  7 -- SYSTEM-INFORMATIONEN
# ================================================================

system_info() {
    header
    section "SYSTEM-INFORMATIONEN"

    divider
    _row() {
        printf "  ${D}%-20s${N}  ${G}%s${N}\n" "$1" "$2"
    }

    local os_name=""
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        os_name="$PRETTY_NAME"
    elif [[ "$OS" == "macos" ]]; then
        os_name="$(sw_vers -productName 2>/dev/null) $(sw_vers -productVersion 2>/dev/null)"
    fi

    _row "Betriebssystem:"  "${os_name:-unbekannt}"
    _row "Kernel:"          "$(uname -r)"

    local cpu=""
    if [[ "$OS" == "macos" ]]; then
        cpu=$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
    else
        cpu=$(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
        cpu="$cpu  ($(nproc 2>/dev/null || echo '?') Kerne)"
    fi
    _row "CPU:"             "${cpu:-unbekannt}"

    local ram=""
    if [[ "$OS" == "macos" ]]; then
        ram=$(sysctl -n hw.memsize 2>/dev/null \
            | awk '{printf "%.1f GB", $1/1024/1024/1024}')
    else
        ram=$(free -h 2>/dev/null \
            | awk '/Mem:/{printf "Gesamt: %s  |  Belegt: %s  |  Frei: %s", $2, $3, $4}')
    fi
    _row "RAM:"             "${ram:-unbekannt}"
    _row "Uptime:"          "$(uptime -p 2>/dev/null || uptime)"
    _row "Hostname:"        "$(hostname)"

    local ip=""
    if command -v ip &>/dev/null; then
        ip=$(ip -4 addr show \
            | awk '/inet / && !/127.0.0.1/{print $2}' \
            | paste -sd ' ')
    elif command -v ifconfig &>/dev/null; then
        ip=$(ifconfig \
            | awk '/inet / && !/127.0.0.1/{print $2}' \
            | paste -sd ' ')
    fi
    _row "IP (lokal):"      "${ip:--}"
    _row "Log-Datei:"       "$LOG_FILE"
    divider

    enter
}

# ================================================================
#  8 -- PC NEU STARTEN
# ================================================================

reboot_system() {
    header
    section "PC NEU STARTEN"

    printf "  ${Y}[!]${N}  Alle nicht gespeicherten Daten gehen verloren!\n"
    echo ""

    if ! confirm "PC jetzt wirklich neu starten?"; then
        info "Neustart abgebrochen."
        enter; return
    fi

    echo ""
    printf "  ${C}Starte in 3 Sekunden neu ...${N}\n"
    log "INFO" "Neustart ausgefuehrt"
    sleep 3

    if [[ "$OS" == "macos" ]]; then
        sudo shutdown -r now 2>/dev/null
    else
        sudo reboot 2>/dev/null || sudo shutdown -r now 2>/dev/null
    fi
}

# ================================================================
#  HAUPTMENUE
# ================================================================

main_menu() {
    while true; do
        header

        printf "  ${W}${B}Was moechtest du tun?${N}\n"
        echo ""
        printf "  ${C}[1]${N}  Festplatten anzeigen\n"
        printf "  ${C}[2]${N}  Partitionen anzeigen\n"
        printf "  ${C}[3]${N}  Speicher-Analyse\n"
        printf "  ${C}[4]${N}  Installierte Programme\n"
        printf "  ${C}[5]${N}  Programm komplett deinstallieren\n"
        printf "  ${C}[6]${N}  Junk Cleaner\n"
        printf "  ${C}[7]${N}  System-Informationen\n"
        printf "  ${C}[8]${N}  PC neu starten\n"
        echo ""
        divider
        printf "  ${R}[0]${N}  Beenden\n"
        echo ""
        printf "  Auswahl: "
        read -r ch

        case $ch in
            1) show_disks ;;
            2) show_partitions ;;
            3) storage_analysis ;;
            4) list_programs ;;
            5) uninstall_program ;;
            6) junk_cleaner ;;
            7) system_info ;;
            8) reboot_system ;;
            0)
                clear
                echo ""
                printf "  ${G}Tschuess!${N}\n"
                echo ""
                log "INFO" "SysManager beendet"
                exit 0
                ;;
            *)
                err "Ungueltige Eingabe -- bitte 0 bis 8 waehlen"
                sleep 1
                ;;
        esac
    done
}

# ================================================================
#  START
# ================================================================

if (( EUID != 0 )); then
    echo ""
    printf "  ${Y}[!]${N}  Tipp: Starte mit 'sudo bash sysmanager.sh' fuer alle Funktionen.\n"
    echo ""
    sleep 2
fi

log "INFO" "SysManager v3.2 gestartet (OS: $OS, EUID: $EUID)"
login
main_menu