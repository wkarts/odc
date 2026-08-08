package odc

import (
	"compress/gzip"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"mime"
	"os"
	"path/filepath"
	"strings"
)

const (
	Magic                    = "ODC1"
	HeaderSize               = 24
	ChunkHeaderSize          = 12
	ChunkFileName     uint16 = 0x0001
	ChunkMime         uint16 = 0x0002
	ChunkMeta         uint16 = 0x0003
	ChunkOriginalSize uint16 = 0x0004
	ChunkCompression  uint16 = 0x0010
	ChunkSHA256       uint16 = 0x0020
	ChunkPayload      uint16 = 0x0100
	CompressionNone   byte   = 0
	CompressionGzip   byte   = 1
)

type Chunk struct {
	Type         uint16
	Flags        uint16
	Length       uint64
	HeaderOffset int64
	DataOffset   int64
}
type Header struct {
	Major uint16
	Minor uint16
	Flags uint32
	Count uint32
}
type Info struct {
	Magic             string  `json:"magic"`
	Version           string  `json:"version"`
	Flags             uint32  `json:"flags"`
	ChunkCount        uint32  `json:"chunk_count"`
	FileName          string  `json:"file_name"`
	MimeType          string  `json:"mime_type"`
	OriginalSize      uint64  `json:"original_size"`
	StoredPayloadSize uint64  `json:"stored_payload_size"`
	Compression       string  `json:"compression"`
	SHA256            string  `json:"sha256"`
	Metadata          any     `json:"metadata"`
	Chunks            []Chunk `json:"chunks"`
}

func Scan(path string) (Header, []Chunk, error) {
	f, err := os.Open(path)
	if err != nil {
		return Header{}, nil, err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return Header{}, nil, err
	}
	b := make([]byte, HeaderSize)
	if _, err = io.ReadFull(f, b); err != nil {
		return Header{}, nil, err
	}
	if string(b[:4]) != Magic {
		return Header{}, nil, errors.New("magic ODC inválido")
	}
	h := Header{binary.LittleEndian.Uint16(b[4:6]), binary.LittleEndian.Uint16(b[6:8]), binary.LittleEndian.Uint32(b[8:12]), binary.LittleEndian.Uint32(b[16:20])}
	if h.Major != 1 || binary.LittleEndian.Uint32(b[12:16]) != HeaderSize || h.Count > 1_000_000 {
		return Header{}, nil, errors.New("header não suportado")
	}
	pos := int64(HeaderSize)
	chunks := make([]Chunk, 0, h.Count)
	for i := uint32(0); i < h.Count; i++ {
		if pos+ChunkHeaderSize > st.Size() {
			return Header{}, nil, errors.New("chunk truncado")
		}
		c := make([]byte, ChunkHeaderSize)
		if _, e := f.ReadAt(c, pos); e != nil {
			return Header{}, nil, e
		}
		l := binary.LittleEndian.Uint64(c[4:12])
		d := pos + ChunkHeaderSize
		if l > uint64(st.Size()-d) {
			return Header{}, nil, errors.New("comprimento inválido")
		}
		chunks = append(chunks, Chunk{binary.LittleEndian.Uint16(c[0:2]), binary.LittleEndian.Uint16(c[2:4]), l, pos, d})
		pos = d + int64(l)
	}
	return h, chunks, nil
}
func index(ch []Chunk) map[uint16][]Chunk {
	m := map[uint16][]Chunk{}
	for _, c := range ch {
		m[c.Type] = append(m[c.Type], c)
	}
	return m
}
func readSmall(path string, idx map[uint16][]Chunk, typ uint16, max uint64, required bool) ([]byte, error) {
	cs := idx[typ]
	if len(cs) == 0 {
		if required {
			return nil, fmt.Errorf("chunk ausente %04x", typ)
		}
		return nil, nil
	}
	c := cs[0]
	if c.Length > max {
		return nil, errors.New("chunk acima do limite")
	}
	f, e := os.Open(path)
	if e != nil {
		return nil, e
	}
	defer f.Close()
	b := make([]byte, int(c.Length))
	_, e = f.ReadAt(b, c.DataOffset)
	return b, e
}
func InfoFile(path string) (Info, error) {
	h, ch, e := Scan(path)
	if e != nil {
		return Info{}, e
	}
	idx := index(ch)
	fn, e := readSmall(path, idx, ChunkFileName, 1<<20, true)
	if e != nil {
		return Info{}, e
	}
	mt, e := readSmall(path, idx, ChunkMime, 1<<20, true)
	if e != nil {
		return Info{}, e
	}
	sz, e := readSmall(path, idx, ChunkOriginalSize, 8, true)
	if e != nil {
		return Info{}, e
	}
	cp, e := readSmall(path, idx, ChunkCompression, 1, true)
	if e != nil {
		return Info{}, e
	}
	sh, e := readSmall(path, idx, ChunkSHA256, 32, true)
	if e != nil {
		return Info{}, e
	}
	p := idx[ChunkPayload]
	if len(p) == 0 {
		return Info{}, errors.New("PAYLOAD ausente")
	}
	mb, _ := readSmall(path, idx, ChunkMeta, 16<<20, false)
	var meta any
	if mb != nil {
		if e = json.Unmarshal(mb, &meta); e != nil {
			return Info{}, e
		}
	}
	comp := "none"
	if cp[0] == 1 {
		comp = "gzip"
	}
	return Info{Magic, fmt.Sprintf("%d.%d", h.Major, h.Minor), h.Flags, h.Count, string(fn), string(mt), binary.LittleEndian.Uint64(sz), p[0].Length, comp, hex.EncodeToString(sh), meta, ch}, nil
}
func shouldGzip(mt string, size int64) bool {
	if size < 768 {
		return false
	}
	mt = strings.ToLower(strings.Split(mt, ";")[0])
	return strings.HasPrefix(mt, "text/") || mt == "application/json" || mt == "application/xml" || strings.HasSuffix(mt, "+json") || strings.HasSuffix(mt, "+xml")
}
func detectMime(p string) string {
	if m := mime.TypeByExtension(strings.ToLower(filepath.Ext(p))); m != "" {
		return strings.Split(m, ";")[0]
	}
	return "application/octet-stream"
}
func writeHeader(w io.Writer, flags uint32, count uint32) error {
	b := make([]byte, HeaderSize)
	copy(b[:4], Magic)
	binary.LittleEndian.PutUint16(b[4:6], 1)
	binary.LittleEndian.PutUint32(b[8:12], flags)
	binary.LittleEndian.PutUint32(b[12:16], HeaderSize)
	binary.LittleEndian.PutUint32(b[16:20], count)
	_, e := w.Write(b)
	return e
}
func writeChunk(w io.Writer, t uint16, data []byte) error {
	h := make([]byte, ChunkHeaderSize)
	binary.LittleEndian.PutUint16(h[0:2], t)
	binary.LittleEndian.PutUint64(h[4:12], uint64(len(data)))
	if _, e := w.Write(h); e != nil {
		return e
	}
	_, e := w.Write(data)
	return e
}
func Create(input, output string, meta map[string]any, compress bool) error {
	raw, e := os.ReadFile(input)
	if e != nil {
		return e
	}
	mt := detectMime(input)
	payload := raw
	comp := CompressionNone
	if compress && shouldGzip(mt, int64(len(raw))) {
		tf, e := os.CreateTemp("", "odc-gzip-")
		if e != nil {
			return e
		}
		name := tf.Name()
		gz := gzip.NewWriter(tf)
		_, e = gz.Write(raw)
		if ce := gz.Close(); e == nil {
			e = ce
		}
		tf.Close()
		defer os.Remove(name)
		if e != nil {
			return e
		}
		gzb, e := os.ReadFile(name)
		if e != nil {
			return e
		}
		if len(gzb)+64 < len(raw) {
			payload = gzb
			comp = CompressionGzip
		}
	}
	sha := sha256.Sum256(raw)
	count := uint32(6)
	if len(meta) > 0 {
		count++
	}
	if e = os.MkdirAll(filepath.Dir(output), 0755); e != nil {
		return e
	}
	tmp := output + ".tmp"
	f, e := os.Create(tmp)
	if e != nil {
		return e
	}
	ok := false
	defer func() {
		f.Close()
		if !ok {
			os.Remove(tmp)
		}
	}()
	flags := uint32(0)
	if comp == 1 {
		flags = 1
	}
	if e = writeHeader(f, flags, count); e != nil {
		return e
	}
	if e = writeChunk(f, ChunkFileName, []byte(filepath.Base(input))); e != nil {
		return e
	}
	if e = writeChunk(f, ChunkMime, []byte(mt)); e != nil {
		return e
	}
	if len(meta) > 0 {
		mb, _ := json.Marshal(meta)
		if e = writeChunk(f, ChunkMeta, mb); e != nil {
			return e
		}
	}
	sb := make([]byte, 8)
	binary.LittleEndian.PutUint64(sb, uint64(len(raw)))
	if e = writeChunk(f, ChunkOriginalSize, sb); e != nil {
		return e
	}
	if e = writeChunk(f, ChunkCompression, []byte{comp}); e != nil {
		return e
	}
	if e = writeChunk(f, ChunkSHA256, sha[:]); e != nil {
		return e
	}
	if e = writeChunk(f, ChunkPayload, payload); e != nil {
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	if e = os.Rename(tmp, output); e != nil {
		return e
	}
	ok = true
	return nil
}
func Extract(path, out string) error {
	_, ch, e := Scan(path)
	if e != nil {
		return e
	}
	idx := index(ch)
	p := idx[ChunkPayload]
	if len(p) == 0 {
		return errors.New("PAYLOAD ausente")
	}
	f, e := os.Open(path)
	if e != nil {
		return e
	}
	defer f.Close()
	sr := io.NewSectionReader(f, p[0].DataOffset, int64(p[0].Length))
	cp, _ := readSmall(path, idx, ChunkCompression, 1, true)
	var r io.Reader = sr
	if cp[0] == 1 {
		gz, e := gzip.NewReader(sr)
		if e != nil {
			return e
		}
		defer gz.Close()
		r = gz
	} else if cp[0] != 0 {
		return errors.New("compressão não suportada")
	}
	if e = os.MkdirAll(filepath.Dir(out), 0755); e != nil {
		return e
	}
	o, e := os.Create(out)
	if e != nil {
		return e
	}
	h := sha256.New()
	n, e := io.Copy(io.MultiWriter(o, h), r)
	ce := o.Close()
	if e != nil {
		return e
	}
	if ce != nil {
		return ce
	}
	sz, _ := readSmall(path, idx, ChunkOriginalSize, 8, true)
	if uint64(n) != binary.LittleEndian.Uint64(sz) {
		return errors.New("tamanho divergente")
	}
	sh, _ := readSmall(path, idx, ChunkSHA256, 32, true)
	if !equal(sh, h.Sum(nil)) {
		return errors.New("SHA-256 inválido")
	}
	return nil
}
func equal(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	var x byte
	for i := range a {
		x |= a[i] ^ b[i]
	}
	return x == 0
}
func Verify(path string) bool {
	f, e := os.CreateTemp("", "odc-verify-")
	if e != nil {
		return false
	}
	n := f.Name()
	f.Close()
	defer os.Remove(n)
	return Extract(path, n) == nil
}

// SetMetadata atualiza ou remove (meta=nil) o METADATA_JSON recriando o container de forma segura.
func SetMetadata(path string, meta map[string]any) error {
	i, err := InfoFile(path)
	if err != nil {
		return err
	}
	dir, err := os.MkdirTemp("", "odc-edit-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)
	original := filepath.Join(dir, i.FileName)
	if err = Extract(path, original); err != nil {
		return err
	}
	return Create(original, path, meta, i.Compression == "gzip")
}
