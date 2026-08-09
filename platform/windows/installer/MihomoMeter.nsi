Unicode true

!include "LogicLib.nsh"
!include "MUI2.nsh"
!include "x64.nsh"

!ifndef APP_VERSION
    !error "缺少 APP_VERSION。"
!endif
!ifndef PAYLOAD_DIRECTORY
    !error "缺少 PAYLOAD_DIRECTORY。"
!endif
!ifndef OUTPUT_FILE
    !error "缺少 OUTPUT_FILE。"
!endif

!define PRODUCT_NAME "Mihomo Meter"
!define PRODUCT_PUBLISHER "HongXunPan"
!define PRODUCT_INSTALL_ID "com.HongXunPan.MihomoMeter"
!define PRODUCT_EXECUTABLE "MihomoMeter.Windows.App.exe"
!define PRODUCT_INSTALL_MARKER ".mihomo-meter-install"
!define PRODUCT_UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_INSTALL_ID}"
!define PRODUCT_DEFAULT_INSTALL_DIRECTORY "$LOCALAPPDATA\Programs\Mihomo Meter"
!define PRODUCT_DATA_DIRECTORY "$LOCALAPPDATA\HongXunPan\MihomoMeter"
!define PRODUCT_START_MENU_DIRECTORY "$SMPROGRAMS\Mihomo Meter"

Name "${PRODUCT_NAME}"
OutFile "${OUTPUT_FILE}"
InstallDir "${PRODUCT_DEFAULT_INSTALL_DIRECTORY}"
RequestExecutionLevel user
AllowRootDirInstall false
SetCompressor /SOLID lzma
SetOverwrite on
ShowInstDetails show
ShowUninstDetails show
BrandingText "Mihomo Meter"

VIProductVersion "${APP_VERSION}.0"
VIFileVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=2052 "ProductName" "${PRODUCT_NAME}"
VIAddVersionKey /LANG=2052 "CompanyName" "${PRODUCT_PUBLISHER}"
VIAddVersionKey /LANG=2052 "FileDescription" "Mihomo Meter Windows 安装器"
VIAddVersionKey /LANG=2052 "FileVersion" "${APP_VERSION}.0"
VIAddVersionKey /LANG=2052 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=2052 "LegalCopyright" "Copyright HongXunPan"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${PRODUCT_EXECUTABLE}"
!define MUI_FINISHPAGE_RUN_TEXT "运行 Mihomo Meter"

!insertmacro MUI_PAGE_WELCOME
!define MUI_PAGE_CUSTOMFUNCTION_PRE PrepareInstallDirectoryPage
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE ValidateInstallDirectoryPage
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "SimpChinese"
SetFont /LANG=${LANG_SIMPCHINESE} "Microsoft YaHei UI" 9
!include /CHARSET=UTF8 "${__FILEDIR__}\MihomoMeter.InstallDirectory.nsh"

Function EnsureApplicationStopped
install_process_check:
    nsExec::ExecToStack /TIMEOUT=10000 `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -Command "if (Get-Process -Name 'MihomoMeter.Windows.App' -ErrorAction SilentlyContinue) { exit 10 }; exit 0"`
    Pop $0
    Pop $1
    ${If} $0 == "0"
        Return
    ${ElseIf} $0 == "10"
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
            "Mihomo Meter 仍在运行。请从通知区域菜单明确退出后选择“重试”；安装器不会强制结束应用。" \
            IDRETRY install_process_check
        Abort
    ${Else}
        MessageBox MB_OK|MB_ICONSTOP \
            "无法确认 Mihomo Meter 是否正在运行，安装已取消。PowerShell 退出码：$0"
        Abort
    ${EndIf}
FunctionEnd

Function un.EnsureApplicationStopped
uninstall_process_check:
    nsExec::ExecToStack /TIMEOUT=10000 `"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -NonInteractive -Command "if (Get-Process -Name 'MihomoMeter.Windows.App' -ErrorAction SilentlyContinue) { exit 10 }; exit 0"`
    Pop $0
    Pop $1
    ${If} $0 == "0"
        Return
    ${ElseIf} $0 == "10"
        MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION \
            "Mihomo Meter 仍在运行。请从通知区域菜单明确退出后选择“重试”；卸载器不会强制结束应用。" \
            IDRETRY uninstall_process_check
        Abort
    ${Else}
        MessageBox MB_OK|MB_ICONSTOP \
            "无法确认 Mihomo Meter 是否正在运行，卸载已取消。PowerShell 退出码：$0"
        Abort
    ${EndIf}
FunctionEnd

Function .onInit
    ${IfNot} ${RunningX64}
        MessageBox MB_OK|MB_ICONSTOP "Mihomo Meter 当前只支持 Windows 10 22H2 x64 或更高版本。"
        Abort
    ${EndIf}
    SetShellVarContext current
    SetRegView 64
    ReadRegStr $ExistingInstallDirectory HKCU \
        "${PRODUCT_UNINSTALL_KEY}" "InstallLocation"
    StrCmp $ExistingInstallDirectory "" existing_install_directory_loaded
    StrCpy $INSTDIR "$ExistingInstallDirectory"
    Call EnsureExistingInstallDirectoryOwned
existing_install_directory_loaded:
    Call EnsureApplicationStopped
FunctionEnd

Function un.onInit
    ${IfNot} ${RunningX64}
        MessageBox MB_OK|MB_ICONSTOP "Mihomo Meter 当前只支持 Windows x64。"
        Abort
    ${EndIf}
    SetShellVarContext current
    Call un.EnsureApplicationStopped
FunctionEnd

Section "Mihomo Meter" MainSection
    SectionIn RO
    SetShellVarContext current
    SetRegView 64
    Call EnsureApplicationStopped

    StrCmp $ExistingInstallDirectory "" fresh_install_directory_ready
    Call EnsureExistingInstallDirectoryOwned
    ClearErrors
    RMDir /r "$INSTDIR"
    IfErrors 0 install_directory_ready
    MessageBox MB_OK|MB_ICONSTOP \
        "旧版本程序文件仍被占用，安装已取消。请确认 Mihomo Meter 已完全退出。"
    Abort
fresh_install_directory_ready:
    Call ValidateFreshInstallDirectory
install_directory_ready:

    SetOutPath "$INSTDIR"
    File /r "${PAYLOAD_DIRECTORY}\*.*"
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    ClearErrors
    FileOpen $0 "$INSTDIR\${PRODUCT_INSTALL_MARKER}" w
    IfErrors install_marker_failed
    FileWrite $0 "${PRODUCT_INSTALL_ID}"
    FileClose $0
    SetFileAttributes "$INSTDIR\${PRODUCT_INSTALL_MARKER}" HIDDEN
    Goto install_marker_ready
install_marker_failed:
    SetOutPath "$TEMP"
    RMDir /r "$INSTDIR"
    MessageBox MB_OK|MB_ICONSTOP \
        "无法写入安装目录所有权标记，安装已取消且已清理程序文件。"
    Abort
install_marker_ready:

    CreateDirectory "${PRODUCT_START_MENU_DIRECTORY}"
    CreateShortcut \
        "${PRODUCT_START_MENU_DIRECTORY}\Mihomo Meter.lnk" \
        "$INSTDIR\${PRODUCT_EXECUTABLE}"

    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayName" "${PRODUCT_NAME}"
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${PRODUCT_EXECUTABLE},0"
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKCU "${PRODUCT_UNINSTALL_KEY}" "URLInfoAbout" \
        "https://github.com/HongXunPan/mihomo-meter"
    WriteRegDWORD HKCU "${PRODUCT_UNINSTALL_KEY}" "NoModify" 1
    WriteRegDWORD HKCU "${PRODUCT_UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
    SetShellVarContext current
    SetRegView 64
    Call un.EnsureApplicationStopped

    ReadRegStr $0 HKCU "${PRODUCT_UNINSTALL_KEY}" "InstallLocation"
    StrCmp $0 $INSTDIR 0 uninstall_path_invalid
    Call un.IsOwnedInstallDirectory
    StrCmp $0 "1" 0 uninstall_path_invalid

    StrLen $1 "${PRODUCT_DATA_DIRECTORY}"
    StrCpy $2 "$INSTDIR" $1
    StrCmp $2 "${PRODUCT_DATA_DIRECTORY}" 0 uninstall_path_outside_data
    StrCpy $2 "$INSTDIR" 1 $1
    StrCmp $2 "" uninstall_path_invalid
    StrCmp $2 "\" uninstall_path_invalid uninstall_path_outside_data
uninstall_path_outside_data:
    ClearErrors
    GetFullPathName $1 "$INSTDIR\.."
    IfErrors uninstall_path_invalid
    StrCmp $INSTDIR $1 uninstall_path_invalid
    Goto uninstall_path_valid

uninstall_path_invalid:
    MessageBox MB_OK|MB_ICONSTOP \
        "卸载目录身份或安全边界校验失败，卸载已取消且不会删除该目录。"
    Abort
uninstall_path_valid:

    SetOutPath "$TEMP"
    ClearErrors
    RMDir /r "$INSTDIR"
    IfErrors 0 uninstall_files_removed
        MessageBox MB_OK|MB_ICONSTOP \
            "程序文件未能完整移除，卸载已停止；用户数据和卸载入口保持不变。"
        Abort
uninstall_files_removed:
    Delete "${PRODUCT_START_MENU_DIRECTORY}\Mihomo Meter.lnk"
    RMDir "${PRODUCT_START_MENU_DIRECTORY}"
    DeleteRegKey HKCU "${PRODUCT_UNINSTALL_KEY}"
SectionEnd
