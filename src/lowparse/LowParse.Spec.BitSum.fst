module LowParse.Spec.BitSum
include LowParse.Spec.Sum
include LowParse.Spec.BitFields

module L = FStar.List.Tot

let rec valid_bitfield_widths_inj
  (lo: nat)
  (hi1: nat { lo <= hi1 })
  (hi2: nat { lo <= hi2 })
  (l: list nat)
: Lemma
  (requires (valid_bitfield_widths lo hi1 l /\ valid_bitfield_widths lo hi2 l))
  (ensures (hi1 == hi2))
  (decreases l)
= match l with
  | [] -> ()
  | sz :: q -> valid_bitfield_widths_inj (lo + sz) hi1 hi2 q

let rec valid_bitfield_widths_prefix
  (lo: nat)
  (hi: nat { lo <= hi })
  (prefix: list nat)
  (suffix: list nat { valid_bitfield_widths lo hi (prefix `L.append` suffix) })
: Tot (mi: nat { lo <= mi /\ mi <= hi /\ valid_bitfield_widths lo mi prefix })
  (decreases prefix)
= match prefix with
  | [] -> lo
  | sz :: q -> valid_bitfield_widths_prefix (lo + sz) hi q suffix

let rec valid_bitfield_widths_append
  (lo: nat)
  (mi: nat { lo <= mi })
  (hi: nat { mi <= hi })
  (prefix: list nat { valid_bitfield_widths lo mi prefix })
  (suffix: list nat { valid_bitfield_widths mi hi suffix })
: Lemma
  (ensures (valid_bitfield_widths lo hi (prefix `L.append` suffix)))
  (decreases prefix)
= match prefix with
  | [] -> ()
  | sz :: q -> valid_bitfield_widths_append (lo + sz) mi hi q suffix

noeq
type bitsum' =
| BitSum' :
    (tot: pos) ->
    (t: eqtype) ->
    (cl: uint_t tot t) ->
    (key: eqtype) ->
    (header: list nat) ->
    (header_size: nat { valid_bitfield_widths 0 header_size header }) ->
    (key_size: nat { header_size + key_size <= tot }) ->
    (e: enum key (bitfield cl key_size)) ->
    (payload: (enum_key e -> Tot (l: list nat { valid_bitfield_widths (header_size + key_size) tot l }))) ->
    bitsum'

noextract
let bitsum'_type
  (b: bitsum')
: Tot Type0
= (bitfields b.cl 0 b.header_size b.header & (key: enum_key b.e & bitfields b.cl (b.header_size + b.key_size) b.tot (b.payload key)))

inline_for_extraction
let filter_bitsum'
  (b: bitsum')
  (x: b.t)
: Tot bool
= let f : bitfield b.cl b.key_size = b.cl.get_bitfield x b.header_size (b.header_size + b.key_size) in
  list_mem f (list_map snd b.e)

inline_for_extraction
let synth_bitsum'
  (b: bitsum')
  (x: parse_filter_refine (filter_bitsum' b))
: Tot (bitsum'_type b)
= let f : bitfield b.cl b.key_size = b.cl.get_bitfield x b.header_size (b.header_size + b.key_size) in
  let k = enum_key_of_repr b.e f in
  (synth_bitfield b.cl 0 b.header_size b.header x, (| k, synth_bitfield b.cl (b.header_size + b.key_size) b.tot (b.payload k) x |))
  
module BF = LowParse.BitFields

let synth_bitsum'_injective'
  (b: bitsum')
  (x y: parse_filter_refine (filter_bitsum' b))
: Lemma
  (requires (synth_bitsum' b x == synth_bitsum' b y))
  (ensures (x == y))
= let f : bitfield b.cl b.key_size = b.cl.get_bitfield x b.header_size (b.header_size + b.key_size) in
  let g : bitfield b.cl b.key_size = b.cl.get_bitfield x b.header_size (b.header_size + b.key_size) in
  let k = enum_key_of_repr b.e f in
  assert (f == g);
  synth_bitfield_injective' b.cl 0 b.header_size b.header x y;
  synth_bitfield_injective' b.cl (b.header_size + b.key_size) b.tot (b.payload k) x y;
  BF.get_bitfield_partition (b.cl.v x) (b.cl.v y) 0 b.tot [b.header_size; b.header_size + b.key_size];
  BF.get_bitfield_full (b.cl.v x);
  BF.get_bitfield_full (b.cl.v y);
  assert (b.cl.uint_to_t (b.cl.v x) == b.cl.uint_to_t (b.cl.v y))

let synth_bitsum'_injective
  (b: bitsum')
: Lemma
  (synth_injective (synth_bitsum' b))
  [SMTPat (synth_injective (synth_bitsum' b))]
= synth_injective_intro' (synth_bitsum' b) (fun x y ->
    synth_bitsum'_injective' b x y
  )

let parse_bitsum'
  (b: bitsum')
  (#k: parser_kind)
  (p: parser k b.t)
: Tot (parser (parse_filter_kind k) (bitsum'_type b))
= (p `parse_filter` filter_bitsum' b) `parse_synth` synth_bitsum' b

inline_for_extraction
let synth_bitsum'_recip'
  (b: bitsum')
  (x: bitsum'_type b)
: Tot b.t
= let (hd, (| k, tl |)) = x in
  let y1 = synth_bitfield_recip b.cl (b.header_size + b.key_size) b.tot (b.payload k) tl in
  let y2 = b.cl.set_bitfield y1 b.header_size (b.header_size + b.key_size) (enum_repr_of_key b.e k) in
  let y3 = y2 `b.cl.logor` synth_bitfield_recip b.cl 0 b.header_size b.header hd in
  y3

let bitsum_btag_of_data'
  (bs: bitsum')
  (data: Type0)
  (header_of_data: (data -> Tot (bitfields bs.cl 0 bs.header_size bs.header)))
  (tag_of_data: (data -> Tot (enum_key bs.e)))
  (bit_payload_of_data: ((k: enum_key bs.e) -> (refine_with_tag tag_of_data k) -> Tot (bitfields bs.cl (bs.header_size + bs.key_size) bs.tot (bs.payload k))))
  (x: data)
: Tot (bitsum'_type bs)
= let k = tag_of_data x in
  (header_of_data x, (| k, bit_payload_of_data k x |))

inline_for_extraction
noextract
noeq
type synth_case_t
  (bs: bitsum')
  (data: Type0)
  (header_of_data: (data -> Tot (bitfields bs.cl 0 bs.header_size bs.header)))
  (tag_of_data: (data -> Tot (enum_key bs.e)))
  (bit_payload_of_data: ((k: enum_key bs.e) -> (refine_with_tag tag_of_data k) -> Tot (bitfields bs.cl (bs.header_size + bs.key_size) bs.tot (bs.payload k))))
  (type_of_tag: (enum_key bs.e -> Tot Type0))
= | SynthCase: (f: (
    (hd: bitfields bs.cl 0 bs.header_size bs.header) ->
    (k: enum_key bs.e) ->
    (bpl: bitfields bs.cl (bs.header_size + bs.key_size) bs.tot (bs.payload k)) ->
    (pl: type_of_tag k) ->
    Tot (refine_with_tag (bitsum_btag_of_data' bs data header_of_data tag_of_data bit_payload_of_data) (hd, (| k, bpl |)))
  )) -> synth_case_t bs data header_of_data tag_of_data bit_payload_of_data type_of_tag

noeq
type bitsum =
| BitSum:
    (bs: bitsum') ->
    (data: Type0) ->
    (header_of_data: (data -> Tot (bitfields bs.cl 0 bs.header_size bs.header))) ->
    (tag_of_data: (data -> Tot (enum_key bs.e))) ->
    (bit_payload_of_data: ((k: enum_key bs.e) -> (refine_with_tag tag_of_data k) -> Tot (bitfields bs.cl (bs.header_size + bs.key_size) bs.tot (bs.payload k)))) ->
    (type_of_tag: (enum_key bs.e -> Tot Type0)) ->
    (synth_case: synth_case_t bs data header_of_data tag_of_data bit_payload_of_data type_of_tag) ->
    bitsum

let weaken_parse_bitsum_cases_kind
  (b: bitsum)
  (f: (x: enum_key b.bs.e) -> Tot (k: parser_kind & parser k (b.type_of_tag x)))
: Tot parser_kind
= let keys : list b.bs.key = List.Tot.map fst b.bs.e in
  glb_list_of #(b.bs.key) (fun (x: b.bs.key) ->
    if List.Tot.mem x keys
    then let (| k, _ |) = f x in k
    else default_parser_kind
  ) (List.Tot.map fst b.bs.e)

let parse_bitsum_cases
  (b: bitsum)
  (f: (x: enum_key b.bs.e) -> Tot (k: parser_kind & parser k (b.type_of_tag x)))
  (x: bitsum'_type b.bs)
: Tot (parser (weaken_parse_bitsum_cases_kind b f) (refine_with_tag (bitsum_btag_of_data' b.bs b.data b.header_of_data b.tag_of_data b.bit_payload_of_data) x))
= let (hd, (| tg, tl |)) = x in
  let (| _, p |) = f tg in
  assume (synth_injective (b.synth_case.f hd tg tl));
  weaken (weaken_parse_bitsum_cases_kind b f) (p `parse_synth` b.synth_case.f hd tg tl)

inline_for_extraction
let parse_bitsum_kind
  (kt: parser_kind)
  (b: bitsum)
  (f: (x: enum_key b.bs.e) -> Tot (k: parser_kind & parser k (b.type_of_tag x)))
: Tot parser_kind
= and_then_kind (parse_filter_kind kt) (weaken_parse_bitsum_cases_kind b f)

let parse_bitsum
  (#kt: parser_kind)
  (b: bitsum)
  (p: parser kt b.bs.t)
  (f: (x: enum_key b.bs.e) -> Tot (k: parser_kind & parser k (b.type_of_tag x)))
: Tot (parser (parse_bitsum_kind kt b f) b.data)
= parse_tagged_union
    #(parse_filter_kind kt)
    #(bitsum'_type b.bs)
    (parse_bitsum' b.bs p)
    #(b.data)
    (bitsum_btag_of_data' b.bs b.data b.header_of_data b.tag_of_data b.bit_payload_of_data)
    #(weaken_parse_bitsum_cases_kind b f)
    (parse_bitsum_cases b f)
