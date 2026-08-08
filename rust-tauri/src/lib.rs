use flate2::{read::GzDecoder, write::GzEncoder, Compression};
use serde::Serialize;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::{
    fs,
    io::{Read, Write},
    path::Path,
};

pub const HEADER: usize = 24;
pub const CH: usize = 12;
pub const FILE_NAME: u16 = 0x0001;
pub const MIME: u16 = 0x0002;
pub const META: u16 = 0x0003;
pub const ORIGINAL_SIZE: u16 = 0x0004;
pub const COMPRESSION: u16 = 0x0010;
pub const SHA256: u16 = 0x0020;
pub const PAYLOAD: u16 = 0x0100;

#[derive(Debug, Clone, Serialize)]
pub struct Chunk {
    pub chunk_type: u16,
    pub flags: u16,
    pub length: u64,
    pub header_offset: u64,
    pub data_offset: u64,
}

#[derive(Debug, Serialize)]
pub struct OdcInfo {
    pub version: String,
    pub flags: u32,
    pub chunk_count: u32,
    pub file_name: String,
    pub mime_type: String,
    pub original_size: u64,
    pub stored_payload_size: u64,
    pub compression: String,
    pub sha256: String,
    pub metadata: Option<Value>,
    pub chunks: Vec<Chunk>,
}

fn le16(bytes: &[u8]) -> u16 {
    u16::from_le_bytes([bytes[0], bytes[1]])
}

fn le32(bytes: &[u8]) -> u32 {
    u32::from_le_bytes(bytes.try_into().expect("slice u32 validada"))
}

fn le64(bytes: &[u8]) -> u64 {
    u64::from_le_bytes(bytes.try_into().expect("slice u64 validada"))
}

fn put_chunk(out: &mut Vec<u8>, chunk_type: u16, data: &[u8]) {
    out.extend_from_slice(&chunk_type.to_le_bytes());
    out.extend_from_slice(&0_u16.to_le_bytes());
    out.extend_from_slice(&(data.len() as u64).to_le_bytes());
    out.extend_from_slice(data);
}

fn should_gzip(mime: &str, size: usize) -> bool {
    size >= 768
        && (mime.starts_with("text/")
            || matches!(
                mime,
                "application/json"
                    | "application/xml"
                    | "application/javascript"
                    | "application/sql"
            )
            || mime.ends_with("+json")
            || mime.ends_with("+xml"))
}

pub fn scan(data: &[u8]) -> Result<(u32, Vec<Chunk>), String> {
    if data.len() < HEADER || &data[..4] != b"ODC1" {
        return Err("ODC inválido/truncado".into());
    }

    let major = le16(&data[4..6]);
    let flags = le32(&data[8..12]);
    let header_size = le32(&data[12..16]);
    let chunk_count = le32(&data[16..20]);

    if major != 1 || header_size != HEADER as u32 || chunk_count > 1_000_000 {
        return Err("header não suportado".into());
    }

    let mut offset = HEADER;
    let mut chunks = Vec::with_capacity(chunk_count as usize);

    for _ in 0..chunk_count {
        if offset + CH > data.len() {
            return Err("chunk truncado".into());
        }

        let chunk_type = le16(&data[offset..offset + 2]);
        let chunk_flags = le16(&data[offset + 2..offset + 4]);
        let length = le64(&data[offset + 4..offset + 12]);
        let data_offset = offset + CH;

        if length > usize::MAX as u64
            || data_offset
                .checked_add(length as usize)
                .is_none_or(|end| end > data.len())
        {
            return Err("comprimento inválido".into());
        }

        chunks.push(Chunk {
            chunk_type,
            flags: chunk_flags,
            length,
            header_offset: offset as u64,
            data_offset: data_offset as u64,
        });

        offset = data_offset + length as usize;
    }

    Ok((flags, chunks))
}

fn one<'a>(
    data: &'a [u8],
    chunks: &[Chunk],
    chunk_type: u16,
    max: u64,
    required: bool,
) -> Result<Option<&'a [u8]>, String> {
    if let Some(chunk) = chunks.iter().find(|chunk| chunk.chunk_type == chunk_type) {
        if chunk.length > max {
            return Err("chunk acima do limite".into());
        }

        let start = chunk.data_offset as usize;
        return Ok(Some(&data[start..start + chunk.length as usize]));
    }

    if required {
        Err(format!("chunk ausente {chunk_type:04x}"))
    } else {
        Ok(None)
    }
}

pub fn create_from_file(
    input: &Path,
    output: &Path,
    metadata: Option<&Value>,
    compress: bool,
) -> Result<(), String> {
    let raw = fs::read(input).map_err(|error| error.to_string())?;
    let mime = mime_guess::from_path(input)
        .first_or_octet_stream()
        .essence_str()
        .to_string();

    let mut payload = raw.clone();
    let mut compression = 0_u8;

    if compress && should_gzip(&mime, raw.len()) {
        let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
        encoder
            .write_all(&raw)
            .map_err(|error| error.to_string())?;
        let compressed = encoder.finish().map_err(|error| error.to_string())?;

        if compressed.len() + 64 < raw.len() {
            payload = compressed;
            compression = 1;
        }
    }

    let hash = Sha256::digest(&raw);
    let chunk_count = 6 + u32::from(metadata.is_some());
    let mut out = Vec::with_capacity(payload.len() + 512);

    out.extend_from_slice(b"ODC1");
    out.extend_from_slice(&1_u16.to_le_bytes());
    out.extend_from_slice(&0_u16.to_le_bytes());
    out.extend_from_slice(&(if compression == 1 { 1_u32 } else { 0 }).to_le_bytes());
    out.extend_from_slice(&(HEADER as u32).to_le_bytes());
    out.extend_from_slice(&chunk_count.to_le_bytes());
    out.extend_from_slice(&0_u32.to_le_bytes());

    put_chunk(
        &mut out,
        FILE_NAME,
        input
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .as_bytes(),
    );
    put_chunk(&mut out, MIME, mime.as_bytes());

    if let Some(metadata) = metadata {
        let json = serde_json::to_vec(metadata).map_err(|error| error.to_string())?;
        put_chunk(&mut out, META, &json);
    }

    put_chunk(&mut out, ORIGINAL_SIZE, &(raw.len() as u64).to_le_bytes());
    put_chunk(&mut out, COMPRESSION, &[compression]);
    put_chunk(&mut out, SHA256, &hash);
    put_chunk(&mut out, PAYLOAD, &payload);

    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }

    let temp = output.with_extension("odc.tmp");
    fs::write(&temp, out).map_err(|error| error.to_string())?;

    if output.exists() {
        fs::remove_file(output).map_err(|error| error.to_string())?;
    }

    fs::rename(temp, output).map_err(|error| error.to_string())?;
    Ok(())
}

pub fn info_file(path: &Path) -> Result<OdcInfo, String> {
    let data = fs::read(path).map_err(|error| error.to_string())?;
    let (flags, chunks) = scan(&data)?;

    let file_name = String::from_utf8_lossy(
        one(&data, &chunks, FILE_NAME, 1 << 20, true)?.expect("chunk obrigatório validado"),
    )
    .into_owned();
    let mime_type = String::from_utf8_lossy(
        one(&data, &chunks, MIME, 1 << 20, true)?.expect("chunk obrigatório validado"),
    )
    .into_owned();
    let original_size = le64(
        one(&data, &chunks, ORIGINAL_SIZE, 8, true)?.expect("chunk obrigatório validado"),
    );
    let compression = one(&data, &chunks, COMPRESSION, 1, true)?
        .expect("chunk obrigatório validado")[0];
    let sha256 = hex::encode(
        one(&data, &chunks, SHA256, 32, true)?.expect("chunk obrigatório validado"),
    );
    let payload = chunks
        .iter()
        .find(|chunk| chunk.chunk_type == PAYLOAD)
        .ok_or("PAYLOAD ausente")?;
    let metadata = match one(&data, &chunks, META, 16 << 20, false)? {
        Some(bytes) => Some(serde_json::from_slice(bytes).map_err(|error| error.to_string())?),
        None => None,
    };

    Ok(OdcInfo {
        version: "1.0".into(),
        flags,
        chunk_count: chunks.len() as u32,
        file_name,
        mime_type,
        original_size,
        stored_payload_size: payload.length,
        compression: if compression == 1 {
            "gzip".into()
        } else {
            "none".into()
        },
        sha256,
        metadata,
        chunks,
    })
}

pub fn extract(path: &Path, output: &Path) -> Result<(), String> {
    let data = fs::read(path).map_err(|error| error.to_string())?;
    let (_, chunks) = scan(&data)?;
    let payload = chunks
        .iter()
        .find(|chunk| chunk.chunk_type == PAYLOAD)
        .ok_or("PAYLOAD ausente")?;
    let start = payload.data_offset as usize;
    let packed = &data[start..start + payload.length as usize];
    let compression = one(&data, &chunks, COMPRESSION, 1, true)?
        .expect("chunk obrigatório validado")[0];

    let raw = match compression {
        0 => packed.to_vec(),
        1 => {
            let mut decoder = GzDecoder::new(packed);
            let mut decoded = Vec::new();
            decoder
                .read_to_end(&mut decoded)
                .map_err(|error| error.to_string())?;
            decoded
        }
        _ => return Err("compressão não suportada".into()),
    };

    let expected_size = le64(
        one(&data, &chunks, ORIGINAL_SIZE, 8, true)?.expect("chunk obrigatório validado"),
    );
    if raw.len() as u64 != expected_size {
        return Err("tamanho divergente".into());
    }

    let expected_hash =
        one(&data, &chunks, SHA256, 32, true)?.expect("chunk obrigatório validado");
    let actual_hash = Sha256::digest(&raw);
    if expected_hash != &actual_hash[..] {
        return Err("SHA-256 inválido".into());
    }

    if let Some(parent) = output.parent() {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    fs::write(output, raw).map_err(|error| error.to_string())
}

pub fn verify(path: &Path) -> bool {
    let temp = std::env::temp_dir().join(format!("odc-verify-{}", std::process::id()));
    let valid = extract(path, &temp).is_ok();
    let _ = fs::remove_file(temp);
    valid
}

pub fn set_metadata(path: &Path, metadata: Option<&Value>) -> Result<(), String> {
    let info = info_file(path)?;
    let temp = std::env::temp_dir().join(format!(
        "odc-meta-{}-{}",
        std::process::id(),
        info.file_name
    ));

    extract(path, &temp)?;
    let result = create_from_file(&temp, path, metadata, info.compression == "gzip");
    let _ = fs::remove_file(temp);
    result
}
