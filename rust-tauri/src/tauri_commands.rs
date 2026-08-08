// Copie para seu app Tauri e adicione #[tauri::command] conforme necessário.
use std::path::Path;
use crate::{info_file, verify, create_from_file};
use serde_json::Value;

pub fn odc_info(path: String) -> Result<crate::OdcInfo, String> { info_file(Path::new(&path)) }
pub fn odc_verify(path: String) -> bool { verify(Path::new(&path)) }
pub fn odc_create(input: String, output: String, metadata: Option<Value>) -> Result<(), String> {
    create_from_file(Path::new(&input), Path::new(&output), metadata.as_ref(), true)
}
