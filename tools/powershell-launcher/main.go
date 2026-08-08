package main

import (
    _ "embed"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
)

//go:embed Odc.Core.ps1
var core []byte
//go:embed ODC-Studio.ps1
var studio []byte

func main() {
    dir, err := os.MkdirTemp("", "odc-studio-")
    if err != nil { fail(err) }
    defer os.RemoveAll(dir)
    corePath := filepath.Join(dir, "Odc.Core.ps1")
    studioPath := filepath.Join(dir, "ODC-Studio.ps1")
    if err = os.WriteFile(corePath, core, 0600); err != nil { fail(err) }
    if err = os.WriteFile(studioPath, studio, 0600); err != nil { fail(err) }
    cmd := exec.Command("powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-WindowStyle", "Hidden", "-File", studioPath)
    if err = cmd.Run(); err != nil { fail(err) }
}
func fail(err error) {
    // Em build windowsgui não há console; usa uma mensagem simples via powershell.
    _ = exec.Command("powershell.exe", "-NoProfile", "-Command", fmt.Sprintf("Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('%s','ODC Studio')", escape(err.Error()))).Run()
    os.Exit(1)
}
func escape(s string) string { out := ""; for _,r := range s { if r=='\'' { out += "''" } else { out += string(r) } }; return out }
