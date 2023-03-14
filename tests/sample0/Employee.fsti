module Employee

(* This file has been automatically generated by EverParse. *)
open FStar.Bytes
module U8 = FStar.UInt8
module U16 = FStar.UInt16
module U32 = FStar.UInt32
module U64 = FStar.UInt64
module LP = LowParse.Spec.Base
module LS = LowParse.SLow.Base
module LPI = LowParse.Spec.AllIntegers
module LL = LowParse.Low.Base
module L = FStar.List.Tot
module B = LowStar.Buffer
module BY = FStar.Bytes
module HS = FStar.HyperStack
module HST = FStar.HyperStack.ST


(* Type of field name*)
include Employee_name

type employee = {
  name : employee_name;
  salary : U16.t;
}

inline_for_extraction noextract let employee_parser_kind = LP.strong_parser_kind 4 258 None

noextract val employee_parser: LP.parser employee_parser_kind employee

noextract val employee_serializer: LP.serializer employee_parser

noextract val employee_bytesize (x:employee) : GTot nat

noextract val employee_bytesize_eq (x:employee) : Lemma (employee_bytesize x == Seq.length (LP.serialize employee_serializer x))

val employee_parser32: LS.parser32 employee_parser

val employee_serializer32: LS.serializer32 employee_serializer

val employee_size32: LS.size32 employee_serializer

val employee_validator: LL.validator employee_parser

val employee_jumper: LL.jumper employee_parser

val employee_bytesize_eqn (x: employee) : Lemma (employee_bytesize x == (employee_name_bytesize (x.name)) + 2) [SMTPat (employee_bytesize x)]

noextract let clens_employee_name : LL.clens employee employee_name = {
  LL.clens_cond = (fun _ -> True);
  LL.clens_get = (fun x -> x.name);
}

noextract let clens_employee_salary : LL.clens employee U16.t = {
  LL.clens_cond = (fun _ -> True);
  LL.clens_get = (fun x -> x.salary);
}

val gaccessor_employee_name : LL.gaccessor employee_parser employee_name_parser clens_employee_name

val accessor_employee_name : LL.accessor gaccessor_employee_name

val gaccessor_employee_salary : LL.gaccessor employee_parser LPI.parse_u16 clens_employee_salary

val accessor_employee_salary : LL.accessor gaccessor_employee_salary

val employee_valid (h:HS.mem) (#rrel: _) (#rel: _) (input:LL.slice rrel rel) (pos0:U32.t) : Lemma
  (requires (
  LL.valid employee_name_parser h input pos0 /\ (
  let pos1 = LL.get_valid_pos employee_name_parser h input pos0 in
  LL.valid LPI.parse_u16 h input pos1 /\ (
  let pos2 = LL.get_valid_pos LPI.parse_u16 h input pos1 in
  True
  ))))
  (ensures (
  let name = LL.contents employee_name_parser h input pos0 in
  let pos1 = LL.get_valid_pos employee_name_parser h input pos0 in
  let salary = LL.contents LPI.parse_u16 h input pos1 in
  let pos2 = LL.get_valid_pos LPI.parse_u16 h input pos1 in
  LL.valid_content_pos employee_parser h input pos0 ({
      name = name;
      salary = salary;
    }) pos2))

