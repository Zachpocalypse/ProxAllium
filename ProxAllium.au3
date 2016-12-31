; USE THIS PROGRAM AT YOUR OWN RISK
; THIS PROGRAM IS CURRENTLY AT VERY EARLY STAGES - Not suitable for normal use!

#NoTrayIcon

#Region Includes
#include <Array.au3>
#include <Color.au3>
#include <ColorConstants.au3>
#include <EditConstants.au3>
#include <FileConstants.au3>
#include <FontConstants.au3>
#include <GuiEdit.au3>
#include <StringConstants.au3>
#include <TrayConstants.au3>
#include "Tor.au3"
#EndRegion Includes

#Region Tray Creation
Opt("TrayMenuMode", 1 + 2) ; No default menu and automatic checkmarks
Opt("TrayOnEventMode", 1) ; OnEvent mode
Opt("TrayAutoPause", 0) ; No Auto-Pause

TrayItemSetState(TrayCreateItem("ProxAllium"), $TRAY_DISABLE)
TrayCreateItem("")
Global $g_idTrayTorOutputToggle = TrayCreateItem("Show Tor Output")
TrayItemSetOnEvent($g_idTrayTorOutputToggle, "GUI_ToggleTorOutputWindow")
TrayCreateItem("")
TrayItemSetOnEvent(TrayCreateItem("Exit"), "GUI_Exit")
TraySetState($TRAY_ICONSTATE_SHOW)
#EndRegion Tray Creation

#Region GUI Functions
Opt("GUIOnEventMode", 1)

Func GUI_CreateLogWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hLogGUI = GUICreate("ProxAllium", $eiGuiWidth, $eiGuiHeight, Default, Default, $WS_OVERLAPPEDWINDOW)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_Exit")
	Global $g_idLogCtrl = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hLogCtrl = GUICtrlGetHandle($g_idLogCtrl) ; Get the handle of the Edit control for future use in GUI_LogOut
	GUICtrlSetFont($g_idLogCtrl, 9, Default, Default, "Consolas")
	GUISetState(@SW_SHOW, $g_hLogGUI) ; Make the GUI visible
EndFunc

Func GUI_LogOut($sText, $bEOL = True)
	If $bEOL Then $sText &= @CRLF
	_GUICtrlEdit_AppendText($g_hLogCtrl, $sText)
	ConsoleWrite($sText)
EndFunc

Func GUI_CreateTorOutputWindow()
	Local Const $eiGuiWidth = 580, $eiGuiHeight = 280
	Global $g_hTorGUI = GUICreate("Tor Output", $eiGuiWidth, $eiGuiHeight, Default, Default, $WS_OVERLAPPEDWINDOW)
	GUISetOnEvent($GUI_EVENT_CLOSE, "GUI_Exit")
	Global $g_idTorOutput = GUICtrlCreateEdit("", 0, 0, $eiGuiWidth, $eiGuiHeight, BitOR($ES_READONLY, $ES_MULTILINE, $WS_VSCROLL, $ES_AUTOVSCROLL))
	Global $g_hTorOutput = GUICtrlGetHandle($g_idTorOutput) ; Get the handle of the Edit control for future use in the Tor Output Handler
	GUICtrlSetFont($g_idTorOutput, 9, Default, Default, "Consolas")
	GUICtrlSetBkColor($g_idTorOutput, $COLOR_BLACK)
	Local $aGrayCmdColor[3] = [197, 197, 197] ; CMD Text Color's combination in RGB
	Local Const $iGrayCmdColor = _ColorSetRGB($aGrayCmdColor) ; Get the RGB code of CMD Text Color
	GUICtrlSetColor($g_idTorOutput, $iGrayCmdColor)
	Local $idDummy = GUICtrlCreateDummy()
	GUICtrlSetOnEvent($idDummy, "GUI_ToggleTorOutputWindow")
	Local $aGuiAccelKeys[1][2] = [["^t", $idDummy]]
	GUISetAccelerators($aGuiAccelKeys, $g_hTorGUI)
	; Create a Dummy on $g_hLogGUI too
	GUISwitch($g_hLogGUI)
	$idDummy = GUICtrlCreateDummy()
	GUICtrlSetOnEvent($idDummy, "GUI_ToggleTorOutputWindow")
	$aGuiAccelKeys[0][1] = $idDummy
	GUISetAccelerators($aGuiAccelKeys, $g_hLogGUI)
EndFunc
#EndRegion GUI Functions

#Region Main Script
Global $g_aTorProcess[2]

GUI_CreateLogWindow()
GUI_LogOut("Starting ProxAllium... Please wait :)")

#Region Read Configuration
Global Const $CONFIG_INI = @ScriptDir & '\config.ini'

Global $g_sTorPath = IniRead($CONFIG_INI, "tor", "path", @ScriptDir & '\Tor\tor.exe')
Global $g_sTorConfigFile = IniRead($CONFIG_INI, "tor", "config_file", @ScriptDir & '\config.torrc')
Global $g_sTorDataDirPath = IniRead($CONFIG_INI, "tor", "data_dir", @ScriptDir & '\Tor\data')
Global $g_sTorGeoIPv4File = IniRead($CONFIG_INI, "tor", "geoip4_file", @ScriptDir & '\Tor\geoip')
Global $g_sTorGeoIPv6File = IniRead($CONFIG_INI, "tor", "geoip6_file", @ScriptDir & '\Tor\geoip6')
Global $g_iOutputPollInterval = Int(IniRead($CONFIG_INI, "proxallium", "output_poll_interval", "250"))

Global $g_sTorConfig_Port = IniRead($CONFIG_INI, "tor_config", "port", "9050")
Global $g_bTorConfig_OnlyLocalhost = (IniRead($CONFIG_INI, "tor_config", "localhost_only", "true") = "true")
#EndRegion Read Configuration

If Not FileExists($g_sTorConfigFile) Then
	GUI_LogOut("Cannot find Tor configuration file, generating one now... ", False)
	ProxAllium_GenTorrc()
	If @error Then ProxAllium_WaitForExit("Failed to create configuration file!")
	GUI_LogOut("Successfully generated Tor configuration file!")
EndIf

Global $g_aTorVersion = _Tor_SetPath($g_sTorPath)
Switch @error
	Case $TOR_ERROR_GENERIC
		ProxAllium_WaitForExit("Invalid Tor path!")

	Case $TOR_ERROR_VERSION
		ProxAllium_WaitForExit("Unable to identify Tor's version!")
EndSwitch
GUI_LogOut("Detected Tor version: " & $g_aTorVersion[$TOR_VERSION])

GUI_LogOut("Starting Tor... ", False)
$g_aTorProcess = _Tor_Start($g_sTorConfigFile)
Switch @error
	Case $TOR_ERROR_PROCESS
		ProxAllium_WaitForExit("Unable to start Tor!")

	Case $TOR_ERROR_CONFIG
		ProxAllium_WaitForExit("Invalid Tor configuration, please check your custom entries.")
EndSwitch
GUI_LogOut("Started Tor with PID: " & $g_aTorProcess[$TOR_PROCESS_PID])

#Region Tor Output Handler
Global $g_sTorOutputCallbackFunc

GUI_CreateTorOutputWindow()

$g_sTorOutputCallbackFunc = "ProxAllium_BootstrapHandler"

Global $g_sPartialTorOutput = ""
Global $g_aPartialTorOutput[0]
While ProcessExists($g_aTorProcess[$TOR_PROCESS_PID]) ; Loop until the Tor exits
	$g_sPartialTorOutput = StdoutRead($g_aTorProcess[$TOR_PROCESS_PID])
	If $g_sPartialTorOutput = "" Then ContinueLoop
	_GUICtrlEdit_AppendText($g_hTorOutput, $g_sPartialTorOutput)
	$g_aPartialTorOutput = StringSplit($g_sPartialTorOutput, @CRLF, $STR_ENTIRESPLIT)
	For $iLine = 1 To $g_aPartialTorOutput[0]
		Call($g_sTorOutputCallbackFunc, StringSplit($g_aPartialTorOutput[$iLine], ' '))
	Next
	Sleep($g_iOutputPollInterval) ; Don't kill the CPU
WEnd
#EndRegion Tor Output Handler

ProxAllium_WaitForExit("Tor exited with exit code: " & _Process_GetExitCode($g_aTorProcess[$TOR_PROCESS_HANDLE]))
#EndRegion Main Script

#Region GUI Handlers
Func GUI_Exit()
	ProcessClose($g_aTorProcess[$TOR_PROCESS_PID])
	GUISetState(@SW_HIDE, $g_hTorGUI)
	If @GUI_WinHandle = $g_hLogGUI Then Exit
EndFunc

Func GUI_ToggleTorOutputWindow()
	Local Static $bHidden = True
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOW, $g_hTorGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayTorOutputToggle, "Hide Tor Output")
		Return
	EndIf
	$bHidden = (GUISetState(@SW_SHOWNORMAL, $g_hTorGUI) = 1)
	If $bHidden Then TrayItemSetText($g_idTrayTorOutputToggle, "Show Tor Output")
EndFunc

Func GUI_ToggleLogWindow()
	Local Static $bHidden = False
	If $bHidden Then
		$bHidden = Not (GUISetState(@SW_SHOWNORMAL, $g_hLogGUI) = 1)
		If Not $bHidden Then TrayItemSetText($g_idTrayLogToggle, "Hide Log Window")
		Return
	EndIf
	$bHidden = (GUISetState(@SW_HIDE, $g_hLogGUI) = 1)
	If $bHidden Then TrayItemSetText($g_idTrayLogToggle, "Show Log Window")
EndFunc
#EndRegion GUI Handlers

#Region Misc. Functions
Func ProxAllium_GenTorrc()
	Local $hTorrc = FileOpen($g_sTorConfigFile, $FO_APPEND + $FO_CREATEPATH)
	If @error Then Return SetError(1, 0, False)
	FileSetPos($hTorrc, 0, $FILE_BEGIN)
	FileWriteLine($hTorrc, '## Configuration file automatically generated by ProxAllium')
	FileWriteLine($hTorrc, '## This file was generated on ' & @MDAY & '-' & @MON & '-' & @YEAR)
	FileWriteLine($hTorrc, "")
	FileWriteLine($hTorrc, '## Open SOCKS proxy on the following port')
	FileWriteLine($hTorrc, 'SOCKSPort ' & $g_sTorConfig_Port)
	FileWriteLine($hTorrc, "")
	If $g_bTorConfig_OnlyLocalhost Then
		FileWriteLine($hTorrc, '## Only accept connections from localhost')
		FileWriteLine($hTorrc, 'SOCKSPolicy accept 127.0.0.1')
		FileWriteLine($hTorrc, 'SOCKSPolicy accept6 [::1]')
		FileWriteLine($hTorrc, 'SOCKSPolicy reject *')
		FileWriteLine($hTorrc, "")
	EndIf
	FileWriteLine($hTorrc, '## GeoIP Files')
	FileWriteLine($hTorrc, 'GeoIPFile ' & $g_sTorGeoIPv4File)
	FileWriteLine($hTorrc, 'GeoIPv6File ' & $g_sTorGeoIPv6File)
	FileWriteLine($hTorrc, "")
	FileWriteLine($hTorrc, '## Data Directory')
	FileWriteLine($hTorrc, 'DataDirectory ' & $g_sTorDataDirPath)
	FileSetEnd($hTorrc)
	FileClose($hTorrc)
EndFunc

Func ProxAllium_WaitForExit($sLogText = "")
	If Not $sLogText = "" Then GUI_LogOut($sLogText)
	GUI_LogOut("ProxAllium now ready to exit...")
	GUI_LogOut("Close the window by clicking X to exit ProxAllium!")
	Do
		Sleep(1000)
	Until False
EndFunc

Func ProxAllium_BootstrapHandler(ByRef $aTorOutput)
	If Not ($aTorOutput[0] >= 7 And $aTorOutput[5] = "Bootstrapped") Then Return
	Local $iPercentage = Int(StringTrimRight($aTorOutput[6], 1))
	If $iPercentage = 0 Then GUI_LogOut("Trying to build a circuit, please wait...")
	GUI_LogOut(_ArrayToString($aTorOutput, ' ', 5))
	If $iPercentage = 100 Then
		GUI_LogOut("Successfully built a circuit, Tor is now ready for use!")
		$g_sTorOutputCallbackFunc = "" ; Reset the callback function, we don't need this anyomore
	EndIf
EndFunc
#Region Misc. Functions
