const MAGIC = new TextEncoder().encode('ODC1');
const HEADER = 24, CH = 12;
const T = { FILE: 1, MIME: 2, META: 3, SIZE: 4, COMP: 0x10, SHA: 0x20, PAYLOAD: 0x100 };
const enc = new TextEncoder(), dec = new TextDecoder();
function u64(n) { const b = new Uint8Array(8); new DataView(b.buffer).setBigUint64(0, BigInt(n), true); return b; }
function cat(parts) { let n = 0; for (const p of parts)
    n += p.length; const out = new Uint8Array(n); let o = 0; for (const p of parts) {
    out.set(p, o);
    o += p.length;
} return out; }
function ch(t, d) { const h = new Uint8Array(CH); const v = new DataView(h.buffer); v.setUint16(0, t, true); v.setBigUint64(4, BigInt(d.length), true); return cat([h, d]); }
async function gzip(data) { const s = new Blob([data]).stream().pipeThrough(new CompressionStream('gzip')); return new Uint8Array(await new Response(s).arrayBuffer()); }
async function gunzip(data) { const s = new Blob([data]).stream().pipeThrough(new DecompressionStream('gzip')); return new Uint8Array(await new Response(s).arrayBuffer()); }
function shouldGzip(m, n) { return n >= 768 && (m.startsWith('text/') || ['application/json', 'application/xml', 'application/javascript', 'application/sql'].includes(m) || m.endsWith('+json') || m.endsWith('+xml')); }
async function sha(data) { return new Uint8Array(await crypto.subtle.digest('SHA-256', Uint8Array.from(data))); }
function hex(b) { return [...b].map(x => x.toString(16).padStart(2, '0')).join(''); }
export function scan(data) { if (data.length < HEADER || !MAGIC.every((x, i) => data[i] === x))
    throw new Error('ODC inválido'); const v = new DataView(data.buffer, data.byteOffset, data.byteLength); const major = v.getUint16(4, true), flags = v.getUint32(8, true), hs = v.getUint32(12, true), count = v.getUint32(16, true); if (major !== 1 || hs !== HEADER || count > 1_000_000)
    throw new Error('header não suportado'); let p = HEADER; const chunks = []; for (let i = 0; i < count; i++) {
    if (p + CH > data.length)
        throw new Error('chunk truncado');
    const type = v.getUint16(p, true), fl = v.getUint16(p + 2, true), big = v.getBigUint64(p + 4, true);
    if (big > BigInt(Number.MAX_SAFE_INTEGER))
        throw new Error('chunk grande demais');
    const length = Number(big), d = p + CH;
    if (d + length > data.length)
        throw new Error('comprimento inválido');
    chunks.push({ type, flags: fl, length, headerOffset: p, dataOffset: d });
    p = d + length;
} return { flags, chunks }; }
function one(data, chunks, type, max, req = true) { const c = chunks.find(x => x.type === type); if (!c) {
    if (req)
        throw new Error(`chunk ausente ${type}`);
    return null;
} if (c.length > max)
    throw new Error('chunk acima do limite'); return data.subarray(c.dataOffset, c.dataOffset + c.length); }
export async function createOdc(fileName, mimeType, raw, metadata = null, compress = true) { let payload = raw, comp = 0; if (compress && shouldGzip(mimeType, raw.length)) {
    const z = await gzip(raw);
    if (z.length + 64 < raw.length) {
        payload = z;
        comp = 1;
    }
} const hash = await sha(raw), count = 6 + (metadata ? 1 : 0); const h = new Uint8Array(HEADER); h.set(MAGIC); const v = new DataView(h.buffer); v.setUint16(4, 1, true); v.setUint32(8, comp ? 1 : 0, true); v.setUint32(12, HEADER, true); v.setUint32(16, count, true); const parts = [h, ch(T.FILE, enc.encode(fileName)), ch(T.MIME, enc.encode(mimeType))]; if (metadata)
    parts.push(ch(T.META, enc.encode(JSON.stringify(metadata)))); parts.push(ch(T.SIZE, u64(raw.length)), ch(T.COMP, new Uint8Array([comp])), ch(T.SHA, hash), ch(T.PAYLOAD, payload)); return cat(parts); }
export async function infoOdc(data) { const { flags, chunks } = scan(data), p = chunks.find(c => c.type === T.PAYLOAD); if (!p)
    throw new Error('PAYLOAD ausente'); const m = one(data, chunks, T.META, 16 << 20, false); return { version: '1.0', flags, chunkCount: chunks.length, fileName: dec.decode(one(data, chunks, T.FILE, 1 << 20)), mimeType: dec.decode(one(data, chunks, T.MIME, 1 << 20)), originalSize: Number(new DataView(one(data, chunks, T.SIZE, 8).buffer, one(data, chunks, T.SIZE, 8).byteOffset, 8).getBigUint64(0, true)), storedPayloadSize: p.length, compression: one(data, chunks, T.COMP, 1)[0] === 1 ? 'gzip' : 'none', sha256: hex(one(data, chunks, T.SHA, 32)), metadata: m ? JSON.parse(dec.decode(m)) : null, chunks }; }
export async function extractOdc(data) { const { chunks } = scan(data), p = chunks.find(c => c.type === T.PAYLOAD); if (!p)
    throw new Error('PAYLOAD ausente'); const packed = data.subarray(p.dataOffset, p.dataOffset + p.length), cp = one(data, chunks, T.COMP, 1)[0]; const raw = cp === 1 ? await gunzip(packed) : packed.slice(); if (cp !== 0 && cp !== 1)
    throw new Error('compressão não suportada'); const size = Number(new DataView(one(data, chunks, T.SIZE, 8).buffer, one(data, chunks, T.SIZE, 8).byteOffset, 8).getBigUint64(0, true)); if (raw.length !== size)
    throw new Error('tamanho divergente'); const actual = await sha(raw), expected = one(data, chunks, T.SHA, 32); if (!actual.every((x, i) => x === expected[i]))
    throw new Error('SHA-256 inválido'); return raw; }
export async function verifyOdc(data) { try {
    await extractOdc(data);
    return true;
}
catch {
    return false;
} }
export async function setMetadata(data, metadata) { const i = await infoOdc(data), raw = await extractOdc(data); return createOdc(i.fileName, i.mimeType, raw, metadata, i.compression === 'gzip'); }
