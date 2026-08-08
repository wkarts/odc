export type OdcMetadata = Record<string, unknown>;
export interface OdcChunk {
    type: number;
    flags: number;
    length: number;
    headerOffset: number;
    dataOffset: number;
}
export interface OdcInfo {
    version: string;
    flags: number;
    chunkCount: number;
    fileName: string;
    mimeType: string;
    originalSize: number;
    storedPayloadSize: number;
    compression: 'none' | 'gzip';
    sha256: string;
    metadata: OdcMetadata | null;
    chunks: OdcChunk[];
}
export declare function scan(data: Uint8Array): {
    flags: number;
    chunks: OdcChunk[];
};
export declare function createOdc(fileName: string, mimeType: string, raw: Uint8Array, metadata?: OdcMetadata | null, compress?: boolean): Promise<Uint8Array<ArrayBuffer>>;
export declare function infoOdc(data: Uint8Array): Promise<OdcInfo>;
export declare function extractOdc(data: Uint8Array): Promise<Uint8Array<ArrayBuffer>>;
export declare function verifyOdc(data: Uint8Array): Promise<boolean>;
export declare function setMetadata(data: Uint8Array, metadata: OdcMetadata | null): Promise<Uint8Array<ArrayBuffer>>;
