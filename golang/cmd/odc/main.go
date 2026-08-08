package main

import (
	"encoding/json"
	"example.com/odc/odc"
	"fmt"
	"os"
)

var version = "dev"

func die(e error) { fmt.Fprintln(os.Stderr, "ERRO:", e); os.Exit(1) }
func main() {
	if len(os.Args) == 2 && os.Args[1] == "version" {
		fmt.Println(version)
		return
	}
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "Uso: odc info|verify|extract|create|set-meta|remove-meta|version ...")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "info":
		i, e := odc.InfoFile(os.Args[2])
		if e != nil {
			die(e)
		}
		b, _ := json.MarshalIndent(i, "", "  ")
		fmt.Println(string(b))
	case "verify":
		if odc.Verify(os.Args[2]) {
			fmt.Println("OK")
		} else {
			fmt.Println("INVALIDO")
			os.Exit(1)
		}
	case "extract":
		if len(os.Args) < 4 {
			os.Exit(2)
		}
		if e := odc.Extract(os.Args[2], os.Args[3]); e != nil {
			die(e)
		}
	case "create":
		if len(os.Args) < 4 {
			os.Exit(2)
		}
		m := map[string]any{}
		if len(os.Args) > 4 {
			b, e := os.ReadFile(os.Args[4])
			if e != nil {
				die(e)
			}
			if e = json.Unmarshal(b, &m); e != nil {
				die(e)
			}
		}
		if e := odc.Create(os.Args[2], os.Args[3], m, true); e != nil {
			die(e)
		}
	case "set-meta":
		if len(os.Args) < 4 {
			os.Exit(2)
		}
		m := map[string]any{}
		b, e := os.ReadFile(os.Args[3])
		if e != nil {
			die(e)
		}
		if e = json.Unmarshal(b, &m); e != nil {
			die(e)
		}
		if e = odc.SetMetadata(os.Args[2], m); e != nil {
			die(e)
		}
	case "remove-meta":
		if e := odc.SetMetadata(os.Args[2], map[string]any{}); e != nil {
			die(e)
		}
	default:
		os.Exit(2)
	}
}
