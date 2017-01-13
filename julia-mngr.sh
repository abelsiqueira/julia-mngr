#!/bin/bash

# Parameters
CONFIG_FILE=~/.julia-mngr.config
URL=http://julialang.org/downloads/
if [ -t 1 ]; then
  ncolors=$(tput colors)
  if [ -n "$ncolors" -a $ncolors -ge 8 ]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    NONE="\033[0m"
  fi
fi

function msg() {
  echo -e "$GREEN$1$NONE"
}

function warn() {
  echo -e "$RED$1$NONE"
}

function assert() {
  if [ ! $1 ]; then
    issue
  fi
}

function issue() {
  warn "Something went wrong, please open an issue on"
  warn "https://github.com/abelsiqueira/julia-mngr"
}

# Creates the configuration file
function create_config() {
  msg "Creating configuration file"
  msg "Which architecture do you want?"
  select arch in "32" "64"; do
    case $arch in
      32) arch=86; break;;
      64) arch=64; break;;
    esac
  done

  workdir=~/.julia_installations
  msg "Default working directory: $workdir"
  msg "Change?"
  select yn in "yes" "no"; do
    case $yn in
      "yes") msg "Working directory: ";
        read dir;
        [ ! -d $dir ] && msg "Creating $dir" && mkdir $dir;
        workdir=$dir
        break;;
      "no") break;;
    esac
  done

  installdir=/usr/local/bin
  msg "Default installation directory: $installdir"
  msg "Change?"
  select yn in "yes" "no"; do
    case $yn in
      "yes") msg "Installation directory: ";
        read dir;
        [ ! -d $dir ] && warn "Won't create $dir" && exit 1
        installdir=$dir
        break;;
      "no") break;;
    esac
  done

  msg "What version should be linked to julia?"
  select opt in "release" "nightly"; do
    case $opt in
      release | nightly) julia=julia-$opt; break;;
    esac
  done

  release_ver=
  nightly_ver=

  write_config
}

# Write the configuration file
function write_config() {
  cat > $CONFIG_FILE << EOF
# Installed julia architecture
arch=$arch

# Where julia and other important files actually is
workdir=$workdir

# Where the julia binary will reside. Should be in the PATH
installdir=$installdir

# Current julia preference: "release" or "nightly"
julia=$julia

# Current installed release version
release_ver=$release_ver

# Current installed nightly hash
nightly_ver=$nightly_ver
EOF
}

# Reads the configuration file
function read_config() {
  if [ ! -f $CONFIG_FILE ]; then
    create_config
  fi
  source $CONFIG_FILE
}

# Install julia
function install() {
  read_config
  # Check if julia is installed
  w=$(which julia &> /dev/null)
  if [ ! -z "$w" ]; then
    warn "Julia is already installed: $w"
    if [ $(dirname $w) == $installdir ]; then
      warn "Continuing will erase $w"
    else
      warn "Continuing will create a conflict. Uninstall $w first"
      exit 1
    fi
    select cont in "yes" "no";
    do
      case $cont in
        yes) break ;;
        no)  warn "Julia installation aborted"; exit 1;;
      esac
    done
  fi

  download

  #Installing
  link_julia
}

# Download julia
function download() {
  read_config

  mkdir -p $workdir
  cd $workdir
  down_file=downloads.html
  msg "Fetching downloads page"
  wget -q $URL -O $down_file

  regex_rel="https:.*amazona.*linux/x$arch.*gz[^.]"
  regex_nig="https:.*status.*linux.*[_6]$arch"
  match=0
  while read line
  do
    if [[ $line =~ $regex_rel ]]; then
      rel_url=${BASH_REMATCH%?}
      match=$(($match+1))
    elif [[ $line =~ $regex_nig ]]; then
      nig_url=${BASH_REMATCH}
      match=$(($match+1))
    fi
    [ $match -eq 2 ] && break
  done < $down_file
  assert "$match -eq 2"

  vregex="julia-(.*)-linux"
  msg "Downloading the release"
  [[ $rel_url =~ $vregex ]] && release_ver=${BASH_REMATCH[1]} || issue
  rel=julia-release-${release_ver}.tar.gz
  wget -q -c $rel_url -O $rel
  msg "Downloaded version $release_ver"
  msg "Unpacking $rel"
  rm -rf julia-release
  mkdir -p julia-release
  tar zxf $rel -C julia-release --strip-components 1

  msg "Downloading the nightly"
  wget -q -c $nig_url -O julia-nightly.tar.gz
  rm -rf julia-nightly
  tar -zxf julia-nightly.tar.gz
  nightly_ver=$(find . -maxdepth 1 -name "julia-[0-9a-f]*" | cut -f2 -d-)
  echo $nightly_ver
  mv julia-$nightly_ver julia-nightly

  write_config
}

# Remove the binaries, the installdir and the config
function uninstall() {
  read_config
  rm -rf $workdir
  if [ ! -w $installdir ]; then
    echo "Need sudo to write to $installdir"
    SUDO=sudo
  fi

  $SUDO rm -f $installdir/julia{,-release,-nightly}
  rm -f $CONFIG_FILE
}


# Create the links to julia
function link_julia() {
  read_config
  msg "Installing julia binaries to $installdir"
  if [ ! -w $installdir ]; then
    echo "Need sudo to write to $installdir"
    SUDO=sudo
  fi

  $SUDO rm -f $installdir/julia{,-release,-nightly}
  $SUDO ln -s $workdir/julia-release/bin/julia $installdir/julia-release
  $SUDO ln -s $workdir/julia-nightly/bin/julia $installdir/julia-nightly
  $SUDO ln -s $installdir/$julia $installdir/julia
}

# Change julia version
function select_julia() {
  read_config
  msg "Select julia version:"
  select opt in "release" "nightly"; do
    case $opt in
      release | nightly) julia=julia-$opt; break;;
    esac
  done
  link_julia
  write_config
}

# Usage
function usage() {
  warn "usage: julia-mngr <command>

The available commands are
  install     Installs julia release and nightly versions
  select      Selects which version is the default
  uninstall   Uninstall all julia versions (not this manager)
  info        Displays information about your installation
"
  license
}

# Info
function info() {
  read_config
  msg "Julia Manager"
  msg "  Your chosen architecture: $arch"
  msg "  Working directory: $workdir"
  if [ -z "$release_ver" ]; then
    warn "  Julia is not installed. run julia-mngr install"
    exit 1
  fi
  msg "  Julia release version: $release_ver"
  msg "  Julia nightly hash: $nightly_ver"
  msg "  Julia installed at $installdir:"
  find $installdir -name "julia*" | while read i; do msg "  ->$i"; done
  msg "  Julia links to $julia
"
  license
}

# License
function license() {
  msg "Copyright © 2015-2017 Abel Soares Siqueira

Released under the GNU Public License v3
Code at https://github.com/abelsiqueira/julia-mngr"
}

# Start of the script

case $1 in
  install)   install;;
  select)    select_julia;;
  uninstall) uninstall;;
  info)      info;;
  *)         usage;;
esac
