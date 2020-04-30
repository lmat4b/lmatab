#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
AutoItSetOption("WinTitleMatchMode", 3) ; EXACT_MATCH!

;============================================================
;             PSM AutoIt Dispatcher Skeleton
;             ------------------------------
;
; Use this skeleton to create your own
; connection components integrated with the PSM.
; Areas you may want to modify are marked
; with the string "CHANGE_ME".
;
; Created : April 2013
; Cyber-Ark Software Ltd.
;============================================================
#include "PSMGenericClientWrapper.au3"
#include <AutoItConstants.au3>
;#include <FileConstants.au3>
;#include <MsgBoxConstants.au3>
;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME									= "VMWare Remote Console" ; CHANGE_ME
Global $CLIENT_EXECUTABLE									= "E:\Program Files (x86)\Remote Console Vmware\vmrc.exe" ; CHANGE_ME
Global Const $ERROR_MESSAGE_TITLE  								= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX 								= $DISPATCHER_NAME & " Dispatcher - "

Global $TargetUsername
Global $TargetPassword
Global $LogonAccount
Global $LogonAccountPwd
Global $TargetAddress
Global $TargetMoid
Global $Perimeter
Global $ConnectionClientPID = 0
Global $hostname = "production.vcenter.local"

;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main
;=======================================
Func Main()

	; Init PSM Dispatcher utils wrapper
	ToolTip ("Initializing...")
	if (PSMGenericClient_Init() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	LogWrite("successfully initialized Dispatcher Utils Wrapper")

	; Get the dispatcher parameters
	FetchSessionProperties()

	LogWrite("mapping local drives")
	if (PSMGenericClient_MapTSDrives() <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	LogWrite("starting client application")
	ToolTip ("Starting " & $DISPATCHER_NAME & "...")
	
	;As I didn't want to update a new file category for every account, I decided to set the default value to the production vCenter and just 
	;for those VMs from the contingency vCenter, I created the perimeter file category which would contain the following value: Disasterrecovery.
	;This will be checked by this if statement.As I didn't want to update a new file category for every account, I decided to set 
	;the default value to the production vCenter and just for those VMs from the contingency vCenter, I created the perimeter file category which would contain the following value: Disasterrecovery.
	;This will be checked by this if statement.
	if ($Perimeter == "Disasterrecovery") Then
		$hostname = "contingency.vcenter.local"
	EndIf
	
	
	;Using the official VMWare syntax, we will use the parameters retrieved from PSM for the account.
	$CLIENT_EXECUTABLE = "E:\Program Files (x86)\Remote Console Vmware\vmrc.exe vmrc://"& $LogonAccount & "@" & $hostname & "/?moid=" & $TargetMoid & ""
	;The previous command is executed and its PID is stored.
	$ConnectionClientPID = Run($CLIENT_EXECUTABLE, "", @SW_MAXIMIZE, "")

	WinWaitActive("[CLASS:VMPlayerFrame]", "", 20)
	
	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $CLIENT_EXECUTABLE, @error))
	EndIf 
	
	

	; ------------------
	; Handle login vCenter here! ; CHANGE_ME
	; ------------------
	
	; This is something to be changed using your AutoIt tool as I created one for my VMRC version. Besides, it expects spanish as the vmrc language.
	ControlFocus("Conectarse al servidor", "", "[CLASS:Edit; INSTANCE:3]")
	Sleep(200)
	;Sends the password to the second input (the user inputis filled in the execution command by "LogonACcount"
	Send($LogonAccountPwd, 1)
	;Tooltip("found!!")


	;Clicks the submit button
	Sleep(800)
	ControlClick("Conectarse al servidor", "", "[CLASS:Button; INSTANCE:2]")
	
	Sleep(200)
	Tooltip( "Mmmm... That was surprisingly easy" )
	
	;Will wait for the security prompt and will accept the risk
	WinWaitActive("Certificado de seguridad no válido", "", 6)
	Sleep(100)
	ControlClick("Certificado de seguridad no válido", "", "[CLASS:Button; INSTANCE:3]")
	Sleep(200)
	
	
	
	
	
	WinWaitActive("[CLASS:VMPlayerFrame]", "", 15)
	Sleep(10000)
	
	;====================== READ NEXT LINES. THESE ARE OPTIONAL ====================================
	;===============================================================================================
	;If you choose not to use the following lines, the scrip works fine but it wont try to log you in the system.
	;The following lines are just for Windows (tested in WS12) and they are not 100% efficient yet.
	
	;Will focus on the window and select the FILE tab.
	ControlClick("[CLASS:VMPlayerFrame]", "", "[CLASS:MKSEmbedded; INSTANCE:1]")

	Send("{ENTER}")
	Sleep(4000)
	;Tooltip(" Wait a second... let's try something! ")
	ControlClick("[CLASS:VMPlayerFrame]", "", "[CLASS:wui.unibar.Toolbar; INSTANCE:1]")
	Sleep(800)
	
	;Selects the 'Send ctrl+alt+del' option
	Send("{DOWN 3}")
	Sleep(200)
	Send("{ENTER}")

	;Tooltip(" Hell yeah! So much fun. ")
	Sleep(600)
	
	
	;Tries to enter password in Windows.
	MouseClick($MOUSE_CLICK_LEFT, 332, 268, 2)
	Sleep(300)
	ControlClick("[CLASS:VMPlayerFrame]", "", "[CLASS:MKSEmbedded; INSTANCE:1]", "left", 1, 319, 270)

	Sleep(200)
	Send($TargetPassword)

	Sleep(500)
	Send("{ENTER}")
	
	;===============================================================================================
	;===============================================================================================
	
	
	
	
	
	
	LogWrite("sending PID to PSM")
	if (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	; Terminate PSM Dispatcher utils wrapper
	LogWrite("Terminating Dispatcher Utils Wrapper")
	PSMGenericClient_Term()

	Return $PSM_ERROR_SUCCESS
EndFunc

;==================================
; Functions
;==================================
; #FUNCTION# ====================================================================================================================
; Name...........: Error
; Description ...: An exception handler - displays an error message and terminates the dispatcher
; Parameters ....: $ErrorMessage - Error message to display
; 				   $Code 		 - [Optional] Exit error code
; ===============================================================================================================================
Func Error($ErrorMessage, $Code = -1)

	; If the dispatcher utils DLL was already initialized, write an error log message and terminate the wrapper
	if (PSMGenericClient_IsInitialized()) Then
		LogWrite($ErrorMessage, True)
		PSMGenericClient_Term()
	EndIf

	Local $MessageFlags = BitOr(0, 16, 262144) ; 0=OK button, 16=Stop-sign icon, 262144=MsgBox has top-most attribute set

	MsgBox($MessageFlags, $ERROR_MESSAGE_TITLE, $ErrorMessage)

	; If the connection component was already invoked, terminate it
	if ($ConnectionClientPID <> 0) Then
		ProcessClose($ConnectionClientPID)
		$ConnectionClientPID = 0
	EndIf

	Exit $Code
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: LogWrite
; Description ...: Write a PSMWinSCPDispatcher log message to standard PSM log file
; Parameters ....: $sMessage - [IN] The message to write
;                  $LogLevel - [Optional] [IN] Defined if the message should be handled as an error message or as a trace messge
; Return values .: $PSM_ERROR_SUCCESS - Success, otherwise error - Use PSMGenericClient_PSMGetLastErrorString for details.
; ===============================================================================================================================
Func LogWrite($sMessage, $LogLevel = $LOG_LEVEL_TRACE)
	Return PSMGenericClient_LogWrite($LOG_MESSAGE_PREFIX & $sMessage, $LogLevel)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name...........: PSMGenericClient_GetSessionProperty
; Description ...: Fetches properties required for the session
; Parameters ....: None
; Return values .: None
; ===============================================================================================================================
Func FetchSessionProperties() ; CHANGE_ME
	if (PSMGenericClient_GetSessionProperty("Username", $TargetUsername) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	if (PSMGenericClient_GetSessionProperty("Password", $TargetPassword) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	if (PSMGenericClient_GetSessionProperty("Perimeter", $Perimeter) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("MoID", $TargetMoid) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("LogonAccount_Username", $LogonAccount) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
	if (PSMGenericClient_GetSessionProperty("LogonAccount_Password", $LogonAccountPwd) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

EndFunc
