!ifndef MIHOMO_METER_INSTALL_DIRECTORY_NSH
!define MIHOMO_METER_INSTALL_DIRECTORY_NSH

Var ExistingInstallDirectory

Function IsInstallDirectoryEmpty
    StrCpy $0 "1"
    ClearErrors
    FindFirst $1 $2 "$INSTDIR\*.*"
    IfErrors install_directory_empty_done
install_directory_empty_scan:
    StrCmp $2 "." install_directory_empty_next
    StrCmp $2 ".." install_directory_empty_next
    StrCpy $0 "0"
    Goto install_directory_empty_close
install_directory_empty_next:
    ClearErrors
    FindNext $1 $2
    IfErrors install_directory_empty_close
    Goto install_directory_empty_scan
install_directory_empty_close:
    FindClose $1
install_directory_empty_done:
FunctionEnd

Function EnsureInstallDirectoryOutsideData
    StrLen $0 "${PRODUCT_DATA_DIRECTORY}"
    StrCpy $1 "$INSTDIR" $0
    StrCmp $1 "${PRODUCT_DATA_DIRECTORY}" 0 install_directory_outside_data
    StrCpy $1 "$INSTDIR" 1 $0
    StrCmp $1 "" install_directory_is_data
    StrCmp $1 "\" install_directory_is_data install_directory_outside_data
install_directory_is_data:
    MessageBox MB_OK|MB_ICONSTOP \
        "程序不能安装到 Mihomo Meter 用户数据目录或其子目录，请选择其他位置。"
    Abort
install_directory_outside_data:
FunctionEnd

Function ValidateFreshInstallDirectory
    StrCmp $INSTDIR "" fresh_install_directory_invalid
    Call EnsureInstallDirectoryOutsideData

    ClearErrors
    CreateDirectory "$INSTDIR"
    IfErrors fresh_install_directory_unwritable

    ClearErrors
    GetFullPathName $0 "$INSTDIR"
    IfErrors fresh_install_directory_invalid
    StrCpy $INSTDIR "$0"
    Call EnsureInstallDirectoryOutsideData

    ClearErrors
    GetFullPathName $0 "$INSTDIR\.."
    IfErrors fresh_install_directory_invalid
    StrCmp $INSTDIR $0 fresh_install_directory_root

    Call IsInstallDirectoryEmpty
    StrCmp $0 "1" 0 fresh_install_directory_not_empty

    ClearErrors
    GetTempFileName $0 "$INSTDIR"
    IfErrors fresh_install_directory_unwritable
    Delete "$0"
    Return

fresh_install_directory_invalid:
    MessageBox MB_OK|MB_ICONSTOP "请选择有效的本机绝对安装目录。"
    Abort
fresh_install_directory_root:
    MessageBox MB_OK|MB_ICONSTOP \
        "不能直接安装到磁盘根目录或网络共享根目录，请选择专用程序目录。"
    Abort
fresh_install_directory_not_empty:
    MessageBox MB_OK|MB_ICONSTOP \
        "首次安装只能使用空目录，请新建或选择 Mihomo Meter 专用目录。"
    Abort
fresh_install_directory_unwritable:
    MessageBox MB_OK|MB_ICONSTOP \
        "当前用户无法写入该目录，请选择其他位置。安装器不会请求管理员权限。"
    Abort
FunctionEnd

Function IsOwnedInstallDirectory
    StrCpy $0 "0"
    IfFileExists "$INSTDIR\${PRODUCT_EXECUTABLE}" 0 owned_install_directory_done
    ClearErrors
    FileOpen $1 "$INSTDIR\${PRODUCT_INSTALL_MARKER}" r
    IfErrors owned_install_directory_done
    ClearErrors
    FileRead $1 $2
    IfErrors owned_install_directory_close
    StrCmp $2 "${PRODUCT_INSTALL_ID}" 0 owned_install_directory_close
    StrCpy $0 "1"
owned_install_directory_close:
    FileClose $1
owned_install_directory_done:
FunctionEnd

Function EnsureExistingInstallDirectoryOwned
    StrCmp $ExistingInstallDirectory "" existing_install_directory_owned
    StrCmp $INSTDIR $ExistingInstallDirectory 0 existing_install_directory_invalid
    Call IsOwnedInstallDirectory
    StrCmp $0 "1" existing_install_directory_owned

    StrCmp $INSTDIR "${PRODUCT_DEFAULT_INSTALL_DIRECTORY}" 0 existing_install_directory_invalid
    IfFileExists "$INSTDIR\${PRODUCT_EXECUTABLE}" \
        existing_install_directory_owned existing_install_directory_invalid

existing_install_directory_invalid:
    MessageBox MB_OK|MB_ICONSTOP \
        "既有安装目录无法确认归属于 Mihomo Meter，安装已取消且不会删除该目录。"
    Abort
existing_install_directory_owned:
FunctionEnd

Function PrepareInstallDirectoryPage
    StrCmp $ExistingInstallDirectory "" install_directory_page_ready
    Abort
install_directory_page_ready:
FunctionEnd

Function ValidateInstallDirectoryPage
    Call ValidateFreshInstallDirectory
FunctionEnd

Function un.IsOwnedInstallDirectory
    StrCpy $0 "0"
    IfFileExists "$INSTDIR\${PRODUCT_EXECUTABLE}" 0 un_owned_install_directory_done
    ClearErrors
    FileOpen $1 "$INSTDIR\${PRODUCT_INSTALL_MARKER}" r
    IfErrors un_owned_install_directory_done
    ClearErrors
    FileRead $1 $2
    IfErrors un_owned_install_directory_close
    StrCmp $2 "${PRODUCT_INSTALL_ID}" 0 un_owned_install_directory_close
    StrCpy $0 "1"
un_owned_install_directory_close:
    FileClose $1
un_owned_install_directory_done:
FunctionEnd

!endif
