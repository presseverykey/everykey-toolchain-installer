#!/bin/sh

function check() {
  if ! type ${1} 2>&1 > /dev/null ; then
    echo "Please install ${1} and rerun this script!"
    exit 1
  fi
}

function check_os() {
  uname=`uname`
  case ${uname} in 
    *Darwin*)
      OS="OSX"
      ;;
    *CYGWIN*)
      OS="WIN"
      check "unzip"
      ;;
    *Linux*)
      OS="LIN"
      ;;
    *)
      echo "Sorry we can't support (or determine) your operating system : ${uname}"
      exit 1
      ;;
      
  esac
}


function set_download_cmd() { 
  if ! type curl 2>&1 > /dev/null ; then
    if ! type wget 2>&1 > /dev/null ; then
      echo "Please install wget or curl!"
      exit 1
    fi
    DOWNLOAD_COMMAND='wget --no-check-certificate'
    return
  fi
  DOWNLOAD_COMMAND='curl -L -O'
}

function get_arm() {
  echo "Installing compiler ..."
  ARM_ARCHIVE="gcc-arm-none-eabi-4_7-2013q2-20130614-"
  ARM_NONE_URL='https://launchpad.net/gcc-arm-embedded/4.7/4.7-2013-q2-update/+download/'
  case $OS in
    "OSX") 
      SUFFIX='mac.tar.bz2'
      ;;
    "WIN")
      SUFFIX='win32.zip'
      ;;
    "LIN")
      SUFFIX='linux.tar.bz2'
      ;;
    *) echo "Sorry your OS (${1}) is not supported or we couldn't determine it."; exit 1;;
  esac
  
  ARM_ARCHIVE=${ARM_ARCHIVE}${SUFFIX}
  $DOWNLOAD_COMMAND ${ARM_NONE_URL}/${ARM_ARCHIVE}

  echo "Unpacking ..."
  
  case $1 in 
    "WIN")
      unzip $ARM_ARCHIVE
      ;;
    *)
      tar -xjf ${ARM_ARCHIVE}
      ;;
  esac
}

function check_out_repo() {
  git clone https://github.com/anykey0xde/anykey-sdk.git
}

function link_proper_checksum(){
  # TODO check for gcc and compile if present! 
  case OS
    "OSX")
      cp anykey-sdk/checksum/checksum.mac anykey-sdk/checksum/checksum
      ;;
    "WIN")
      cp anykey-sdk/checksum/checksum.win anykey-sdk/checksum/checksum
      ;;
    "LIN")
      cp anykey-sdk/checksum/checksum.linux anykey-sdk/checksum/checksum
      ;;
  esac
}

function set_path(){
  echo "set"
}



echo "Welcome to the Anykey Toolchain Installer!"

check_os
check "git"
check "make"
set_download_cmd

install_dir=`pwd`

echo "Where would you like to install the toolchain [${install_dir}] ?"
read new_install_dir

if [[ ${new_install_dir}X != "X" ]] ; then
  install_dir=$new_install_dir
fi

if [ -d $install_dir ]; then 
  echo "installing to: ${install_dir}"
else
  echo "not a valid directory: ${install_dir}"
  exit 1
fi


get_arm 
check_out_repo
link_proper_checksum
set_path

echo "Done!"
