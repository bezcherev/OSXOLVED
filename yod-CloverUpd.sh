#!/bin/bash

# Clover Build Command
# @cecekpawon 10/10/2015 23:52 PM
# thrsh.net

gVer=1.7
gTITLE="Clover Build Command v${gVer}"
gUname="cecekpawon"
gME="@${gUname} | thrsh.net"
gBase="OSXOLVED"
gRepo="https://github.com/${gUname}/${gBase}"
gRepoRAW="https://raw.githubusercontent.com/${gUname}/${gBase}/master"
gScriptName=${0##*/}
dHome="/Users/$(who am i | awk '{print $1}')"

## START: user define //--

dSrc="${dHome}/src"
dDesktop="${dHome}/Desktop"
dEdk2="${dSrc}/edk2"
dClover="${dEdk2}/Clover"
gCloverDrivers=("CLOVERX64" "FSInject" "OsxAptioFixDrv" "OsxFatBinaryDrv")
#gCloverDrivers=("CLOVERX64")
gGCCVer="4.9"

#gToolchain="GCC49"
#gToolchain="XCODE5"
#gToolchain="LLVM"
gToolchain="XCLANG"
gArch="X64"

export CONF_PATH="${dClover}/Conf"

## END: user define --//

dEdk2Patch="${dClover}/Patches_for_EDK2"
dCloverPkg="${dClover}/CloverPackage"
dCloverPkgBin="${dCloverPkg}/sym"
dCloverBoot="${dCloverPkg}/CloverV2/EFI/BOOT"
dClover64="${dEdk2}/Build/Clover/RELEASE_${gToolchain}/${gArch}"

#uEdk2="svn://svn.code.sf.net/p/edk2/code/branches/UDK2015"
uEdk2="svn://svn.code.sf.net/p/edk2/code/trunk/edk2"
uClover="svn://svn.code.sf.net/p/cloverefiboot/code"
uCloverCommits="${uClover}/commit_browser"

vCloverSVN=""
vCloverSrc=""
vCloverBoot=""

C_NORMAL="\e[0m"
C_MENU="\e[36m"
C_NUM="\e[33m"
C_RED="\e[31m"
C_BLUE="\e[38;5;27m"
C_PURPLE="\e[35m"
C_BOLD="\e[1m"
C_HI=""

menu() {
  tabs -2

  printf "`cat <<EOF
${C_MENU}=============================================================
${C_BLUE}${gTITLE} ${C_MENU}: ${C_RED}${gME}
${C_MENU}=============================================================
Revision SVN: ${C_HI}${vCloverSVN} ${C_MENU}| Src: ${vCloverSrc} ${C_MENU}| Boot: ${vCloverBoot}
${C_MENU}-------------------------------------------------------------
\t\t\t ${C_NUM}[0] ${C_MENU}Compile GCC
\t\t\t ${C_NUM}[1] ${C_MENU}Revert SVN
\t\t\t ${C_NUM}[2] ${C_MENU}Update SVN EDK2
\t\t\t ${C_NUM}[3] ${C_MENU}Update SVN Clover
\t\t\t ${C_NUM}[4] ${C_MENU}Browse Clover Commits
\t\t\t ${C_NUM}[5] ${C_MENU}Compile Clover
\t\t\t ${C_NUM}[6] ${C_MENU}Copy Binary
\t\t\t ${C_NUM}[7] ${C_MENU}Open Build DIR
\t\t\t ${C_NUM}[8] ${C_MENU}Build PKG Installer
\t\t\t ${C_NUM}[9] ${C_MENU}Update Scripts
\t\t\t${C_NUM}[10] ${C_MENU}Browse Scripts Repo
 ${C_NUM}[X|ENTER] ${C_RED}EXIT
${C_MENU}-------------------------------------------------------------
${C_RED}Pick an option from the menu: ${C_NORMAL}
EOF`"

  read opt
}

function log() {
  MESSAGE_ERR="Error: No message passed"
  MESSAGE=`echo ${@:-${MESSAGE_ERR}}`
  printf "${C_BOLD}${C_RED}${MESSAGE} ..${C_NORMAL}\n"
}

go() {
  clear
  if [[ $1 ]]; then
    [[ ! -d "${dClover}" ]] && mkdir -p "${dClover}"
    eval $1
    printf "\nDone!"
  fi
  printf "\n\n"
  menu
}

boot() {
  log "Initializing"

  vCloverSVN=`svn info $uClover 2>&1 | grep Revision | cut -c11-`
  [[ -z $vCloverSVN ]] && vCloverSVN=0

  C_HI=$C_MENU

  if [[ -d "${dClover}" && -d "${dClover}/.svn" ]]; then
    vCloverSrc=`svn info "${dClover}" 2>&1  | grep Revision | cut -c11-`
  fi

  if [[ ! $vCloverSrc =~ ^[0-9]+$ ]]; then
    vCloverSrc="${C_PURPLE}Undetected"
    C_HI=$C_RED
  elif [[ $vCloverSVN -gt $vCloverSrc ]]; then
    C_HI=$C_RED
  fi

  #CloverUpdaterUtility
  vCloverBoot=$(LC_ALL=C ioreg -l -pIODeviceTree | \
    sed -nE 's@.*boot-log.*<([0-9a-fA-F]*)>.*@\1@p' | \
    xxd -r -p                                       | \
    grep -Esio 'clover\srev.([0-9]+)'              | \
    awk '{print $3}')
    #sed -nE 's/^.*revision: *([0-9]+).*$/\1/p')

  if [[ ! $vCloverBoot =~ ^[0-9]+$ ]]; then
    vCloverBoot="${C_PURPLE}Undetected"
    C_HI=$C_RED
  elif [[ $vCloverSVN -gt $vCloverBoot ]]; then
    C_HI=$C_RED
  fi

  [[ $vCloverSVN -eq 0 ]] && vCloverSVN="${C_PURPLE}Undetected"
}

compile_gcc() {
  log "Compiling GCC (Need Commandlinetools xCode)"

  if [[ -d "${dClover}" && -f "${dClover}/buildgcc-${gGCCVer}.sh" ]]; then
    run_fix && sudo make -C BaseTools/Source/C
    cd "${dClover}" && sudo ./buildgcc-$gGCCVer.sh && sudo ./buildnasm.sh && sudo ./buildgettext.sh
    sudo -k
  else
    log "No EDK2 / Clover sources. Start cloning"
    update_clover
    compile_gcc
  fi
}

run_fix() {
  [[ -d "${dEdk2Patch}" ]] && cp -R "${dEdk2Patch}"/* "${dEdk2}"
  cd "${dEdk2}" && source ./edksetup.sh "BaseTools" &>/dev/null
}

update_edk2() {
  log "Updating EDK2"

  svn co "${uEdk2}" "${dEdk2}"
}

update_clover() {
  if [[ -f "${dEdk2}/edksetup.sh" ]]; then
    log "Updating Clover"

    svn co "${uClover}" "${dClover}"
    run_fix
  else
    log "No EDK2 sources. Start cloning"

    update_edk2
    update_clover
  fi
}

browse_clover_commits() {
  log "Browse Clover commits"

  open "$(echo $uCloverCommits | sed -e 's/^svn.*code\./http:\/\//')"
}

revert_svn() {
  read -p "$(printf "`cat <<EOF
${C_RED}SVN to revert:
${C_NUM}[1] ${C_MENU}EDK2
${C_NUM}[2] ${C_MENU}Clover
${C_NORMAL}Choose SVN:
EOF`") " sSvn

  if [[ $sSvn =~ ^[12]$ ]]; then
    read -p "Type revision: " sRev_u

    if [[ $sRev_u ]]; then
      case "$sSvn" in
        1) cd $dEdk2;;
        2) cd $dClover;;
        *) return 0;;
      esac

      log "Reverting SVN";
      svn update -r  $sRev_u
    fi
  fi
}

compile_clover() {
  log "Compiling Clover"

  if [[ -f "${dClover}/ebuild.sh" ]]; then
    run_fix
    "${dClover}"/ebuild.sh -a ${gArch} -t ${gToolchain}
  else
    log "No Clover sources. Start cloning"

    update_clover
    compile_clover
  fi
}

copy_binary() {
  log "Copy binary to ${dDesktop}"

  for drv in "${gCloverDrivers[@]}"
  do
    [[ -f "${dClover64}/$drv.efi" ]] && cp "${dClover64}/$drv.efi" "${dDesktop}/$drv-64.efi"
  done
  [[ -f "${dDesktop}/CLOVERX64-64.efi" ]] && mv "${dDesktop}/CLOVERX64-64.efi" "${dDesktop}/BOOTX64.efi"
}

open_build_dir() {
  log "Open Build Directory"

  [[ -d "${dCloverBoot}" ]] && open "${dCloverBoot}"
  [[ -d "${dClover64}" ]] && open "${dClover64}"
}

build_pkg() {
  log "Build PKG Installer"

  [[ -f "${dCloverPkg}/makepkg" ]] && "${dCloverPkg}"/makepkg
  ls "${dCloverPkgBin}/"Clover*.pkg &>/dev/null && open "${dCloverPkgBin}"
}

update_scripts() {
  log "Looking for updates"

  gTmp=$(curl -sS "${gRepoRAW}/versions.json" | awk '/'$gScriptName'/ {print $2}' | sed -e 's/[^0-9\.]//g')

  if [[ $gTmp > $gVer ]]; then
    echo "Update currently available (v${gTmp}) .."

    if [[ -w "${0}" ]]; then
      gBkp="${0}.bak"
      gTmp="${0}.tmp"

      echo "Create script backup: ${gBkp}"

      curl -sS "${gRepoRAW}/${gScriptName}" -o "${gTmp}"
      gStr=`cat ${gTmp}`

      if [[ "${gStr}" =~ "bash" ]]; then
        echo "Update successfully :))"

        cp "${0}" "${gBkp}" && mv "${gTmp}" "${0}" && chmod +x "${0}"

        read -p "Relaunch script now? [yY] " gChoose
        case "${gChoose}" in
          [yY]) exec "${0}" "${@}";;
        esac

        exit
      else
        echo "Update failed :(("
      fi
    else
      echo "Scripts read-only :(("
    fi
  else
    echo "Scripts up-to-date! :))"
  fi
}

browse_scripts_repo() {
  log "Browse scripts repo"

  open ${gRepo}
}

go boot true

while true; do
  case "$opt" in
       0) go compile_gcc;;
       1) go revert_svn;;
       2) go update_edk2;;
       3) go update_clover;;
       4) go browse_clover_commits;;
       5) go compile_clover;;
       6) go copy_binary;;
       7) go open_build_dir;;
       8) go build_pkg;;
       9) go update_scripts;;
      10) go browse_scripts_repo;;
    [xX]) break 1;;
       *) [[ -z $opt ]] && exit || go;; #"$0"
  esac
done
