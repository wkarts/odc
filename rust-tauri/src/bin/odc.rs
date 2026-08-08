use odc::{create_from_file, extract, info_file, set_metadata, verify};
use serde_json::Value;
use std::{env, fs, path::Path};

fn usage() {
    eprintln!(
        "Uso:\n  odc info <arquivo.odc>\n  odc verify <arquivo.odc>\n  odc extract <arquivo.odc> <saida>\n  odc create <entrada> <saida.odc> [metadata.json]\n  odc set-meta <arquivo.odc> <metadata.json>\n  odc remove-meta <arquivo.odc>"
    );
}

fn argument<'a>(args: &'a [String], index: usize, name: &str) -> Result<&'a str, String> {
    args.get(index)
        .map(String::as_str)
        .ok_or_else(|| format!("argumento ausente: {name}"))
}

fn read_metadata(path: &str) -> Result<Value, String> {
    let content = fs::read_to_string(path).map_err(|error| error.to_string())?;
    serde_json::from_str(&content).map_err(|error| error.to_string())
}

fn run(args: &[String]) -> Result<(), String> {
    let command = argument(args, 1, "comando")?;
    let input = argument(args, 2, "arquivo")?;

    match command {
        "info" => {
            let info = info_file(Path::new(input))?;
            let json = serde_json::to_string_pretty(&info).map_err(|error| error.to_string())?;
            println!("{json}");
            Ok(())
        }
        "verify" => {
            if verify(Path::new(input)) {
                println!("OK");
                Ok(())
            } else {
                Err("INVALIDO".into())
            }
        }
        "extract" => {
            let output = argument(args, 3, "saida")?;
            extract(Path::new(input), Path::new(output))
        }
        "create" => {
            let output = argument(args, 3, "saida.odc")?;
            let metadata = args.get(4).map(|path| read_metadata(path)).transpose()?;
            create_from_file(Path::new(input), Path::new(output), metadata.as_ref(), true)
        }
        "set-meta" => {
            let metadata_path = argument(args, 3, "metadata.json")?;
            let metadata = read_metadata(metadata_path)?;
            set_metadata(Path::new(input), Some(&metadata))
        }
        "remove-meta" => set_metadata(Path::new(input), None),
        _ => Err(format!("comando inválido: {command}")),
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if let Err(error) = run(&args) {
        usage();
        eprintln!("ERRO: {error}");
        std::process::exit(1);
    }
}
