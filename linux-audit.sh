#!/bin/bash
# linux-audit v0.0.1
# Lazily wraps various Linux system auditing tools.
# Intended for personal use. Use at own risk.
# Don't run this on production systems.
#
# ~ bcoles 2019
set -euo pipefail
IFS=$'\n\t'

umask 0077

readonly _rel="$(dirname "$(readlink -f "$0")")"
readonly _tools_directory="${_rel}/tools"
readonly _logs_directory="${_rel}/logs"
readonly _audit_name="$(hostname)-$(date +%Y%m%d%H%M%S)-linux-audit"
readonly _audit_directory="${_logs_directory}/${_audit_name}"

readonly _version="0.0.1"

# Enable automatic updating of dependencies
readonly _update_deps="true"

function info() { echo -e "\\033[1;34m[*]\\033[0m  $*"; }
function warn() { echo -e "\\033[1;33m[!]\\033[0m  $*"; }
function error() { echo -e "\\033[1;31m[-]\\033[0m  $*"; exit 1 ; }

function __main__() {
  echo -e "--[ \\033[1;32mlinux-audit v${_version}\\033[0m ]--"
  echo

  setup

  audit

  info "Complete"
}

function audit() {
  mkdir -p "${_audit_directory}"

  echo
  info "Date:\t$(date)"
  info "Hostname:\t$(hostname)"
  info "System:\t$(uname -a)"
  info "User:\t$(id)"
  info "Log:\t${_audit_directory}"
  echo

  if [ "$(id -u)" -eq 0 ]; then
    check_priv
  else
    check_pentest
  fi
}

function command_exists () {
  command -v "${1}" >/dev/null 2>&1
}

function setup() {
  mkdir -p "${_tools_directory}"

  info "Checking dependencies..."

  if ! command_exists git ; then
    error "git is not in \$PATH"
  fi

  if ! command_exists python3 ; then
    warn "python3 is not in \$PATH! Some checks will be skipped ..."
  fi

  set +e
  IFS=' ' read -r -d '' -a array <<'_EOF_'
https://github.com/mzet-/linux-exploit-suggester
https://github.com/CISOfy/lynis
https://github.com/bcoles/so-check
https://github.com/sokdr/LinuxAudit
https://github.com/initstring/uptux
https://github.com/lateralblast/lunar
https://github.com/diego-treitos/linux-smart-enumeration
https://github.com/a13xp0p0v/kconfig-hardened-check
https://github.com/bcoles/jalesc
https://github.com/rebootuser/LinEnum
https://github.com/trimstray/otseca
https://github.com/inquisb/unix-privesc-check
https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite
_EOF_
  set -e

  while read -r repo; do
    tool=${repo##*/}

    [ -z "${repo}" ] && continue

    if [ -d "${_tools_directory}/${tool}" ]; then
      if [ "${_update_deps}" = "true" ]; then
        info "Updating ${tool} ..."
        bash -c "cd ${_tools_directory}/${tool}; git pull"
      fi
    else
      info "Fetching ${tool} ..."
      git clone "${repo}" "${_tools_directory}/${tool}"
    fi
  done <<< "${array}"

  #if command_exists "apt-get"; then
  #  # Debian / Ubuntu
  #  apt-get -y install libopenscap8
  #elif command_exists "yum" ; then
  #  # CentOS / RHEL
  #  yum -y install openscap-scanner scap-security-guide
  #elif command_exists "dnf"; then
  #  # Fedora
  #  dnf -y install openscap-scanner
  #fi
}

function check_pentest() {

  info "Running unprivileged checks..."
  echo

  info "Running linux-exploit-suggester..."
  bash "${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh" --checksec | tee "${_audit_directory}/les-checksec.log"
  bash "${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh" | tee "${_audit_directory}/les.log"

  info "Running lynis..."
  cd "${_tools_directory}/lynis" || exit
  "${_tools_directory}/lynis/lynis" --pentest --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
  cd "${_rel}" || exit

  info "Running so-check..."
  bash "${_tools_directory}/so-check/so-check.sh" | tee "${_audit_directory}/so-check.log"

  info "Running LinuxAudit..."
  bash "${_tools_directory}/LinuxAudit/LinuxAudit.sh" | tee "${_audit_directory}/LinuxAudit.log"

  if command_exists python3 ; then
    info "Running kconfig-hardened-check..."
    python3 "${_tools_directory}/kconfig-hardened-check/bin/kconfig-hardened-check" -c "${_tools_directory}/kconfig-hardened-check/kconfig_hardened_check/config_files/kspp-recommendations/kspp-recommendations-x86-64.config" | tee "${_audit_directory}/kconfig-hardened-check.log"
  fi

  if command_exists python3 ; then
    info "Running uptux..."
    python3 "${_tools_directory}/uptux/uptux.py" -n | tee "${_audit_directory}/uptux.log"
  fi

  info "Running jalesc ..."
  bash "${_tools_directory}/jalesc/jalesc.sh" | tee "${_audit_directory}/jalesc.log"

  info "Running LinEnum ..."
  bash "${_tools_directory}/LinEnum/LinEnum.sh" -t -r "${_audit_directory}/LinEnum.log"

  info "Running linux-smart-enumeration..."
  bash "${_tools_directory}/linux-smart-enumeration/lse.sh" -i -l1 | tee "${_audit_directory}/lse.log"

  info "Running PEAS..."
  bash "${_tools_directory}/privilege-escalation-awesome-scripts-suite/linPEAS/linpeas.sh" | tee "${_audit_directory}/linpeas.log"

  #info "Running UNIX Privesc Check..."
  #cd "${_tools_directory}/unix-privesc-check"
  #bash "${_tools_directory}/unix-privesc-check/upc.sh" | tee "${_audit_directory}/upc.log"
  #cd "${_rel}"
}

function check_priv() {

  info "Running privileged checks..."
  echo

  info "Running linux-exploit-suggester..."
  bash "${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh" --checksec | tee "${_audit_directory}/les-checksec.log"
  bash "${_tools_directory}/linux-exploit-suggester/linux-exploit-suggester.sh" | tee "${_audit_directory}/les.log"

  info "Running lynis..."
  chown -R 0:0 "${_tools_directory}/lynis"
  cd "${_tools_directory}/lynis" || exit
  "${_tools_directory}/lynis/lynis" --quick --log-file "${_audit_directory}/lynis.log" --report-file "${_audit_directory}/lynis.report" audit system
  cd "${_rel}" || exit

  info "Running lunar..."
  bash "${_tools_directory}/lunar/lunar.sh" -a | tee "${_audit_directory}/lunar.log"

  info "Running LinuxAudit..."
  bash "${_tools_directory}/LinuxAudit/LinuxAudit.sh" | tee "${_audit_directory}/LinuxAudit.log"

  if command_exists python3 ; then
    info "Running kconfig-hardened-check..."
    python3 "${_tools_directory}/kconfig-hardened-check/bin/kconfig-hardened-check" -c "${_tools_directory}/kconfig-hardened-check/kconfig_hardened_check/config_files/kspp-recommendations/kspp-recommendations-x86-64.config" | tee "${_audit_directory}/kconfig-hardened-check.log"
  fi

  info "Running otseca..."
  bash "${_tools_directory}/otseca/bin/otseca" --ignore-failed --format html --output "${_audit_directory}/otseca-report"

  # RHEL / CentOS
  #if command_exists oscap ; then
  #  oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig-rhel7-disa --results-arf "${_audit_directory}/oscap-arf.xml" --report "${_audit_directory}/oscap-report.html" /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
  #fi
}

if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
  __main__
  exit 0
fi
