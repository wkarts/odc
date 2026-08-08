import { createOdc, infoOdc, extractOdc } from './odc.js';
export async function fromFile(file) { const raw = new Uint8Array(await file.arrayBuffer()); const odc = await createOdc(file.name, file.type || 'application/octet-stream', raw, { origem: 'browser' }); console.log(await infoOdc(odc)); const restored = await extractOdc(odc); return new Blob([restored], { type: file.type }); }
