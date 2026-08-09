//go:build windows

package main

import (
	"bytes"
	_ "embed"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
	"unsafe"
)

//go:embed Odc.Core.ps1
var core []byte

//go:embed ODC-Studio.ps1
var studio []byte

const createNoWindow = 0x08000000

var selfTestMode bool

func main() {
	selfTestMode = len(os.Args) > 1 && os.Args[1] == "--self-test"

	dir, err := os.MkdirTemp("", "odc-studio-")
	if err != nil {
		fail(err, "", "")
	}
	defer os.RemoveAll(dir)

	corePath := filepath.Join(dir, "Odc.Core.ps1")
	studioPath := filepath.Join(dir, "ODC-Studio.ps1")

	if err = writePowerShellFile(corePath, core); err != nil {
		fail(err, "", "")
	}
	if err = writePowerShellFile(studioPath, studio); err != nil {
		fail(err, "", "")
	}

	powershell, err := findWindowsPowerShell()
	if err != nil {
		fail(err, "", "")
	}

	args := []string{
		"-NoLogo",
		"-NoProfile",
		"-ExecutionPolicy", "Bypass",
		"-STA",
		"-File", studioPath,
	}

	cmd := exec.Command(powershell, args...)
	cmd.Dir = dir
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: createNoWindow,
	}

	if selfTestMode {
		cmd.Env = append(os.Environ(), "ODC_STUDIO_SELF_TEST=1")
	}

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr

	err = cmd.Run()
	if err != nil {
		fail(err, stdout.String(), stderr.String())
	}

	if selfTestMode && !strings.Contains(stdout.String(), "ODC_STUDIO_SELF_TEST_OK") {
		fail(errors.New("self-test não retornou o marcador esperado"), stdout.String(), stderr.String())
	}
}

func writePowerShellFile(path string, data []byte) error {
	bom := []byte{0xEF, 0xBB, 0xBF}
	payload := make([]byte, 0, len(bom)+len(data))
	payload = append(payload, bom...)

	if len(data) >= 3 && bytes.Equal(data[:3], bom) {
		payload = append(payload, data[3:]...)
	} else {
		payload = append(payload, data...)
	}

	return os.WriteFile(path, payload, 0600)
}

func findWindowsPowerShell() (string, error) {
	if root := os.Getenv("SystemRoot"); root != "" {
		candidate := filepath.Join(root, "System32", "WindowsPowerShell", "v1.0", "powershell.exe")
		if stat, err := os.Stat(candidate); err == nil && !stat.IsDir() {
			return candidate, nil
		}
	}

	if candidate, err := exec.LookPath("powershell.exe"); err == nil {
		return candidate, nil
	}

	return "", errors.New("Windows PowerShell 5.1 não foi encontrado")
}

func fail(runErr error, stdout, stderr string) {
	logPath := writeErrorLog(runErr, stdout, stderr)

	// Em modo de self-test, nunca exibe MessageBox. Isso evita bloquear
	// runners headless e garante que o CI receba apenas o ExitCode real.
	if selfTestMode {
		os.Exit(1)
	}

	message := "O ODC Studio PowerShell não pôde ser iniciado."
	if text := strings.TrimSpace(stderr); text != "" {
		message += "\r\n\r\nDetalhes:\r\n" + tail(text, 1800)
	} else {
		message += "\r\n\r\nDetalhes: " + runErr.Error()
	}

	if logPath != "" {
		message += "\r\n\r\nLog completo:\r\n" + logPath
	}

	messageBox(message, "ODC Studio", 0x00000010)
	os.Exit(1)
}

func writeErrorLog(runErr error, stdout, stderr string) string {
	base := os.Getenv("LOCALAPPDATA")
	if base == "" {
		base = os.TempDir()
	}

	dir := filepath.Join(base, "ODC", "Logs")
	if err := os.MkdirAll(dir, 0755); err != nil {
		return ""
	}

	name := "ODC-Studio-" + time.Now().Format("20060102-150405") + ".log"
	path := filepath.Join(dir, name)

	content := fmt.Sprintf(
		"ODC Studio PowerShell launcher\r\n"+
			"Timestamp: %s\r\n"+
			"Erro: %v\r\n\r\n"+
			"STDOUT:\r\n%s\r\n\r\n"+
			"STDERR:\r\n%s\r\n",
		time.Now().Format(time.RFC3339),
		runErr,
		stdout,
		stderr,
	)

	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		return ""
	}

	return path
}

func tail(text string, max int) string {
	if len(text) <= max {
		return text
	}
	return "...\r\n" + text[len(text)-max:]
}

func messageBox(text, caption string, flags uintptr) {
	user32 := syscall.NewLazyDLL("user32.dll")
	proc := user32.NewProc("MessageBoxW")

	textPtr, _ := syscall.UTF16PtrFromString(text)
	captionPtr, _ := syscall.UTF16PtrFromString(caption)

	_, _, _ = proc.Call(
		0,
		uintptr(unsafe.Pointer(textPtr)),
		uintptr(unsafe.Pointer(captionPtr)),
		flags,
	)
}
