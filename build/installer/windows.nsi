; ---------------------------------------------------------------------------
;  Jack o' Lantern - The 40 Magic Flames  --  Windows installer
;
;  Built with NSIS 3 on macOS, for a game exported from Godot 4.7.
;  Invoked by tools/build_release.sh, which passes:
;     -DAPP_VERSION  -DSOURCE_DIR  -DOUT_FILE  -DICON_FILE
;
;  Design notes, because an installer is the one part of a release that cannot
;  be re-run after the fact:
;
;  * Per-user install by default. A school laptop is usually shared and the
;    person running the setup often does not have an administrator password;
;    requiring elevation would mean the game cannot be installed at all.
;  * No "run now" checkbox on the finish page. On a machine with a projector
;    this is how a lesson accidentally starts with the game already open.
;  * Uninstall removes the program files, but *not* the save game. A child's
;    progress lives in %APPDATA% and surviving a reinstall is the whole point.
; ---------------------------------------------------------------------------

Unicode true
ManifestDPIAware true

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

!ifndef APP_VERSION
  !define APP_VERSION "1.0.0"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required (the folder holding the exported JackOLantern.exe)."
!endif
!ifndef OUT_FILE
  !error "OUT_FILE is required (the .exe installer to write)."
!endif
!ifndef ICON_FILE
  !error "ICON_FILE is required (a .ico holding 16/32/48/64/128/256 px images)."
!endif

; VIProductVersion accepts only four dot-separated numbers, while the version we
; show to the user may be "1.0.0". Keeping the two apart means bumping the
; release version never silently leaves a stale 1.0.0.0 inside the file
; properties. build_release.sh passes both.
!ifndef APP_VERSION4
  !define APP_VERSION4 "1.0.0.0"
!endif

!define APP_NAME    "Jack o' Lantern"
!define APP_TITLE   "Jack o' Lantern - The 40 Magic Flames"
!define APP_PUBLISHER "Jack o' Lantern"
!define APP_EXE     "JackOLantern.exe"
!define APP_KEY     "JackOLantern40MagicFlames"
!define UNINST_KEY  "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_KEY}"

Name "${APP_TITLE}"
BrandingText "${APP_TITLE} ${APP_VERSION}"
OutFile "${OUT_FILE}"
; Best compression: the payload is a Godot binary, which compresses ~2:1, and
; a teacher copying this to a USB stick cares about the size more than the
; extra minute it takes to build.
SetCompressor /SOLID lzma
SetCompressorDictSize 64

; Per-user, so no RequestExecutionLevel admin.
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\JackOLantern"
InstallDirRegKey HKCU "Software\${APP_KEY}" "InstallDir"

VIProductVersion "${APP_VERSION4}"
VIFileVersion    "${APP_VERSION4}"
VIAddVersionKey "ProductName"     "${APP_TITLE}"
VIAddVersionKey "FileDescription" "Installer for ${APP_TITLE}"
VIAddVersionKey "CompanyName"     "${APP_PUBLISHER}"
VIAddVersionKey "LegalCopyright"  "Educational use"
VIAddVersionKey "FileVersion"     "${APP_VERSION}"
VIAddVersionKey "ProductVersion"  "${APP_VERSION}"

!define MUI_ABORTWARNING
!define MUI_ICON   "${ICON_FILE}"
!define MUI_UNICON "${ICON_FILE}"
!define MUI_WELCOMEPAGE_TITLE "Install ${APP_TITLE}"
!define MUI_WELCOMEPAGE_TEXT "This will install ${APP_TITLE} on your computer.$\r$\n$\r$\nIt is a gentle 3D English game for 7-year-olds: forty missions, a spoken story, and no way to lose.$\r$\n$\r$\nClick Next to continue."
!define MUI_FINISHPAGE_TITLE "All done!"
!define MUI_FINISHPAGE_TEXT "${APP_TITLE} is installed.$\r$\n$\r$\nYou can start it from the Start Menu whenever you like."
!define MUI_FINISHPAGE_NOAUTOCLOSE

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Italian"

; --- Install ---------------------------------------------------------------
Section "Game" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"

  ; /r recurses the export folder. With embed_pck the export is a single .exe,
  ; and that is all this ships today; the recursion is there so that adding an
  ; optional data folder later does not silently produce a game that starts and
  ; then cannot find its files.
  File /r "${SOURCE_DIR}\*.*"

  ; The readme is optional so this script still compiles during a quick test
  ; build, but build_release.sh always passes it: a teacher who is handed only
  ; the setup file would otherwise never see where the save games live or what
  ; to do when there is no sound.
  !ifdef README_FILE
    File "/oname=README.txt" "${README_FILE}"
  !endif

  ; A stale shortcut from a previous version could point at a deleted exe if the
  ; install directory changed, so both are always rewritten.
  WriteRegStr HKCU "Software\${APP_KEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\${APP_KEY}" "Version" "${APP_VERSION}"

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_TITLE}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"

  ; Desktop shortcut: many classrooms launch everything from the desktop, and a
  ; seven-year-old will not find the Start Menu on their own.
  CreateShortCut "$DESKTOP\${APP_TITLE}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0

  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayName"     "${APP_TITLE}"
  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayVersion"  "${APP_VERSION}"
  WriteRegStr   HKCU "${UNINST_KEY}" "Publisher"       "${APP_PUBLISHER}"
  WriteRegStr   HKCU "${UNINST_KEY}" "DisplayIcon"     "$INSTDIR\${APP_EXE}"
  WriteRegStr   HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr   HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1

  ; Size shown in "Apps & features". GetSize needs the path to exist by now.
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINST_KEY}" "EstimatedSize" "$0"
SectionEnd

; --- Uninstall -------------------------------------------------------------
Section "Uninstall"
  ; The running game must not be deleted underneath itself. Killing by image
  ; name is deliberate: a child may have left it open, and refusing to uninstall
  ; because of that would be a dead end for the teacher.
  nsExec::Exec 'taskkill /IM "${APP_EXE}" /F'
  Pop $0

  Delete "$INSTDIR\${APP_EXE}"
  Delete "$INSTDIR\*.pck"
  Delete "$INSTDIR\README.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR"

  Delete "$SMPROGRAMS\${APP_NAME}\${APP_TITLE}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_TITLE}.lnk"

  DeleteRegKey HKCU "${UNINST_KEY}"
  DeleteRegKey HKCU "Software\${APP_KEY}"

  ; Save games are deliberately left in %APPDATA%. Reinstalling the game must
  ; not wipe a child's progress; removing that is a separate, explicit choice.
SectionEnd
