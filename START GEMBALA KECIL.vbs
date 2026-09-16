Option Explicit

Dim shell, fileSystem, projectFolder, nodePath, launcher, exitCode
Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

projectFolder = fileSystem.GetParentFolderName(WScript.ScriptFullName)
nodePath = "C:\Program Files\nodejs\node.exe"
launcher = projectFolder & "\tool\start_local.mjs"

If Not fileSystem.FileExists(nodePath) Then
  MsgBox "Node.js tidak ditemukan. Hubungi pengembang untuk memperbaiki instalasi.", 16, "Gembala Kecil"
  WScript.Quit 1
End If

exitCode = shell.Run(Chr(34) & nodePath & Chr(34) & " " & Chr(34) & launcher & Chr(34), 0, True)
If exitCode <> 0 Then
  MsgBox "Preview atau backoffice gagal dijalankan.", 16, "Gembala Kecil"
  WScript.Quit exitCode
End If

shell.Run "http://127.0.0.1:57182/"
shell.Run "http://127.0.0.1:57183/"
