#!/usr/bin/env bash
set -euo pipefail
MAGIC=ODC1; HEADER=24; CH=12
C_FILE=1; C_MIME=2; C_META=3; C_SIZE=4; C_COMP=16; C_SHA=32; C_PAYLOAD=256
need(){ command -v "$1" >/dev/null || { echo "Falta dependência: $1" >&2; exit 3; }; }
for c in dd od stat sha256sum gzip mktemp file; do need "$c"; done
w8(){ printf '%b' "\\x$(printf '%02x' "$1")"; }
w16(){ local n=$1; w8 $((n&255)); w8 $(((n>>8)&255)); }
w32(){ local n=$1; w8 $((n&255)); w8 $(((n>>8)&255)); w8 $(((n>>16)&255)); w8 $(((n>>24)&255)); }
w64(){ local n=$1; for i in {0..7}; do w8 $(((n>>(i*8))&255)); done; }
bytes_at(){ dd if="$1" bs=1 skip="$2" count="$3" status=none | od -An -tu1; }
rnum(){ local f=$1 o=$2 n=$3; local vals; vals=($(bytes_at "$f" "$o" "$n")); local v=0 i=0; for b in "${vals[@]}"; do v=$((v+(b<<(8*i)))); i=$((i+1)); done; echo "$v"; }
chunk_header(){ w16 "$1"; w16 0; w64 "$2"; }
write_chunk_file(){ local t=$1 f=$2; local n; n=$(stat -c%s "$f"); chunk_header "$t" "$n"; cat "$f"; }
write_chunk_text(){ local t=$1 s=$2 tmp; tmp=$(mktemp); printf '%s' "$s">"$tmp"; write_chunk_file "$t" "$tmp"; rm -f "$tmp"; }
scan(){ local f=$1 count; [[ $(dd if="$f" bs=1 count=4 status=none) == "$MAGIC" ]]||return 1; count=$(rnum "$f" 16 4); local p=$HEADER; for((i=0;i<count;i++));do local t fl l; t=$(rnum "$f" "$p" 2); fl=$(rnum "$f" $((p+2)) 2); l=$(rnum "$f" $((p+4)) 8); echo "$t $fl $l $p $((p+CH))"; p=$((p+CH+l)); done; }
find_chunk(){ scan "$1"|awk -v t="$2" '$1==t{print;exit}'; }
read_text(){ local row=($(find_chunk "$1" "$2")); [[ ${#row[@]} -gt 0 ]]||return 1; dd if="$1" bs=1 skip="${row[4]}" count="${row[2]}" status=none; }
create(){ local input=$1 out=$2 meta=${3:-}; local rawsize mime payload comp=0 gz sha count flags tmp; rawsize=$(stat -c%s "$input"); mime=$(file --brief --mime-type "$input"); payload="$input"; gz=$(mktemp); if [[ $rawsize -ge 768 && ( $mime == text/* || $mime == application/json || $mime == application/xml ) ]]; then gzip -c -6 "$input">"$gz"; if (( $(stat -c%s "$gz") + 64 < rawsize )); then payload="$gz";comp=1;fi; fi; count=6; [[ -n "$meta" ]]&&count=7; flags=$comp; sha=$(sha256sum "$input"|awk '{print $1}'); tmp="${out}.tmp.$$"; mkdir -p "$(dirname "$out")"; {
 printf 'ODC1'; w16 1; w16 0; w32 "$flags"; w32 24; w32 "$count"; w32 0;
 write_chunk_text $C_FILE "$(basename "$input")"; write_chunk_text $C_MIME "$mime"; [[ -n "$meta" ]]&&write_chunk_file $C_META "$meta";
 local sfile; sfile=$(mktemp); w64 "$rawsize">"$sfile"; write_chunk_file $C_SIZE "$sfile"; rm -f "$sfile";
 local cfile; cfile=$(mktemp); w8 "$comp">"$cfile"; write_chunk_file $C_COMP "$cfile"; rm -f "$cfile";
 local hfile; hfile=$(mktemp); for((i=0;i<${#sha};i+=2));do w8 $((16#${sha:i:2}));done >"$hfile"; write_chunk_file $C_SHA "$hfile"; rm -f "$hfile";
 write_chunk_file $C_PAYLOAD "$payload";
 } >"$tmp"; mv -f "$tmp" "$out"; rm -f "$gz"; }
info(){ local f=$1 file mime size comp sha prow; file=$(read_text "$f" $C_FILE); mime=$(read_text "$f" $C_MIME); local sr=($(find_chunk "$f" $C_SIZE)); size=$(rnum "$f" "${sr[4]}" 8); local cr=($(find_chunk "$f" $C_COMP)); comp=$(rnum "$f" "${cr[4]}" 1); local hr=($(find_chunk "$f" $C_SHA)); sha=$(dd if="$f" bs=1 skip="${hr[4]}" count=32 status=none|od -An -tx1|tr -d ' \n'); prow=($(find_chunk "$f" $C_PAYLOAD)); printf 'file_name=%s\nmime_type=%s\noriginal_size=%s\nstored_payload_size=%s\ncompression=%s\nsha256=%s\n' "$file" "$mime" "$size" "${prow[2]}" "$([[ $comp == 1 ]]&&echo gzip||echo none)" "$sha"; if find_chunk "$f" $C_META >/dev/null;then printf 'metadata=';read_text "$f" $C_META;echo;fi; }
extract(){ local f=$1 out=$2; local pr cr sr hr; pr=($(find_chunk "$f" $C_PAYLOAD)); cr=($(find_chunk "$f" $C_COMP)); sr=($(find_chunk "$f" $C_SIZE)); hr=($(find_chunk "$f" $C_SHA)); local comp size expected pack; comp=$(rnum "$f" "${cr[4]}" 1); size=$(rnum "$f" "${sr[4]}" 8); expected=$(dd if="$f" bs=1 skip="${hr[4]}" count=32 status=none|od -An -tx1|tr -d ' \n'); pack=$(mktemp); dd if="$f" of="$pack" bs=1 skip="${pr[4]}" count="${pr[2]}" status=none; mkdir -p "$(dirname "$out")"; if [[ $comp == 1 ]];then gzip -dc "$pack">"$out";elif [[ $comp == 0 ]];then cp "$pack" "$out";else echo 'compressão não suportada'>&2;rm -f "$pack";return 1;fi; rm -f "$pack"; [[ $(stat -c%s "$out") == "$size" ]]||{ echo 'tamanho divergente'>&2;return 1;}; [[ $(sha256sum "$out"|awk '{print $1}') == "$expected" ]]||{ echo 'SHA inválido'>&2;return 1;}; }
verify(){ local t; t=$(mktemp); if extract "$1" "$t" 2>/dev/null;then echo OK;rm -f "$t";else echo INVALIDO;rm -f "$t";return 1;fi; }
setmeta(){ local f=$1 meta=${2:-}; local name tmpdir orig; name=$(read_text "$f" $C_FILE); tmpdir=$(mktemp -d);orig="$tmpdir/$name";extract "$f" "$orig";create "$orig" "$f" "$meta";rm -rf "$tmpdir"; }
case "${1:-}" in create) create "$2" "$3" "${4:-}";;info)info "$2";;extract)extract "$2" "$3";;verify)verify "$2";;set-meta)setmeta "$2" "$3";;remove-meta)setmeta "$2";;*)echo 'Uso: odc.sh create|info|extract|verify|set-meta|remove-meta ...'>&2;exit 2;;esac
