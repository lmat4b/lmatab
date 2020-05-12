#AutoIt3Wrapper_UseX64=n
Opt("MustDeclareVars", 1)
;AutoItSetOption("WinTitleMatchMode", 3) ; EXACT_MATCH!

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
#include <FileConstants.au3>
#include <MsgBoxConstants.au3>
#include <File.au3>
;=======================================
; Consts & Globals
;=======================================
Global Const $DISPATCHER_NAME									   = "CheckPoint SmartConsole" ; CHANGE_ME

;You need to modify the following paths according to your PSM Setup.
Global $CLIENT_EXECUTABLE									= "E:\Program Files (x86)\CheckPoint\SmartConsole\R80.10\PROGRAM\SmartConsole.exe" ; CHANGE_ME
Global Const $ERROR_MESSAGE_TITLE  								= "PSM " & $DISPATCHER_NAME & " Dispatcher error message"
Global Const $LOG_MESSAGE_PREFIX 								= $DISPATCHER_NAME & " Dispatcher - "

;Variables to be used by CyberArk
Global $TargetUsername
Global $TargetPassword
Global $TargetAddress
Global $ConnectionClientPID = 0

;Files to be used
;You need to modify the following paths according to your PSM Setup.
Global Const $filetemplate = "C:\Program Files (x86)\CyberArk\PSM\Components\templateSmartConsole.LoginParams"
Global Const $loginfile = "C:\Program Files (x86)\CyberArk\PSM\Components\SmartConsole.LoginParams"
;=======================================
; Code
;=======================================
Exit Main()

;=======================================
; Main
;=======================================
Func Main()

	; Init PSM Dispatcher utils wrapper

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
	
	;-------------------
	;- Build the connection
	;------------------
	Local $iFileTemplateExists = FileExists($filetemplate)
	Local $iFileLoginExists = FileExists($loginfile)
    
	LogWrite("Checking requirements: template xml file for smartconsole authentication")
	
	; IF condition to check whether TemplateFile exists.
	If Not $iFileTemplateExists Then
		LogWrite("Fallo a la hora de obtener el fichero en C:\Program Files (x86)\CyberArk\PSM\Components\SmartConsole.LoginParams. Por favor generar uno.")
		PSMGenericClient_Term()
	Else
		LogWrite("Se encontró el fichero C:\Program Files (x86)\CyberArk\PSM\Components\SmartConsole.LoginParams.")
	EndIf


	; IF condition to check whether LoginParams file exists
	LogWrite("Se comprueba la existencia del fichero xml para el logon. Se creará uno nuevo.")
	;If Not $iFileLoginExists Then
	;	LogWrite("Se intentará crear un nuevo fichero " & $loginfile & "")
	;	Local $copyAction = FileCopy($filetemplate, $loginfile)
	;	If $copyAction == 0 Then
	;		LogWrite("No se puedo crear el fichero")
	;	EndIf
	;EndIf
	
	
	Local $wasCopied = FileCopy($filetemplate, $loginfile, 1)
	If $wasCopied == 0 Then
		LogWrite("No se pudo copiar el fichero")
	;	PSMGenericClient_Term()
	EndIf
	
	;Appends nothing to the end of the file so it is now in write mode.
	Local $wasWritten = FileWrite($loginfile, "")
	If $wasWritten == 0 Then
		LogWrite("No se pudo abrir el fichero en modo escritura")
	;	PSMGenericClient_Term()
	EndIf
	
	_ReplaceStringInFile($loginfile, "USERNAMEREPLACE", $TargetUsername)
	_ReplaceStringInFile($loginfile, "IPSERVERREPLACE", $TargetAddress)
	_ReplaceStringInFile($loginfile, "PASSWORDREPLACE", $TargetPassword)
	
	LogWrite("starting client application")
	
	;launches smartconsole
	$CLIENT_EXECUTABLE = '"' & $CLIENT_EXECUTABLE & '"' & " -p " & '"' & $loginfile & '"'
	;$CLIENT_EXECUTABLE = $CLIENT_EXECUTABLE & " " & $definitiveURL

	$ConnectionClientPID = Run($CLIENT_EXECUTABLE, "", @SW_SHOWMAXIMIZED)

	if ($ConnectionClientPID == 0) Then
		Error(StringFormat("Failed to execute process [%s]", $CLIENT_EXECUTABLE, @error))
	EndIf

	; Send PID to PSM so recording/monitoring can begin
	; Notice that until we send the PID, PSM blocks all user input.
	LogWrite("sending PID to PSM")
	
	;elimina los ficheros utilizados
	
	if (PSMGenericClient_SendPID($ConnectionClientPID) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf

	; Terminate PSM Dispatcher utils wrapper and deletes generated files.
	LogWrite("Terminating Dispatcher Utils Wrapper")
	FileDelete("CKP_shmem_._authkeys.C")
	FileDelete("CKP_shmem_._sslauthkeys.C")
	FileDelete("CKP_shmem_._sslsess.C")
	FileDelete("crl_fetcher.elg")
	FileDelete("ICA_fw1ng__n46ejj_3f44f0.crl")
	Sleep(15000)
	FileDelete($loginfile)
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

	;MsgBox($MessageFlags, $ERROR_MESSAGE_TITLE, $ErrorMessage)

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
	
	if (PSMGenericClient_GetSessionProperty("Address", $TargetAddress) <> $PSM_ERROR_SUCCESS) Then
		Error(PSMGenericClient_PSMGetLastErrorString())
	EndIf
	
  EndFunc

