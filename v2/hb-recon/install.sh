#!/usr/bin/zsh

# We don't need return codes for "$(command)", only stdout is needed.
# Allow `[[ -n "$(command)" ]]`, `func "$(command)"`, pipes, etc.
# shellcheck disable=SC2312

set -u

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [[ -z "${ZSH_VERSION:-}" ]]
then
  abort "Zsh is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]
then
  abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]
then
  abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]
then
  abort 'Bash must not run in POSIX mode. Please unset POSIXLY_CORRECT and try again.'
fi

# Check for file that prevents Homebrew installation
if [[ -f "/etc/homebrew/brew.no_install" ]]
then
  BREW_NO_INSTALL="$(cat "/etc/homebrew/brew.no_install" 2>/dev/null)"
  if [[ -n "${BREW_NO_INSTALL}" ]]
  then
    abort "Homebrew cannot be installed because ${BREW_NO_INSTALL}."
  else
    abort "Homebrew cannot be installed because /etc/homebrew/brew.no_install exists!"
  fi
fi

require_harmonyos_at_least() {
    req_num=$1; req_sp=$2
    [ -n "$req_num" ] && [ -n "$req_sp" ] || abort "Internal error: require_harmonyos_at_least missing arguments."

    uname -s 2>/dev/null | grep -q HarmonyOS || return 0
    command -v param >/dev/null 2>&1 || return 0
    param >/dev/null 2>&1 || return 0

    # ver = last token, e.g. "6.1.0.117(SP68C00E100R13P3)"
    ver=$(param get const.product.software.version 2>/dev/null | awk '{print $NF}')
    [ -n "$ver" ] || abort "Error: empty version."

    # Split on '(' via sed
    num=$(printf '%s\n' "$ver" | sed 's/(.*//')
    sp=$(printf '%s\n' "$ver" | sed -n 's/.*(\([^)]*\)).*/\1/p')

    # Segment-wise compare num vs req_num
    cmp=$(
        a=$num; b=$req_num
        while :; do
            ah=$(printf '%s\n' "$a" | sed 's/\..*//')
            bh=$(printf '%s\n' "$b" | sed 's/\..*//')
            [ -z "$ah" ] && [ -z "$bh" ] && { printf eq; exit; }
            : ${ah:=0}; : ${bh:=0}
            [ "$ah" -gt "$bh" ] && { printf gt; exit; }
            [ "$ah" -lt "$bh" ] && { printf lt; exit; }
            a=$(printf '%s\n' "$a" | sed -n '1s/^[^.]*\.//p')
            b=$(printf '%s\n' "$b" | sed -n '1s/^[^.]*\.//p')
        done
    )

    [ "$cmp" = gt ] && return 0
    [ "$cmp" = lt ] && abort "System too old: ${ver} < ${req_num}(SP${req_sp})."

    # equal -> need SP keyword present and SP number >= req_sp
    case "$sp" in
        SP*) spn=$(printf '%s\n' "$sp" | sed -e 's/^SP//' -e 's/[^0-9].*//' -e 's/[^0-9]//g')
             [ -n "$spn" ] && [ "$spn" -ge "$req_sp" ] && return 0 ;;
    esac

    abort "System too old: ${ver} < ${req_num}(SP${req_sp})."
}

require_harmonyos_at_least "6.1.0.117" "68"

# string formatters
if [[ -t 1 ]]
then
  tty_escape() { printf "\033[%sm" "$1"; }
else
  tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"
  do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

chomp() {
  printf "%s" "${1/"$'\n'"/}"
}

ohai() {
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

warn() {
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

usage() {
  cat <<EOS
Homebrew Installer
Usage: [NONINTERACTIVE=1] [CI=1] install.sh [options]
    -h, --help       Display this message.
    NONINTERACTIVE   Install without prompting for user input
    CI               Install in CI mode (e.g. do not prompt for user input)
EOS
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]
do
  case "$1" in
    -h | --help) usage ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
  esac
done

# Check if script is run non-interactively (e.g. CI)
# If it is run non-interactively we should not prompt for passwords.
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -z "${NONINTERACTIVE-}" ]]
then
  if [[ -n "${CI-}" ]]
  then
    warn 'Running in non-interactive mode because `$CI` is set.'
    NONINTERACTIVE=1
  elif [[ ! -t 0 ]]
  then
    if [[ -z "${INTERACTIVE-}" ]]
    then
      warn 'Running in non-interactive mode because `stdin` is not a TTY.'
      NONINTERACTIVE=1
    else
      warn 'Running in interactive mode despite `stdin` not being a TTY because `$INTERACTIVE` is set.'
    fi
  fi
else
  ohai 'Running in non-interactive mode because `$NONINTERACTIVE` is set.'
fi

# First check OS.
OHOS_MUSL_LIBC="/lib/ld-musl-$(uname -m).so.1"
if [[ -f "${OHOS_MUSL_LIBC}" ]] && strings ${OHOS_MUSL_LIBC} 2>/dev/null | grep -q "OHOS" &>/dev/null
then
  OS="Linux"
  HOMEBREW_ON_OHOS=1
else
  abort "Harmonybrew is only supported on OpenHarmony and HarmonyOS"
fi

if [[ "${OS}" == "Linux" ]]
then
  HOMEBREW_ON_LINUX=1
elif [[ "${OS}" == "Darwin" ]]
then
  HOMEBREW_ON_MACOS=1
else
  abort "Homebrew is only supported on macOS and Linux."
fi

# Required installation paths. To install elsewhere (which is unsupported)
# you can untar https://github.com/Homebrew/brew/tarball/main
# anywhere you like.
if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
then
  UNAME_MACHINE="$(/usr/bin/uname -m)"

  if [[ "${UNAME_MACHINE}" == "arm64" ]]
  then
    # On ARM macOS, this script installs to /opt/homebrew only
    HOMEBREW_PREFIX="/opt/homebrew"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}"
  else
    # On Intel macOS, this script installs to /usr/local only
    HOMEBREW_PREFIX="/usr/local"
    HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  fi
  HOMEBREW_CACHE="${HOME}/Library/Caches/Homebrew"

  STAT_PRINTF=("/usr/bin/stat" "-f")
  PERMISSION_FORMAT="%A"
  CHOWN=("/usr/sbin/chown")
  CHGRP=("/usr/bin/chgrp")
  GROUP="admin"
  TOUCH=("/usr/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "root" -g "wheel" -m "0755")
elif [[ -n ${HOMEBREW_ON_OHOS} ]]
then
  UNAME_MACHINE="$(uname -m)"

  # On Linux, this script installs to /home/linuxbrew/.linuxbrew only
  HOMEBREW_PREFIX="/storage/Users/currentUser/.harmonybrew"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  CACHE_HOME="${XDG_CACHE_HOME:-${HOME}/.cache}"
  HOMEBREW_CACHE="${CACHE_HOME}/Homebrew"

  if [[ -n "${HOMEBREW_BOTTLE_DOMAIN-}" ]]
  then
    HOMEBREW_SERVER="${HOMEBREW_BOTTLE_DOMAIN%/*}"
  else
    HOMEBREW_SERVER="https://harmonybrew.atomgit.com"
  fi

  HOMEBREW_BREW_TAR="brew.tar.gz"
  HOMEBREW_BREW_TAR_REMOTE="${HOMEBREW_SERVER}/brew/${HOMEBREW_BREW_TAR}"
  HAVE_INSTALLED=""

  STAT_PRINTF=("/bin/stat" "-c")
  PERMISSION_FORMAT="%a"
  TOUCH=("/bin/touch")
  INSTALL=("/bin/install" -d -m "0755")
else
  UNAME_MACHINE="$(uname -m)"

  # On Linux, this script installs to /home/linuxbrew/.linuxbrew only
  HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  HOMEBREW_REPOSITORY="${HOMEBREW_PREFIX}/Homebrew"
  HOMEBREW_CACHE="${HOME}/.cache/Homebrew"

  STAT_PRINTF=("/usr/bin/stat" "-c")
  PERMISSION_FORMAT="%a"
  CHOWN=("/bin/chown")
  CHGRP=("/bin/chgrp")
  GROUP="$(id -gn)"
  TOUCH=("/bin/touch")
  INSTALL=("/usr/bin/install" -d -o "${USER}" -g "${GROUP}" -m "0755")
fi
CHMOD=("/bin/chmod")
MKDIR=("/bin/mkdir" "-p")
HOMEBREW_BREW_DEFAULT_GIT_REMOTE="https://atomgit.com/Harmonybrew/brew.git"
HOMEBREW_CORE_DEFAULT_GIT_REMOTE="https://atomgit.com/Harmonybrew/homebrew-core.git"

# Use remote URLs of Homebrew repositories from environment if set.
HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_GIT_REMOTE:-"${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}"}"
HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_CORE_GIT_REMOTE:-"${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}"}"
# The URLs with and without the '.git' suffix are the same Git remote. Do not prompt.
if [[ "${HOMEBREW_BREW_GIT_REMOTE}" == "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}.git" ]]
then
  HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}"
fi
if [[ "${HOMEBREW_CORE_GIT_REMOTE}" == "${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}.git" ]]
then
  HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}"
fi
export HOMEBREW_{BREW,CORE}_GIT_REMOTE

# TODO: bump version when new macOS is released or announced
MACOS_NEWEST_UNSUPPORTED="27.0"
# TODO: bump version when new macOS is released
MACOS_OLDEST_SUPPORTED="14.0"

# For Homebrew on Linux
REQUIRED_RUBY_VERSION=3.4    # https://github.com/Homebrew/brew/pull/19779
REQUIRED_GLIBC_VERSION=2.13  # https://docs.brew.sh/Homebrew-on-Linux#requirements
REQUIRED_CURL_VERSION=7.41.0 # HOMEBREW_MINIMUM_CURL_VERSION in brew.sh in Homebrew/brew
REQUIRED_GIT_VERSION=2.7.0   # HOMEBREW_MINIMUM_GIT_VERSION in brew.sh in Homebrew/brew

# no analytics during installation
export HOMEBREW_NO_ANALYTICS_THIS_RUN=1
export HOMEBREW_NO_ANALYTICS_MESSAGE_OUTPUT=1

unset HAVE_SUDO_ACCESS # unset this from the environment

have_sudo_access() {
  if [[ -n "${HOMEBREW_ON_OHOS}" ]]
  then
    return 1
  fi

  if [[ ! -x "/bin/sudo" ]]
  then
    return 1
  fi

  local -a SUDO=("/bin/sudo")
  if [[ -n "${SUDO_ASKPASS-}" ]]
  then
    SUDO+=("-A")
  elif [[ -n "${NONINTERACTIVE-}" ]]
  then
    SUDO+=("-n")
  fi

  if [[ -z "${HAVE_SUDO_ACCESS-}" ]]
  then
    if [[ -n "${NONINTERACTIVE-}" ]]
    then
      "${SUDO[@]}" -l mkdir &>/dev/null
    else
      "${SUDO[@]}" -v && "${SUDO[@]}" -l mkdir &>/dev/null
    fi
    HAVE_SUDO_ACCESS="$?"
  fi

  if [[ -n "${HOMEBREW_ON_MACOS-}" ]] && [[ "${HAVE_SUDO_ACCESS}" -ne 0 ]]
  then
    abort "Need sudo access on macOS (e.g. the user ${USER} needs to be an Administrator)!"
  fi

  return "${HAVE_SUDO_ACCESS}"
}

execute() {
  if ! "$@"
  then
    abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
  fi
}

retry() {
  local tries="$1" n="$1" pause=2
  shift
  if ! "$@"
  then
    while [[ $((--n)) -gt 0 ]]
    do
      warn "$(printf "Trying again in %d seconds: %s" "${pause}" "$(shell_join "$@")")"
      sleep "${pause}"
      ((pause *= 2))
      if "$@"
      then
        return
      fi
    done
    abort "$(printf "Failed %d times doing: %s" "${tries}" "$(shell_join "$@")")"
  fi
}

execute_sudo() {
  local -a args=("$@")
  if [[ "${EUID:-${UID}}" != "0" ]] && have_sudo_access
  then
    if [[ -n "${SUDO_ASKPASS-}" ]]
    then
      args=("-A" "${args[@]}")
    fi
    ohai "/bin/sudo" "${args[@]}"
    execute "/bin/sudo" "${args[@]}"
  else
    ohai "${args[@]}"
    execute "${args[@]}"
  fi
}

getc() {
  local save_state
  save_state="$(/bin/stty -g)"
  /bin/stty raw -echo
  IFS='' read -r -n 1 -d '' "$@"
  /bin/stty "${save_state}"
}

ring_bell() {
  # Use the shell's audible bell.
  if [[ -t 1 ]]
  then
    printf "\a"
  fi
}

wait_for_user() {
  local c
  echo
  echo "Press ${tty_bold}RETURN${tty_reset}/${tty_bold}ENTER${tty_reset} to continue or any other key to abort:"
  getc c
  # we test for \r and \n because some stuff does \r instead
  if ! [[ "${c}" == $'\r' || "${c}" == $'\n' ]]
  then
    exit 1
  fi
}

major_minor() {
  echo "${1%%.*}.$(
    x="${1#*.}"
    echo "${x%%.*}"
  )"
}

version_gt() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
}
version_ge() {
  [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -ge "${2#*.}" ]]
}
version_lt() {
  [[ "${1%.*}" -lt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -lt "${2#*.}" ]]
}

check_run_command_as_root() {
  [[ "${HOMEBREW_ON_OHOS}" == "0" ]] || return
  [[ "${EUID:-${UID}}" == "0" ]] || return

  # Allow Azure Pipelines/GitHub Actions/Docker/Concourse/Kubernetes to do everything as root (as it's normal there)
  [[ -f /.dockerenv ]] && return
  [[ -f /run/.containerenv ]] && return
  [[ -f /proc/1/cgroup ]] && grep -E "azpl_job|actions_job|docker|garden|kubepods" -q /proc/1/cgroup && return

  abort "Don't run this as root!"
}

should_install_command_line_tools() {
  if [[ -n "${HOMEBREW_ON_LINUX-}" ]]
  then
    return 1
  fi

  if version_gt "${macos_version}" "10.13"
  then
    ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]
  else
    ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]] ||
      ! [[ -e "/usr/include/iconv.h" ]]
  fi
}

get_permission() {
  "${STAT_PRINTF[@]}" "${PERMISSION_FORMAT}" "$1"
}

user_only_chmod() {
  [[ -d "$1" ]] && [[ "$(get_permission "$1")" != 75[0145] ]]
}

exists_but_not_writable() {
  [[ -e "$1" ]] && ! [[ -r "$1" && -w "$1" && -x "$1" ]]
}

# Please sync with 'test_ruby()' in 'Library/Homebrew/utils/ruby.sh' from the Homebrew/brew repository.
test_ruby() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  "$1" --enable-frozen-string-literal --disable=gems,did_you_mean,rubyopt -rrubygems -e \
    "abort if Gem::Version.new(RUBY_VERSION) < \
              Gem::Version.new('${REQUIRED_RUBY_VERSION}')" 2>/dev/null
}

test_curl() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  if [[ "$1" == "/snap/bin/curl" ]]
  then
    warn "Ignoring $1 (curl snap is too restricted)"
    return 1
  fi

  local curl_version_output curl_name_and_version
  curl_version_output="$("$1" --version 2>/dev/null)"
  curl_name_and_version="${curl_version_output%% \(*}"
  version_ge "$(major_minor "${curl_name_and_version##* }")" "$(major_minor "${REQUIRED_CURL_VERSION}")"
}

test_git() {
  if [[ ! -x "$1" ]]
  then
    return 1
  fi

  local git_version_output
  git_version_output="$("$1" --version 2>/dev/null)"
  if [[ "${git_version_output}" =~ "git version "([^ ]*).* ]]
  then
    version_ge "$(major_minor "${BASH_REMATCH[1]:-${match[1]}}")" "$(major_minor "${REQUIRED_GIT_VERSION}")"
  else
    abort "Unexpected Git version: '${git_version_output}'!"
  fi
}

# Search for the given executable in PATH (avoids a dependency on the `which` command)
which() {
  # Alias to Bash built-in command `type -P`
  whence -p "$@"
}

# Search PATH for the specified program that satisfies Homebrew requirements
# function which is set above
# shellcheck disable=SC2230
find_tool() {
  if [[ $# -ne 1 ]]
  then
    return 1
  fi

  local executable
  while read -r executable
  do
    if [[ "${executable}" != /* ]]
    then
      warn "Ignoring ${executable} (relative paths don't work)"
    elif "test_$1" "${executable}"
    then
      echo "${executable}"
      break
    fi
  done < <(which -a "$1")
}

no_usable_ruby() {
  [[ -z "$(find_tool ruby)" ]] || ! ruby -e "require 'erb'"
}

outdated_glibc() {
  local glibc_version
  glibc_version="$(ldd --version | head -n1 | grep -o '[0-9.]*$' | grep -o '^[0-9]\+\.[0-9]\+')"
  version_lt "${glibc_version}" "${REQUIRED_GLIBC_VERSION}"
}

if [[ -n "${HOMEBREW_ON_LINUX-}" && -z "${HOMEBREW_ON_OHOS}" ]] && no_usable_ruby
then
  if outdated_glibc
  then
    abort "$(
      cat <<EOABORT
Homebrew requires Ruby ${REQUIRED_RUBY_VERSION} which was not found on your system.
Homebrew portable Ruby requires Glibc version ${REQUIRED_GLIBC_VERSION} or newer,
and your Glibc version is too old. See:
  ${tty_underline}https://docs.brew.sh/Homebrew-on-Linux#requirements${tty_reset}
Please install Ruby ${REQUIRED_RUBY_VERSION} and add its location to your PATH.
EOABORT
    )"
  else
    export HOMEBREW_FORCE_VENDOR_RUBY=1
  fi
fi

# Things can fail later if `pwd` doesn't exist.
# Also sudo prints a warning message for no good reason
cd "$HOME" || exit 1

####################################################################### script

HOMEBREW_CORE="${HOMEBREW_REPOSITORY}/Library/Taps/harmonybrew/homebrew-core"

check_run_command_as_root

if [[ -d "${HOMEBREW_PREFIX}" && ! -x "${HOMEBREW_PREFIX}" ]]
then
  abort "$(
    cat <<EOABORT
The Homebrew prefix ${tty_underline}${HOMEBREW_PREFIX}${tty_reset} exists but is not searchable.
If this is not intentional, please restore the default permissions and
try running the installer again:
    sudo chmod 775 ${HOMEBREW_PREFIX}
EOABORT
  )"
fi

if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
then
  # On macOS, support 64-bit Intel and ARM
  if [[ "${UNAME_MACHINE}" != "arm64" ]] && [[ "${UNAME_MACHINE}" != "x86_64" ]]
  then
    abort "Homebrew is only supported on Intel and ARM processors!"
  fi
else
  if [[ "${UNAME_MACHINE}" != "x86_64" ]] && [[ "${UNAME_MACHINE}" != "aarch64" ]]
  then
    abort "Homebrew on Linux is only supported on Intel x86_64 and ARM64 processors!"
  fi
fi

if [[ -n "${HOMEBREW_ON_MACOS-}" ]]
then
  macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"
  if version_lt "${macos_version}" "10.7"
  then
    abort "$(
      cat <<EOABORT
Your Mac OS X version is too old. See:
  ${tty_underline}https://github.com/mistydemeo/tigerbrew${tty_reset}
EOABORT
    )"
  elif version_lt "${macos_version}" "10.11"
  then
    abort "Your OS X version is too old."
  elif version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}" ||
       version_lt "${macos_version}" "${MACOS_OLDEST_SUPPORTED}"
  then
    who="We"
    what=""
    if version_ge "${macos_version}" "${MACOS_NEWEST_UNSUPPORTED}"
    then
      what="pre-release version"
    else
      who+=" (and Apple)"
      what="old version"
    fi
    ohai "You are using macOS ${macos_version}."
    ohai "${who} do not provide support for this ${what}."

    echo "$(
      cat <<EOS
This installation may not succeed.
After installation, you will encounter build failures with some formulae.
Please create pull requests instead of asking for help on Homebrew\'s GitHub,
Twitter or any other official channels. You are responsible for resolving any
issues you experience while you are running this ${what}.
EOS
    )
" | tr -d "\\"
  fi
fi

# Check if Homebrew is installed on OHOS.
if [[ -n ${HOMEBREW_ON_OHOS} && -f "${HOMEBREW_REPOSITORY}/bin/brew" ]]
then
  abort "Homebrew is already installed. Please uninstall the old version first."
fi

ohai "This script will install:"
echo "${HOMEBREW_PREFIX}/bin/brew"
echo "${HOMEBREW_PREFIX}/share/doc/homebrew"
echo "${HOMEBREW_PREFIX}/share/man/man1/brew.1"
echo "${HOMEBREW_PREFIX}/share/zsh/site-functions/_brew"
echo "${HOMEBREW_PREFIX}/etc/bash_completion.d/brew"
echo "${HOMEBREW_REPOSITORY}"

# Keep relatively in sync with
# https://github.com/Homebrew/brew/blob/HEAD/Library/Homebrew/keg.rb
directories=(
  bin etc include lib sbin share opt var
  Frameworks
  etc/bash_completion.d lib/pkgconfig
  share/aclocal share/doc share/info share/locale share/man
  share/man/man1 share/man/man2 share/man/man3 share/man/man4
  share/man/man5 share/man/man6 share/man/man7 share/man/man8
  var/log var/homebrew var/homebrew/linked
  bin/brew
)
group_chmods=()
for dir in "${directories[@]}"
do
  if exists_but_not_writable "${HOMEBREW_PREFIX}/${dir}"
  then
    group_chmods+=("${HOMEBREW_PREFIX}/${dir}")
  fi
done

# zsh refuses to read from these directories if group writable
directories=(share/zsh share/zsh/site-functions)
zsh_dirs=()
for dir in "${directories[@]}"
do
  zsh_dirs+=("${HOMEBREW_PREFIX}/${dir}")
done

directories=(
  bin etc include lib sbin share var opt
  share/zsh share/zsh/site-functions
  var/homebrew var/homebrew/linked
  Cellar Caskroom Frameworks
)
mkdirs=()
for dir in "${directories[@]}"
do
  if ! [[ -d "${HOMEBREW_PREFIX}/${dir}" ]]
  then
    mkdirs+=("${HOMEBREW_PREFIX}/${dir}")
  fi
done

user_chmods=()
mkdirs_user_only=()
if [[ "${#zsh_dirs[@]}" -gt 0 ]]
then
  for dir in "${zsh_dirs[@]}"
  do
    if [[ ! -d "${dir}" ]]
    then
      mkdirs_user_only+=("${dir}")
    elif user_only_chmod "${dir}"
    then
      user_chmods+=("${dir}")
    fi
  done
fi

chmods=()
if [[ "${#group_chmods[@]}" -gt 0 ]]
then
  chmods+=("${group_chmods[@]}")
fi
if [[ "${#user_chmods[@]}" -gt 0 ]]
then
  chmods+=("${user_chmods[@]}")
fi

if [[ "${#mkdirs[@]}" -gt 0 ]]
then
  ohai "The following new directories will be created:"
  printf "%s\n" "${mkdirs[@]}"
fi

if should_install_command_line_tools
then
  ohai "The Xcode Command Line Tools will be installed."
fi

non_default_repos=""
additional_shellenv_commands=()
if [[ "${HOMEBREW_BREW_DEFAULT_GIT_REMOTE}" != "${HOMEBREW_BREW_GIT_REMOTE}" ]]
then
  ohai "HOMEBREW_BREW_GIT_REMOTE is set to a non-default URL:"
  echo "${tty_underline}${HOMEBREW_BREW_GIT_REMOTE}${tty_reset} will be used as the Homebrew/brew Git remote."
  non_default_repos="Homebrew/brew"
  additional_shellenv_commands+=("export HOMEBREW_BREW_GIT_REMOTE=\"${HOMEBREW_BREW_GIT_REMOTE}\"")
fi

if [[ "${HOMEBREW_CORE_DEFAULT_GIT_REMOTE}" != "${HOMEBREW_CORE_GIT_REMOTE}" ]]
then
  ohai "HOMEBREW_CORE_GIT_REMOTE is set to a non-default URL:"
  echo "${tty_underline}${HOMEBREW_CORE_GIT_REMOTE}${tty_reset} will be used as the Homebrew/homebrew-core Git remote."
  non_default_repos="${non_default_repos:-}${non_default_repos:+ and }Homebrew/homebrew-core"
  additional_shellenv_commands+=("export HOMEBREW_CORE_GIT_REMOTE=\"${HOMEBREW_CORE_GIT_REMOTE}\"")
fi

if [[ -n "${HOMEBREW_NO_INSTALL_FROM_API-}" ]]
then
  ohai "HOMEBREW_NO_INSTALL_FROM_API is set."
  echo "Homebrew/homebrew-core will be tapped during this ${tty_bold}install${tty_reset} run."
fi

if [[ -z "${NONINTERACTIVE-}" ]]
then
  ring_bell
  #wait_for_user
fi

if ! [[ -d "${HOMEBREW_PREFIX}" ]]
then
  execute_sudo "${INSTALL[@]}" "${HOMEBREW_PREFIX}"
fi

if [[ "${#mkdirs[@]}" -gt 0 ]]
then
  execute_sudo "${MKDIR[@]}" "${mkdirs[@]}"
  execute_sudo "${CHMOD[@]}" "ug=rwx" "${mkdirs[@]}"
  if [[ "${#mkdirs_user_only[@]}" -gt 0 ]]
  then
    execute_sudo "${CHMOD[@]}" "go-w" "${mkdirs_user_only[@]}"
  fi
fi

if ! [[ -d "${HOMEBREW_REPOSITORY}" ]]
then
  execute_sudo "${MKDIR[@]}" "${HOMEBREW_REPOSITORY}"
fi

if ! [[ -d "${HOMEBREW_CACHE}" ]]
then
  execute "${MKDIR[@]}" "${HOMEBREW_CACHE}"
fi
if exists_but_not_writable "${HOMEBREW_CACHE}"
then
  execute_sudo "${CHMOD[@]}" "g+rwx" "${HOMEBREW_CACHE}"
fi
if [[ -d "${HOMEBREW_CACHE}" ]]
then
  execute "${TOUCH[@]}" "${HOMEBREW_CACHE}/.cleaned"
fi

if should_install_command_line_tools && version_ge "${macos_version}" "10.13"
then
  ohai "Searching online for the Command Line Tools"
  # This temporary file prompts the 'softwareupdate' utility to list the Command Line Tools
  clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  execute_sudo "${TOUCH[@]}" "${clt_placeholder}"

  clt_label_command="/usr/sbin/softwareupdate -l |
                      grep -B 1 -E 'Command Line Tools' |
                      awk -F'*' '/^ *\\*/ {print \$2}' |
                      sed -e 's/^ *Label: //' -e 's/^ *//' |
                      sort -V |
                      tail -n1"
  clt_label="$(chomp "$(/bin/bash -c "${clt_label_command}")")"

  if [[ -n "${clt_label}" ]]
  then
    ohai "Installing ${clt_label}"
    execute_sudo "/usr/sbin/softwareupdate" "-i" "${clt_label}"
    execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
  fi
  execute_sudo "/bin/rm" "-f" "${clt_placeholder}"
fi

# Headless install may have failed, so fallback to original 'xcode-select' method
if should_install_command_line_tools && test -t 0
then
  ohai "Installing the Command Line Tools (expect a GUI popup):"
  execute "/usr/bin/xcode-select" "--install"
  echo "Press any key when the installation has completed."
  getc
  execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools"
fi

if [[ -n "${HOMEBREW_ON_MACOS-}" ]] && ! output="$(/usr/bin/xcrun clang 2>&1)" && [[ "${output}" == *"license"* ]]
then
  abort "$(
    cat <<EOABORT
You have not agreed to the Xcode license.
Before running the installer again please agree to the license by opening
Xcode.app or running:
    sudo xcodebuild -license
EOABORT
  )"
fi

if ! command -v curl >/dev/null
then
  abort "$(
    cat <<EOABORT
You must install cURL before installing Homebrew. See:
  ${tty_underline}https://docs.brew.sh/Installation${tty_reset}
EOABORT
  )"
elif [[ -n "${HOMEBREW_ON_LINUX-}" ]]
then
  USABLE_CURL="$(find_tool curl)"
  if [[ -z "${USABLE_CURL}" ]]
  then
    abort "$(
      cat <<EOABORT
The version of cURL that was found does not satisfy requirements for Homebrew.
Please install cURL ${REQUIRED_CURL_VERSION} or newer and add it to your PATH.
EOABORT
    )"
  elif [[ "${USABLE_CURL}" != /usr/bin/curl ]]
  then
    export HOMEBREW_CURL_PATH="${USABLE_CURL}"
    ohai "Found cURL: ${HOMEBREW_CURL_PATH}"
  fi
fi

# try connect to server
details=$(curl --silent --show-error --connect-timeout 5 ${HOMEBREW_SERVER} 2>&1)
if [[ $? -ne 0 ]]; then
    abort "$(
      cat <<EOABORT
Error: Failed to connect to Harmonybrew server.
details:
${details}
EOABORT
    )"
fi

(
  [[ ! -f ${HOMEBREW_REPOSITORY}/bin/brew ]] || return 
  ohai "Downloading and installing Homebrew by curl..."
  cd "${HOMEBREW_PREFIX}" >/dev/null || return

  CURL_HEAD_ARGS=(
    "-s"
    "-I"
    "-o" "/dev/null"
    "-w" "%{http_code}\n"
  )
  "${USABLE_CURL}" "${CURL_HEAD_ARGS[@]}" "${HOMEBREW_BREW_TAR_REMOTE}" | grep -q "200"
  [[ $? == 0 ]] || return

  CURL_ARGS=(
  "--cookie" "/dev/null"
  "--globoff"
  "--fail"
  "--remote-time"
  "--location"
  "--compressed"
  "--speed-limit" "100"
  "--speed-time" "5"
  "--show-error"
  )
  "${USABLE_CURL}" "${CURL_ARGS[@]}" "-o" "${HOMEBREW_BREW_TAR}" "${HOMEBREW_BREW_TAR_REMOTE}"

  if [[ -f "${HOMEBREW_BREW_TAR}" ]]
  then
    if tar zxf "${HOMEBREW_BREW_TAR}" > /dev/null 2>&1
    then
      [[ -d "${HOMEBREW_REPOSITORY}" ]] && rm -rf "${HOMEBREW_REPOSITORY}"
      execute "mv" "brew" "Homebrew"
      execute "ln" "-sf" "${HOMEBREW_REPOSITORY}/bin/brew" "${HOMEBREW_PREFIX}/bin/brew"
    else
      [[ -d "brew" ]] && rm -rf "brew"
    fi
    
    rm "${HOMEBREW_BREW_TAR}"
  fi
)

if [[ -f "${HOMEBREW_REPOSITORY}/bin/brew" ]]
then
  HAVE_INSTALLED=1
fi

USABLE_GIT=/usr/bin/git
if [[ -n "${HOMEBREW_ON_LINUX-}" && -z "${HAVE_INSTALLED}" ]]
then
  USABLE_GIT="$(find_tool git)"
  if [[ -z "$(command -v git)" ]]
  then
    abort "$(
      cat <<EOABORT
  You must install Git before installing Homebrew. See:
    ${tty_underline}https://docs.brew.sh/Installation${tty_reset}
EOABORT
    )"
  fi
  if [[ -z "${USABLE_GIT}" ]]
  then
    abort "$(
      cat <<EOABORT
  The version of Git that was found does not satisfy requirements for Homebrew.
  Please install Git ${REQUIRED_GIT_VERSION} or newer and add it to your PATH.
EOABORT
    )"
  fi
  if [[ "${USABLE_GIT}" != /usr/bin/git ]]
  then
    export HOMEBREW_GIT_PATH="${USABLE_GIT}"
    ohai "Found Git: ${HOMEBREW_GIT_PATH}"
  fi
fi

(
  # check brew have installed by curl
  [[ -z "${HAVE_INSTALLED}" ]] || return 0
  ohai "Downloading and installing Homebrew by git..."
 
  # install brew by git
  cd "${HOMEBREW_REPOSITORY}" >/dev/null || return

  # we do it in four steps to avoid merge errors when reinstalling
  execute "${USABLE_GIT}" "-c" "init.defaultBranch=main" "init" "--quiet"

  # "git remote add" will fail if the remote is defined in the global config
  execute "${USABLE_GIT}" "config" "remote.origin.url" "${HOMEBREW_BREW_GIT_REMOTE}"
  execute "${USABLE_GIT}" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"
  execute "${USABLE_GIT}" "config" "--bool" "fetch.prune" "true"

  # ensure we don't munge line endings on checkout
  execute "${USABLE_GIT}" "config" "--bool" "core.autocrlf" "false"

  # make sure symlinks are saved as-is
  execute "${USABLE_GIT}" "config" "--bool" "core.symlinks" "true"

  if [[ -z "${NONINTERACTIVE-}" ]]
  then
    quiet_progress=("--quiet" "--progress")
  else
    quiet_progress=("--quiet")
  fi
  retry 5 "${USABLE_GIT}" "fetch" "${quiet_progress[@]}" "--force" "origin"
  retry 5 "${USABLE_GIT}" "fetch" "${quiet_progress[@]}" "--force" "--tags" "origin"

  execute "${USABLE_GIT}" "remote" "set-head" "origin" "--auto" >/dev/null

  LATEST_GIT_TAG="$("${USABLE_GIT}" -c "column.ui=never" tag --list --sort="-version:refname" | head -n1)"
  if [[ -z "${LATEST_GIT_TAG}" ]]
  then
    abort "Failed to query latest Homebrew/brew Git tag."
  fi
  execute "${USABLE_GIT}" "checkout" "--quiet" "--force" "-B" "stable" "${LATEST_GIT_TAG}"

  if [[ "${HOMEBREW_REPOSITORY}" != "${HOMEBREW_PREFIX}" ]]
  then
    if [[ "${HOMEBREW_REPOSITORY}" == "${HOMEBREW_PREFIX}/Homebrew" ]]
    then
      execute "ln" "-sf" "../Homebrew/bin/brew" "${HOMEBREW_PREFIX}/bin/brew"
    else
      abort "The Homebrew/brew repository should be placed in the Homebrew prefix directory."
    fi
  fi

  if [[ -n "${HOMEBREW_NO_INSTALL_FROM_API-}" && ! -d "${HOMEBREW_CORE}" ]]
  then
    # Always use single-quoted strings with `exp` expressions
    # shellcheck disable=SC2016
    ohai 'Tapping homebrew/core because `$HOMEBREW_NO_INSTALL_FROM_API` is set.'
    (
      execute "${MKDIR[@]}" "${HOMEBREW_CORE}"
      cd "${HOMEBREW_CORE}" >/dev/null || return

      execute "${USABLE_GIT}" "-c" "init.defaultBranch=main" "init" "--quiet"
      execute "${USABLE_GIT}" "config" "remote.origin.url" "${HOMEBREW_CORE_GIT_REMOTE}"
      execute "${USABLE_GIT}" "config" "remote.origin.fetch" "+refs/heads/*:refs/remotes/origin/*"
      execute "${USABLE_GIT}" "config" "--bool" "fetch.prune" "true"
      execute "${USABLE_GIT}" "config" "--bool" "core.autocrlf" "false"
      execute "${USABLE_GIT}" "config" "--bool" "core.symlinks" "true"
      retry 5 "${USABLE_GIT}" "fetch" "--force" "${quiet_progress[@]}" \
        "origin" "refs/heads/main:refs/remotes/origin/main"
      execute "${USABLE_GIT}" "remote" "set-head" "origin" "--auto" >/dev/null
      execute "${USABLE_GIT}" "reset" "--hard" "origin/main"

      cd "${HOMEBREW_REPOSITORY}" >/dev/null || return
    ) || exit 1
  fi
) || exit 1

(
  if [[ ":${PATH}:" != *":${HOMEBREW_PREFIX}/bin:"* ]]
  then
    PATH_WARN=1
  fi

  execute "zsh" "${HOMEBREW_PREFIX}/bin/brew" "update" "--force"

  if [[ -n "${PATH_WARN-}" ]]
  then
    warn "${HOMEBREW_PREFIX}/bin is not in your PATH.
  Instructions on how to configure your shell for Homebrew
  can be found in the 'Next steps' section below."
  fi
) || exit 1

ohai "Installation successful!"
echo

ring_bell

(
  [[ -z "${HAVE_INSTALLED}" ]] || return 0
  cd "${HOMEBREW_REPOSITORY}" >/dev/null || return
  execute "${USABLE_GIT}" "config" "--replace-all" "homebrew.analyticsmessage" "false"
  execute "${USABLE_GIT}" "config" "--replace-all" "homebrew.caskanalyticsmessage" "false"
) || exit 1

ohai "Next steps:"
SHELL=$(realpath /proc/$PPID/exe)
case "${SHELL}" in
  */bash*)
    shell_rcfile="${HOME}/.bashrc"
    ;;
  */zsh*)
    shell_rcfile="${ZDOTDIR:-"${HOME}"}/.zshrc"
    ;;
  */fish*)
    shell_rcfile="${HOME}/.config/fish/config.fish"
    ;;
  */sh*)
    shell_rcfile="${HOME}/.mkshrc"
    ;;
  *)
    shell_rcfile="${ENV:-"${HOME}/.profile"}"
    ;;
esac

if grep -qs "eval \"\$(${HOMEBREW_PREFIX}/bin/brew shellenv)\"" "${shell_rcfile}"
then
  if ! [[ -x "$(command -v brew)" ]]
  then
    cat <<EOS
- Run this command in your terminal to add Homebrew to your ${tty_bold}PATH${tty_reset}:
    eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
EOS
  fi
else
  cat <<EOS
- Run these commands in your terminal to add Homebrew to your ${tty_bold}PATH${tty_reset}:
    echo >> ${shell_rcfile}
    echo 'eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"' >> ${shell_rcfile}
    eval "\$(${HOMEBREW_PREFIX}/bin/brew shellenv)"
EOS
fi

if [[ -n "${non_default_repos}" ]]
then
  plural=""
  if [[ "${#additional_shellenv_commands[@]}" -gt 1 ]]
  then
    plural="s"
  fi
  printf -- "- Run these commands in your terminal to add the non-default Git remote%s for %s:\n" "${plural}" "${non_default_repos}"
  printf "    echo '# Set non-default Git remote%s for %s.' >> %s\n" "${plural}" "${non_default_repos}" "${shell_rcfile}"
  printf "    echo '%s' >> ${shell_rcfile}\n" "${additional_shellenv_commands[@]}"
  printf "    %s\n" "${additional_shellenv_commands[@]}"
fi
