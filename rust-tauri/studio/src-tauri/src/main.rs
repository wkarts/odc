#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use serde_json::Value;
use std::path::{Path, PathBuf};
use tauri_plugin_dialog::{DialogExt, FilePath};

fn file_path_to_string(path: FilePath) -> Result<String, String> {
    path.into_path()
        .map(|value| value.to_string_lossy().into_owned())
        .map_err(|_| "Não foi possível converter o caminho selecionado.".to_string())
}

fn optional_path_to_string(path: Option<FilePath>) -> Result<Option<String>, String> {
    path.map(file_path_to_string).transpose()
}

#[tauri::command]
async fn dialog_pick_source(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let selected = app
        .dialog()
        .file()
        .set_title("Selecionar arquivo de origem")
        .blocking_pick_file();

    optional_path_to_string(selected)
}

#[tauri::command]
async fn dialog_pick_odc(app: tauri::AppHandle) -> Result<Option<String>, String> {
    let selected = app
        .dialog()
        .file()
        .set_title("Abrir container ODC")
        .add_filter("ODC", &["odc"])
        .blocking_pick_file();

    optional_path_to_string(selected)
}

#[tauri::command]
async fn dialog_save_odc(
    app: tauri::AppHandle,
    suggested_name: Option<String>,
) -> Result<Option<String>, String> {
    let mut dialog = app
        .dialog()
        .file()
        .set_title("Salvar container ODC")
        .add_filter("ODC", &["odc"]);

    if let Some(name) = suggested_name.filter(|name| !name.trim().is_empty()) {
        dialog = dialog.set_file_name(name);
    }

    optional_path_to_string(dialog.blocking_save_file())
}

#[tauri::command]
async fn dialog_save_extracted(
    app: tauri::AppHandle,
    suggested_name: Option<String>,
) -> Result<Option<String>, String> {
    let mut dialog = app.dialog().file().set_title("Salvar arquivo extraído");

    if let Some(name) = suggested_name.filter(|name| !name.trim().is_empty()) {
        dialog = dialog.set_file_name(name);
    }

    optional_path_to_string(dialog.blocking_save_file())
}

#[tauri::command]
fn odc_suggest_output(input: String) -> Result<String, String> {
    if input.trim().is_empty() {
        return Err("Selecione primeiro o arquivo de origem.".to_string());
    }

    let mut output = PathBuf::from(input);
    output.set_extension("odc");
    Ok(output.to_string_lossy().into_owned())
}

#[tauri::command]
fn odc_info(path: String) -> Result<odc::OdcInfo, String> {
    odc::info_file(Path::new(&path))
}

#[tauri::command]
fn odc_verify(path: String) -> bool {
    odc::verify(Path::new(&path))
}

#[tauri::command]
fn odc_create(input: String, output: String, metadata_json: String) -> Result<(), String> {
    if input.trim().is_empty() {
        return Err("Selecione o arquivo de origem.".to_string());
    }
    if output.trim().is_empty() {
        return Err("Selecione o destino do container ODC.".to_string());
    }

    let meta: Option<Value> = if metadata_json.trim().is_empty() {
        None
    } else {
        Some(serde_json::from_str(&metadata_json).map_err(|error| error.to_string())?)
    };

    odc::create_from_file(Path::new(&input), Path::new(&output), meta.as_ref(), true)
}

#[tauri::command]
fn odc_extract(input: String, output: String) -> Result<(), String> {
    if input.trim().is_empty() {
        return Err("Selecione um container ODC.".to_string());
    }
    if output.trim().is_empty() {
        return Err("Selecione o destino do arquivo extraído.".to_string());
    }

    odc::extract(Path::new(&input), Path::new(&output))
}

#[tauri::command]
fn odc_set_metadata(path: String, metadata_json: String) -> Result<(), String> {
    if path.trim().is_empty() {
        return Err("Selecione um container ODC.".to_string());
    }

    let meta: Option<Value> = if metadata_json.trim().is_empty() {
        None
    } else {
        Some(serde_json::from_str(&metadata_json).map_err(|error| error.to_string())?)
    };

    odc::set_metadata(Path::new(&path), meta.as_ref())
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_dialog::init())
        .invoke_handler(tauri::generate_handler![
            dialog_pick_source,
            dialog_pick_odc,
            dialog_save_odc,
            dialog_save_extracted,
            odc_suggest_output,
            odc_info,
            odc_verify,
            odc_create,
            odc_extract,
            odc_set_metadata
        ])
        .run(tauri::generate_context!())
        .expect("erro ao executar ODC Studio");
}
