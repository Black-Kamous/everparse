module Employee

(* This file has been automatically generated by EverParse. *)
open FStar.Bytes
module U8 = FStar.UInt8
module U16 = FStar.UInt16
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module LP = LowParse.Spec
module LS = LowParse.SLow
module LPI = LowParse.Spec.AllIntegers
module LL = LowParse.Low
module L = FStar.List.Tot
module B = LowStar.Buffer
module BY = FStar.Bytes
module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST

#reset-options "--using_facts_from '* -FStar.Tactics -FStar.Reflection' --z3rlimit 16 --z3cliopt smt.arith.nl=false --max_fuel 2 --max_ifuel 2"

(* Type of field name*)
open Employee_name

type employee' = (employee_name & U16.t)

inline_for_extraction let synth_employee (x: employee') : employee =
  match x with (name,salary) -> {
    name = name;
    salary = salary;
  }

inline_for_extraction let synth_employee_recip (x: employee) : employee' = (x.name,x.salary)

let synth_employee_recip_inverse () : Lemma (LP.synth_inverse synth_employee_recip synth_employee) = ()

let synth_employee_injective () : Lemma (LP.synth_injective synth_employee) =
  LP.synth_inverse_synth_injective synth_employee_recip synth_employee;
  synth_employee_recip_inverse ()

let synth_employee_inverse () : Lemma (LP.synth_inverse synth_employee synth_employee_recip) =
  assert_norm (LP.synth_inverse synth_employee synth_employee_recip)

let synth_employee_recip_injective () : Lemma (LP.synth_injective synth_employee_recip) =
  synth_employee_recip_inverse ();
  LP.synth_inverse_synth_injective synth_employee synth_employee_recip

noextract let employee'_parser : LP.parser _ employee' = (employee_name_parser `LP.nondep_then` LPI.parse_u16)

noextract let employee'_parser_kind = LP.get_parser_kind employee'_parser

let employee_parser =
  synth_employee_injective ();
  assert_norm (employee_parser_kind == employee'_parser_kind);
  employee'_parser `LP.parse_synth` synth_employee

noextract let employee'_serializer : LP.serializer employee'_parser = (employee_name_serializer `LP.serialize_nondep_then` LPI.serialize_u16)

let employee_serializer =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = synth_employee_inverse () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LP.serialize_synth _ synth_employee employee'_serializer synth_employee_recip ()

let employee_bytesize (x:employee) : GTot nat = Seq.length (employee_serializer x)

let employee_bytesize_eq x = ()

inline_for_extraction let employee'_parser32 : LS.parser32 employee'_parser = (employee_name_parser32 `LS.parse32_nondep_then` LS.parse32_u16)

let employee_parser32 =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LS.parse32_synth _ synth_employee (fun x -> synth_employee x) employee'_parser32 ()

inline_for_extraction let employee'_serializer32 : LS.serializer32 employee'_serializer = (employee_name_serializer32 `LS.serialize32_nondep_then` LS.serialize32_u16)

let employee_serializer32 =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = synth_employee_inverse () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LS.serialize32_synth _ synth_employee _ employee'_serializer32 synth_employee_recip (fun x -> synth_employee_recip x) ()

inline_for_extraction let employee'_size32 : LS.size32 employee'_serializer = (employee_name_size32 `LS.size32_nondep_then` LS.size32_u16)

let employee_size32 =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = synth_employee_inverse () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LS.size32_synth _ synth_employee _ employee'_size32 synth_employee_recip (fun x -> synth_employee_recip x) ()

inline_for_extraction let employee'_validator : LL.validator employee'_parser = (employee_name_validator `LL.validate_nondep_then` (LL.validate_u16 ()))

let employee_validator =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LL.validate_synth employee'_validator synth_employee ()

inline_for_extraction let employee'_jumper : LL.jumper employee'_parser = (employee_name_jumper `LL.jump_nondep_then` LL.jump_u16)

let employee_jumper =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LL.jump_synth employee'_jumper synth_employee ()

let employee_bytesize_eqn x =
  [@inline_let] let _ = synth_employee_injective () in
  [@inline_let] let _ = synth_employee_inverse () in
  [@inline_let] let _ = assert_norm (employee_parser_kind == employee'_parser_kind) in
  LP.serialize_synth_eq _ synth_employee employee'_serializer synth_employee_recip () x;
LP.length_serialize_nondep_then employee_name_serializer LPI.serialize_u16 x.name x.salary;
  (employee_name_bytesize_eq (x.name));
  (assert (FStar.Seq.length (LP.serialize LP.serialize_u16 (x.salary)) == 2));
  assert(employee_bytesize x == Seq.length (LP.serialize employee_name_serializer x.name) + Seq.length (LP.serialize LPI.serialize_u16 x.salary))

let gaccessor'_employee_name : LL.gaccessor employee'_parser employee_name_parser _ = (LL.gaccessor_then_fst (LL.gaccessor_id employee'_parser))

let gaccessor'_employee_salary : LL.gaccessor employee'_parser LPI.parse_u16 _ = (LL.gaccessor_then_snd (LL.gaccessor_id employee'_parser))

inline_for_extraction noextract let accessor'_employee_name : LL.accessor gaccessor'_employee_name = (LL.accessor_then_fst (LL.accessor_id employee'_parser))

inline_for_extraction noextract let accessor'_employee_salary : LL.accessor gaccessor'_employee_salary = (LL.accessor_then_snd (LL.accessor_id employee'_parser) employee_name_jumper)

noextract let clens_employee_employee' : LL.clens employee employee' = synth_employee_recip_inverse (); synth_employee_recip_injective (); LL.clens_synth synth_employee_recip synth_employee

let gaccessor_employee_employee' : LL.gaccessor employee_parser employee'_parser clens_employee_employee' = synth_employee_inverse (); synth_employee_injective (); synth_employee_recip_inverse (); LL.gaccessor_synth employee'_parser synth_employee synth_employee_recip ()

inline_for_extraction noextract let accessor_employee_employee' : LL.accessor gaccessor_employee_employee' = synth_employee_inverse (); synth_employee_injective (); synth_employee_recip_inverse (); LL.accessor_synth employee'_parser synth_employee synth_employee_recip ()

let gaccessor_employee_name = LL.gaccessor_ext (gaccessor_employee_employee' `LL.gaccessor_compose` gaccessor'_employee_name) clens_employee_name ()

let accessor_employee_name = LL.accessor_ext (LL.accessor_compose accessor_employee_employee' accessor'_employee_name ()) clens_employee_name ()

let gaccessor_employee_salary = LL.gaccessor_ext (gaccessor_employee_employee' `LL.gaccessor_compose` gaccessor'_employee_salary) clens_employee_salary ()

let accessor_employee_salary = LL.accessor_ext (LL.accessor_compose accessor_employee_employee' accessor'_employee_salary ()) clens_employee_salary ()

let employee_valid h #_ #_ input pos0 =
  let name = LL.contents employee_name_parser h input pos0 in
  let pos1 = LL.get_valid_pos employee_name_parser h input pos0 in
  let salary = LL.contents LPI.parse_u16 h input pos1 in
  let pos2 = LL.get_valid_pos LPI.parse_u16 h input pos1 in
  LL.valid_nondep_then_intro h employee_name_parser LPI.parse_u16 input pos0;
  assert_norm (employee' == LP.get_parser_type employee'_parser);
  assert_norm (employee_parser_kind == employee'_parser_kind);
  synth_employee_injective ();
  LL.valid_synth_intro h employee'_parser synth_employee input pos0

