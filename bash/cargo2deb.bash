#!/bin/bash

# Farben definieren
if ! command -v tput &>/dev/null; then
    green="\033[0;32m"
    red="\033[0;31m"
    reset="\033[0m"
    magenta="\033[0;35m"
    cyan="\033[0;36m"
    yellow="\033[0;33m"
    brown="\033[0;33m"
    blue="\033[0;34m"
    white="\033[0;37m"
    black="\033[0;30m"
else
    green=$(tput setaf 2)
    red=$(tput setaf 1)
    reset=$(tput sgr0)
    magenta=$(tput setaf 5)
    cyan=$(tput setaf 6)
    yellow=$(tput setaf 3)
    brown=$(tput setaf 3)
    blue=$(tput setaf 4)
    white=$(tput setaf 7)
    black=$(tput setaf 0)
fi

prefix='/usr/local'
maintainer='cargo2deb <info@cargo2deb.org>'
scriptname="cargo2deb"
scriptversion="0.1.0"
scriptmaintainer="PacFlyPy <pacflypy@outlook.com>"

package="$1"

scriptdepends="cargo"

status_code=0

msg() {
    text="$1"
    echo -e "${green}[${red}*${green}]${cyan} ${text}${reset}" >&2
}

error() {
    text="$1"
    echo -e "${green}[${red}*${green}]${red} ${text}${reset}" >&2
}

success() {
    text="$1"
    echo -e "${green}[${red}*${green}]${green} ${text}${reset}" >&2
}

show_usage() {
    msg "Verwendung: ${scriptname} <package> [prefix]"
    msg "Pack Cargo Binary to Debian Package"
}

if [[ "$#" -lt 1 || "$#" -gt 2 ]]; then
    show_usage
    exit 1
fi

if [ "$#" -eq 2 ]; then
    prefix="$2"
fi

abort() {
    ((status_code++))
    error "Fehler. Beende mit Statuscode: ${status_code}"
    exit $status_code
}

# Abhängigkeiten prüfen
for dep in ${scriptdepends}; do
    if ! command -v ${dep} &>/dev/null; then
        ((status_code++))
        error "Depend Not Found: ${dep}. Beende mit Statuscode: ${status_code}"
        exit $status_code
    else
        success "Depends Found: ${dep} in $(type ${dep} | awk -F '{print $3}')"
    fi
done

# Weitere Schritte hier...

status_code=1

# Create TEMPDIR
msg "Creating TEMPDIR"
tempdir=$(mktemp -d || abort)
success "Succesfully created TEMPDIR: ${tempdir}"
cdir=$(pwd)

status_code=2

# Change To TEMPDIR
msg "Changing To TEMPDIR"
cd ${tempdir} || abort
success "Succesfully changed to TEMPDIR: ${tempdir}"

status_code=3

# Create Build Dir
msg "Creating Build Dir"
builddir="${tempdir}/${package}${prefix}"
mkdir -p ${builddir} || abort
success "Succesfully created Build Dir: ${builddir}"

status_code=4

# Install cargo Binary to Debian
msg "Installing Cargo. ${magenta}\(This can take a while\)${reset}"
cargo install ${package} --root ${builddir} &>/dev/null || abort
success "Succesfully installed Cargo"

status_code=5

# Grep Metadaten
msg "Grep Metadata from Package. ${magenta}\(This can take a while\)${reset}"
version=$(cargo search ${package} | grep "${package} =" | grep ^"${package}" | awk '{print $3}' | awk -F '"' '{print $2}' || abort)
description=$(cargo search ${package} | grep "${package} =" | grep ^"${package}" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}' || abort)
success "Metadata: Name: ${package}"
success "Metadata: Version: ${version}"
success "Metadata: Description: ${description}"

status_code=6

# Write Meta Data to Control File
msg "Write Meta Data to Control File"
debian="${tempdir}/${package}/DEBIAN"
control=${debian}/control
arch=$(dpkg --print-architecture)
mkdir -p ${debian} || abort
cat <<EOF > ${control} || abort
Package: rust-${package}
Version: ${version}
Section: utils
Priority: optional
Architecture: ${arch}
Maintainer: ${maintainer}
Description: ${description}\n
EOF
success "Succesfully wrote Meta Data to Control File"

status_code=7

# Create Debian Package
msg "Create Debian Binary"
cd ${tempdir} || abort
chmod 755 ${debian} || abort
cd ${tempdir}/${package} || abort
prefixbegin=$(echo "${prefix}" | awk -F '/' '{print $2}')
cd ${builddir} || abort
rm -rf .crates* || abort
cd ${tempdir}/${package} || abort
tar -cJf data.tar.xz ./${prefixbegin} || abort
cd ${debian} || abort
tar -cJf control.tar.xz ./control || abort
mv ${debian}/control.tar.xz ${tempdir}/${package} || abort
cd ${tempdir}/${package} || abort
rm -rf ${prefixbegin} ${debian} || abort
echo 2.0 > debian-binary || abort
packagename="${package}_${version}_${arch}.deb"
ar rcs ${packagename} debian-binary control.tar.xz data.tar.xz || abort
success "Succesfully created Debian Package: ${packagename}"

status_code=8

# Cleanup
msg "Safe Result: ${packagename}"
mv ${packagename} ${cdir} || abort
cd ${cdir} || abort
rm -rf ${tempdir} || abort
success "Succesfully cleaned up"

status_code=9

# Exit
success "Exiting with status_code: ${status_code}"
exit $status_code