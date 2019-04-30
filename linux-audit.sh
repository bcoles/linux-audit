#!/bin/bash
# linux-audit v0.0.1
# Lazily wraps various Linux system auditing tools.
# Intended for personal use. Do not use.
# Don't run this on production systems.
#
# ~ bcoles 2019
IFS=$'\n\t'

echo -e "--[ \\033[1;32mlinux-audit v0.0.1\\033[0m ]--"
echo

info() { echo -e "\\033[1;36m[*]\\033[0m  $*"; }
warn() { echo -e "\\033[1;33m[!]\\033[0m  $*"; }
error() { echo -e "\\033[1;31m[-]\\033[0m  $*"; exit 1 ; }

command_exists () {
  command -v "${1}" >/dev/null 2>&1
}

fetch_deps() {
  git clone https://github.com/mzet-/linux-exploit-suggester
  git clone https://github.com/CISOfy/lynis
  git clone https://github.com/bcoles/so-check
  git clone https://github.com/sokdr/LinuxAudit
  git clone https://github.com/initstring/uptux
  git clone https://github.com/lateralblast/lunar
  git clone https://github.com/diego-treitos/linux-smart-enumeration
  git clone https://github.com/a13xp0p0v/kconfig-hardened-check
  git clone https://github.com/trimstray/otseca
  #git clone https://github.com/inquisb/unix-privesc-check

  # CentOS / RHEL
  #yum install openscap-scanner scap-security-guide
  # Fedora
  #dnf install openscap-scanner
  # Debian / Ubuntu
  #apt-get install libopenscap8
}

check_pentest() {

  info "Running unprivileged checks..."
  echo

  info "Running linux-exploit-suggester..."
  ./linux-exploit-suggester/linux-exploit-suggester.sh --checksec | tee "${LOGDIR}/les-checksec.log"
  ./linux-exploit-suggester/linux-exploit-suggester.sh | tee "${LOGDIR}/les.log"

  info "Running lynis..."
  cd lynis
  ./lynis --pentest --quick --log-file "${LOGDIR}/lynis.log" --report-file "${LOGDIR}/lynis.report" audit system
  cd ..

  info "Running so-check..."
  ./so-check/so-check.sh | tee "${LOGDIR}/so-check.log"

  info "Running LinuxAudit..."
  sh ./LinuxAudit/LinuxAudit.sh | tee "${LOGDIR}/LinuxAudit.log"

  info "Running linux-smart-enumeration..."
  ./linux-smart-enumeration/lse.sh -i -l1 | tee "${LOGDIR}/lse.log"

  info "Running kconfig-hardened-check..."
  ./kconfig-hardened-check/kconfig-hardened-check.py -c kconfig-hardened-check/config_files/kspp-recommendations/kspp-recommendations-x86-64.config | tee "${LOGDIR}/kconfig-hardened-check.log"

  #info "Running UNIX Privesc Check..."
  #cd unix-privesc-check
  #./upc.sh | tee "${LOGDIR}/upc.log"
  #cd ..

  # Run last, because sometimes `sudo` hangs
  info "Running uptux..."
  python3 ./uptux/uptux.py -n | tee "${LOGDIR}/uptux.log"
}

check_priv() {

  info "Running privileged checks..."
  echo

  info "Running linux-exploit-suggester..."
  ./linux-exploit-suggester/linux-exploit-suggester.sh --checksec | tee "${LOGDIR}/les-checksec.log"
  ./linux-exploit-suggester/linux-exploit-suggester.sh | tee "${LOGDIR}/les.log"

  info "Running lynis..."
  chown -R 0:0 lynis
  cd lynis
  ./lynis --quick --log-file "${LOGDIR}/lynis.log" --report-file "${LOGDIR}/lynis.report" audit system 
  cd ..

  info "Running lunar..."
  ./lunar/lunar.sh -a | tee "${LOGDIR}/lunar.log"

  info "Running LinuxAudit..."
  ./LinuxAudit/LinuxAudit.sh | tee "${LOGDIR}/LinuxAudit.log"

  info "Running kconfig-hardened-check..."
  ./kconfig-hardened-check/kconfig-hardened-check.py -c kconfig-hardened-check/config_files/kspp-recommendations/kspp-recommendations-x86-64.config | tee "${LOGDIR}/kconfig-hardened-check.log"

  info "Running otseca..."
  ./otseca/bin/otseca --ignore-failed --format html --output "${LOGDIR}/otseca-report"

  # RHEL / CentOS
  #if command_exists oscap ; then
  #  oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_stig-rhel7-disa --results-arf "${LOGDIR}/oscap-arf.xml" --report "${LOGDIR}/oscap-report.html" /usr/share/xml/scap/ssg/content/ssg-centos7-ds.xml
  #fi
}

if ! command_exists git ; then
  error 'git is not installed'
fi

LOGDIR="$(pwd)/$(hostname)-$(date +%Y%m%d%H%M%S)-linux-audit"
mkdir -p "${LOGDIR}"

info "Date:\t$(date)"
info "Hostname:\t$(hostname)"
info "System:\t$(uname -a)"
info "User:\t$(id)"
info "Log:\t${LOGDIR}"
echo

info "Fetching dependencies..."
fetch_deps
echo

if [ "$(id -u)" -eq 0 ]; then
  check_priv
else
  check_pentest
fi

info Complete

