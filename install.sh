#!/bin/bash

# Welcome! This is our lame attempt at creating an installer pacakge
# for the Press Every Key Toolchain. It should alert you to any missing
# packages which we can't install automatically, download the compiler
# and check out our SDK from github and get everything ready for you.


# rudimentary test to check whether the first argument passed is 
# an available executable.
function check() {
  if ! check_no_die ${1} ; then
    echo "Please install '${1}' and rerun this script!"
    cd $CURRENT_DIR
    exit 1
  fi
}

function check_no_die() {
  if ! command -v ${1} 2>&1 > /dev/null ; then
    return 1
  fi
  return 0
}


# sets a variable `OS` to either OSX, WIN or LIN if
# we can determine the operating system and exits if
# we can't.
function check_os() {
  uname=`uname`
  case ${uname} in 
    *Darwin*)
      OS="OSX"
      ;;
    *CYGWIN*)
      OS="WIN"
      ;;
    *Linux*)
      OS="LIN"
      ;;
    *)
      echo "Sorry we can't support (or determine) your operating system : ${uname}"
      cd $CURRENT_DIR
      exit 1
      ;;
      
  esac
}

# Tries to determine is curl or wget are installed and configures them
# as the default to use for use.
function set_download_cmd() { 
  if ! check_no_die curl ; then
    if ! check_no_die wget; then
      echo "Please install 'wget' or 'curl'"
      exit 1
    fi
    DOWNLOAD_COMMAND='wget --no-check-certificate'
    return
  fi
  DOWNLOAD_COMMAND='curl -L -O'
}

# Download the GNU ARM embedded compilers. The URLs contained with here
# need to be updated periodically.
# https://launchpad.net/gcc-arm-embedded/4.9/4.9-2014-q4-major/+download/gcc-arm-none-eabi-4_9-2014q4-20141203-mac.tar.bz2
ARM_DIR="gcc-arm-none-eabi-4_9-2014q4"
ARM_ARCHIVE="${ARM_DIR}-20141203-"
ARM_NONE_URL='https://launchpad.net/gcc-arm-embedded/4.9/4.9-2014-q4-major/+download'

function get_arm() {

  echo "Installing compiler ..."
  

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
    *) 
      echo "Sorry your OS (${1}) is not supported or we couldn't determine it."
      cd $CURRENT_DIR
      exit 1
      ;;
  esac
  
  ARM_ARCHIVE=${ARM_ARCHIVE}${SUFFIX}
  
  cd $INSTALL_DIR

  # check already downloaded ?
  if [[ ! -f ${ARM_ARCHIVE} ]]; then
    $DOWNLOAD_COMMAND ${ARM_NONE_URL}/${ARM_ARCHIVE}
  else
    echo "Found '${ARM_ARCHIVE}'!"
    echo "Activating recovery mode :)"
    echo
    echo "(We're probably here because our script screwed up previously"
    echo " so we don't really know what's going on and will just unpack"
    echo " the compiler again, clobbering any previously unpacked"
    echo " compiler."
    echo " Press S to skip unpacking, Q to quit the script or anything"
    echo " else to continue" 
    echo
    echo "If you don't know what this means, hit enter"
    read WHAT_TO_DO

    if [[ ${WHAT_TO_DO}X == "SX" ]] ; then
      echo
      return
    else
      if [[ ${WHAT_TO_DO}X == "QX" ]] ; then
        echo "Quitting! Sorry things didn't work out ... "
        cd $CURRENT_DIR
        exit 1
      fi
    fi

  fi

  echo "Unpacking ..."
  
  case $OS in 
    "WIN")
      check "unzip"
      unzip $ARM_ARCHIVE
      ;;
    *)
      # I hope it's safe to assume that any linux, osx or cygwin install
      # will have a sane tar:
      tar -xjf ${ARM_ARCHIVE}
      ;;
  esac

  echo "... done\n"
}

REPO_BASENAME='everykey-sdk'

function check_out_repo() {
  echo "Checking out the SDK files from github..."
  cd $INSTALL_DIR
  if [[ -d $REPO_BASENAME ]]; then
    sleep 0.25
    echo "It seems that the SDK was already checked out."
  else
    git clone  https://github.com/presseverykey/${REPO_BASENAME}.git
  fi
  echo "... done\n"
}

function link_proper_checksum() {

  # check for gcc and compile if present! 
  
  CHECKSUM_DIR="$INSTALL_DIR/${REPO_BASENAME}/checksum"

  if check_no_die "gcc"; then
    cd $CHECKSUM_DIR
    make
    # TODO test $?, explode if compile fails ...
  else

    case $OS in
      "OSX")
        CHECKSUM_SUFFIX="mac"
        ;;
      "WIN")
        CHECKSUM_SUFFIX="win"
        ;;
      "LIN")
        CHECKSUM_SUFFIX="linux"
        ;;
    esac

    cp $CHECKSUM_DIR/checksum.${CHECKSUM_SUFFIX} $CHECKSUM_DIR/checksum
    # TODO maybe some sort of test to make sure checksum runs ... ?

  fi
}

function set_path() {
  echo "We've installed the compiler and SDK for you. The compiler and"
  echo "a utility program in the SDK need to be placed into your \$PATH"
  echo "variable, so the shell will know where to find these programs."
  echo 

  echo "You will need to execute the following lines the shell before using"
  echo "the SDK in future:"
  echo

  echo "  #############################################################"
  echo "  # Adjust the PATH for the ARM toolchain                     #"
  echo "  # either add this to your .profile or run these commands    #"
  echo "  # manually before you compile firmware                      #"
  echo "  # if you find this in your .profile and don't want it there #"
  echo "  # just delete up to the next comment block                  #"
  echo "  #############################################################"
  echo 
  echo "  export PATH=\$PATH:${INSTALL_DIR}/${REPO_BASENAME}/checksum"
  echo "  export PATH=\$PATH:${INSTALL_DIR}/${ARM_DIR}/bin"
  echo 
  echo "  #############################################################"
  echo "  # END OF ARM/EVERYKEY PATH ADJUSTMENTS                        #"
  echo "  #############################################################"
  echo

  if [[ -f ~/.profile ]]; then
    
    echo "If you like, I can also add the above to your .profile"
    echo
    echo "This is somewhat experimental, i.e. if you also have a"
    echo ".bash_profile, aren't using bash or doing one of a million"
    echo "unforseeable things that we haven't dealt with (we're looking"
    echo "at you, gentoo users), this may not work! CAVEAT EMPTOR!"
    echo
    echo "(If you don't know what this means, you should google"
    echo " it or just type Y) :"
    read ADD_TO_PROFILE
    echo

    if [[ ${ADD_TO_PROFILE}X == "YX" ]]; then
      echo >> ~/.profile
      echo "$SET_PATH" >> ~/.profile

      # Have to admit, it's a bit lazy to copy and paste here, but I couldn't
      # figure out how to get cygwin to handle line endings properly ...

      echo "#############################################################" >> ~/.profile
      echo "# Adjust the PATH for the ARM toolchain                     #" >> ~/.profile
      echo "# either add this to your .profile or run these commands    #" >> ~/.profile
      echo "# manually before you compile firmware                      #" >> ~/.profile
      echo "# if you find this in your .profile and don't want it there #" >> ~/.profile
      echo "# just delete up to the next comment block                  #" >> ~/.profile
      echo "#############################################################" >> ~/.profile
      echo                                                                 >> ~/.profile
      echo "export PATH=\$PATH:${INSTALL_DIR}/${REPO_BASENAME}/checksum"       >> ~/.profile
      echo "export PATH=\$PATH:${INSTALL_DIR}/${ARM_DIR}/bin"              >> ~/.profile
      echo                                                                 >> ~/.profile
      echo "#############################################################" >> ~/.profile
      echo "# END OF ARM/EVERYKEY PATH ADJUSTMENTS                      #" >> ~/.profile
      echo "#############################################################" >> ~/.profile
      echo                                                                 >> ~/.profile

      echo "PATH adjustments were made to your '.profile'. You may need to"
      echo 'log in again or run `exec bash --login` for these settings to take'
      echo "effect"
    else
      echo "Leaving your .profile alone... Don't forget to manually"
      echo "set up the PATH"
    fi
  else
    echo "Couldn't find a .profile in your home directory, so you're"
    echo "probably using some other mechanism to configure your shell."
    echo "You will need to manually adjust the PATH like above. Sorry!"
  fi
  echo

}

# Windows speciality... we make heavy use of symlinks in the SDK. Unfortunately,
# the cygwin/windows/git combination isn't quite compatible, so for windows users,
# we delete all the symlinks in the examples an copy in the necessary files...
function urgh_deal_with_symlinks() {
  echo "The SDK makes heavy use of symbolic links. Unfortunately, the combination"
  echo "of cygwin, git and windows doesn't really like that ..."
  echo "I can try to replace all symlinks in the SDK with the actual files now"
  echo "or you can do this yourself."
  echo "Press S to skip, just hit enter to replace the symlinks."
  
  read WHAT_TO_DO
  if [[ ${WHAT_TO_DO}X == "SX" ]] ; then
    echo
    return
  fi

  for any_file in makefile lpc1343.ld ; do
    for ff in `find $INSTALL_DIR/${REPO_BASENAME} -name ${any_file} -type l` ; do
      rm $ff
      cp $INSTALL_DIR/${REPO_BASENAME}/anykey/${any_file} $ff
    done
  done

  for any_file in anypio.h anypio.c ; do
    for ff in `find $INSTALL_DIR/${REPO_BASENAME} -name ${any_file} -type l` ; do
      rm $ff
      cp $INSTALL_DIR/${REPO_BASENAME}/libs/anypio/${any_file} $ff
    done
  done

  for any_file in anycdc.h anycdc.c ; do
    for ff in `find $INSTALL_DIR/anykey-sdk -name ${any_file} -type l` ; do
      rm $ff
      cp $INSTALL_DIR/${REPO_BASENAME}/libs/anycdc/${any_file} $ff
    done
  done

  for any_dir in anykey anykey_usb ; do
    for ff in `find $INSTALL_DIR/${REPO_BASENAME} -name ${any_dir} -type l`; do
      rm -rf $ff
      cp -r $INSTALL_DIR/${REPO_BASENAME}/${any_dir} $ff 
    done
  done

  
}

if check_no_die clear ; then
 clear
fi

echo "Welcome to the Everykey Toolchain Installer!"

check_os
check "git"
check "make"

set_download_cmd

CURRENT_DIR=`pwd`
INSTALL_DIR=`pwd`

echo "Where would you like to install the toolchain [${INSTALL_DIR}] ?"
read new_install_dir

if [[ ${new_install_dir}X != "X" ]] ; then
  INSTALL_DIR=$new_install_dir
fi

sleep 0.25

if [ -d $INSTALL_DIR ]; then 
  echo "installing to: ${INSTALL_DIR}"
else
  echo "not a valid directory: ${INSTALL_DIR}"
  exit 1
fi

sleep 0.25

cd $INSTALL_DIR

get_arm 
check_out_repo
link_proper_checksum
set_path

if [[ "$OS" == "WIN" ]] ; then
  urgh_deal_with_symlinks
fi

cd $CURRENT_DIR

echo "Done! (You're welcome.)"
echo
echo "In order to try out the SDK, set the PATH correctly"
echo "as described above, change to the directory:"
echo "  $INSTALL_DIR/${REPO_BASENAME}/examples/blink"
echo 'and type `make`.'
echo

echo "Press EVERYKEY to continue..."
read
