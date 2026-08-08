use std::path::Path;
use serde_json::Value;

#[tauri::command]
fn odc_info(path: String) -> Result<odc::OdcInfo, String> { odc::info_file(Path::new(&path)) }
#[tauri::command]
fn odc_verify(path: String) -> bool { odc::verify(Path::new(&path)) }
#[tauri::command]
fn odc_create(input: String, output: String, metadata_json: String) -> Result<(), String> {
    let meta: Option<Value> = if metadata_json.trim().is_empty() { None } else { Some(serde_json::from_str(&metadata_json).map_err(|e| e.to_string())?) };
    odc::create_from_file(Path::new(&input), Path::new(&output), meta.as_ref(), true)
}
#[tauri::command]
fn odc_extract(input: String, output: String) -> Result<(), String> { odc::extract(Path::new(&input), Path::new(&output)) }
#[tauri::command]
fn odc_set_metadata(path: String, metadata_json: String) -> Result<(), String> {
    let meta: Option<Value> = if metadata_json.trim().is_empty() { None } else { Some(serde_json::from_str(&metadata_json).map_err(|e| e.to_string())?) };
    odc::set_metadata(Path::new(&path), meta.as_ref())
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![odc_info, odc_verify, odc_create, odc_extract, odc_set_metadata])
        .run(tauri::generate_context!())
        .expect("erro ao executar ODC Studio");
}
