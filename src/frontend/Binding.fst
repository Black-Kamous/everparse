module Binding
open Ast
open FStar.All
module H = Hashtable

//the bool signifies that this identifier has been used
let global_env = H.t ident' (decl * option typ)
let local_env = H.t ident' (typ * bool)

noeq
type env = {
  this_typ: (typ * ident);
  locals: local_env;
  globals: global_env
}

let params_of_decl (d:decl) : list param =
  match d.v with
  | Comment _
  | Define _ _
  | Enum _ _ _ -> []
  | Record _ params _
  | CaseType _ params _ -> params

let error #a msg (r:range) : ML a =
  failwith (Printf.sprintf "At %s: %s" (string_of_pos (fst r)) msg)

let check_shadow (e:H.t ident' 'a) (i:ident) (r:range) =
  match H.try_find e i.v with
  | Some j ->
    let msg = Printf.sprintf "Declaration %s clashes with previous declaration" i.v in
    error msg i.range

  | _ ->
    ()

let typedef_names (d:decl) : option typedef_names =
  match d.v with
  | Record td _ _
  | CaseType td _ _ -> Some td
  | _ -> None

let add_global (e:global_env) (i:ident) (d:decl) (t:option typ) =
  check_shadow e i d.range;
  H.insert e i.v (d, t);
  match typedef_names d with
  | None -> ()
  | Some td ->
    if td.typedef_abbrev.v <> i.v
    then begin
      check_shadow e td.typedef_abbrev d.range;
      H.insert e td.typedef_abbrev.v (d, t)
    end
//    check_shadow e td.typedef_ptr_abbrev d.range;


let add_local (e:env) (i:ident) (t:typ) =
  check_shadow e.globals i t.range;
  check_shadow e.locals i t.range;
  H.insert e.locals i.v (t, false)

let lookup (e:env) (i:ident) : ML (either typ (decl & option typ)) =
  match H.try_find e.locals i.v with
  | Some (t, true) ->
    Inl t
  | Some (t, false) ->  //mark it as used
    H.remove e.locals i.v;
    H.insert e.locals i.v (t, true);
    Inl t
  | None ->
    match H.try_find e.globals i.v with
    | Some d -> Inr d
    | None -> error (Printf.sprintf "Variable %s not found" i.v) i.range

let lookup_expr_name (e:env) (i:ident) : ML typ =
  match lookup e i with
  | Inl t -> t
  | Inr (_, Some t) -> t
  | Inr _ ->
    error (Printf.sprintf "Variable %s is not an expression identifier" i.v) i.range

let lookup_enum_cases (e:env) (i:ident)
  : ML (list ident * typ)
  = match lookup e i with
    | Inr ({v=Enum t _ tags}, _) -> tags, t
    | _ ->
      error (Printf.sprintf "Type %s is not an enumeration" i.v) i.range

let is_used (e:env) (i:ident) : ML bool =
  match H.try_find e.locals i.v with
  | Some (t, b) -> b
  | _ ->  error (Printf.sprintf "Variable %s not found" i.v) i.range

let type_of_constant (c:constant) : typ =
  match c with
  | Int i -> tuint32
  | XInt x -> tuint32

let map_opt (f:'a -> ML 'b) (o:option 'a) : ML (option 'b) =
  match o with
  | None -> None
  | Some x -> Some (f x)

let rec check_typ (env:env) (t:typ)
  : ML unit
  = match t.v with
    | Type_app s es ->
      match lookup env s with
      | Inl _ ->
        error (Printf.sprintf "%s is not a type" s.v) s.range

      | Inr (d, _) ->
        let params = params_of_decl d in
        if List.length params <> List.length es
        then error (Printf.sprintf "Not enough arguments to %s" s.v) s.range;
        let es =
          List.map2 (fun (t, _) e ->
            let e, t' = check_expr env e in
            if not (eq_typ t t')
            then error "Argument type mismatch" e.range;
            e)
            params
            es
        in
        ()

and check_expr (env:env) (e:expr)
  : ML (expr & typ)
  = let w e' = with_range e' e.range in
    match e.v with
    | Constant c ->
      e, type_of_constant c

    | Identifier i ->
      let t = lookup_expr_name env i in
      e, t

    | This ->
      w (Identifier (snd env.this_typ)),
      fst env.this_typ

    | App op es ->
      let ets = List.map (check_expr env) es in
      match ets with
      | [(e1, t1)] ->
        begin
        match op with
        | Not ->
          if not (eq_typ t1 tbool)
          then error "Expected bool" e1.range;
          w (App Not [e1]), t1

        | SizeOf ->
          w (App SizeOf [e1]),
          tuint32

        | _ ->
          error "Not a unary op" e1.range
        end

      | [(e1,t1);(e2,t2)] ->
        begin
        match op with
        | Eq ->
          if not (eq_typ t1 t2)
          then error
                 (Printf.sprintf "Equality on unequal types: %s and %s"
                   (print_typ t1)
                   (print_typ t2))
               e.range;
          w (App Eq [e1; e2]), tbool

        | And
        | Or ->
          if not (eq_typ t1 tbool)
           || not (eq_typ t2 tbool)
          then error "Binary boolean op on non booleans" e.range;
          w (App op [e1; e2]), tbool

        | Plus
        | Minus ->
          if not (eq_typ t1 tuint32)
           || not (eq_typ t2 tuint32)
          then error "Binary integer op on non-integers" e.range;
          w (App op [e1; e2]), tuint32


        | LT
        | GT
        | LE
        | GE ->
          if not (eq_typ t1 tuint32)
           || not (eq_typ t2 tuint32)
          then error "Binary integer op on non integers" e.range;
          w (App op [e1; e2]), tbool

        | _ ->
          error "Not a binary op" e.range
        end

      | _ -> error "Unexpected arity" e.range

let check_field (env:env) (extend_scope: bool) (f:field)
  : ML field
  = match f.v with
    | FieldComment _ -> f
    | Field sf ->
      check_typ env sf.field_type;
      let fa = sf.field_array_opt |> map_opt (fun e ->
        let e, t = check_expr env e in
        if not (eq_typ t tuint32)
        then error (Printf.sprintf "Array expression %s has type %s instead of UInt32"
                          (print_expr e)
                          (print_typ t))
                   e.range;
        e)
      in
      let fc = sf.field_constraint |> map_opt (fun e ->
        let env = { env with this_typ=(sf.field_type, sf.field_ident) } in
        fst (check_expr env e)) in
      if extend_scope then add_local env sf.field_ident sf.field_type;
      let sf = { sf with field_array_opt = fa; field_constraint = fc } in
      with_range (Field sf) f.range

let check_switch (env:env) (s:switch_case)
  : ML switch_case
  = let head, cases = s in
    let head, enum_t = check_expr env head in
    let enum_tags, t = lookup_enum_cases env (Type_app?._0 enum_t.v) in
    let check_case (c:case) : ML case =
      let pat, f = c in
      let pat, pat_t = check_expr env pat in
      let case_exists =
          match pat.v with
          | Identifier pat ->
            Some? (List.tryFind (fun (case:ident) -> case.v = pat.v) enum_tags)
          | _ ->
            false
      in
      if not (eq_typ pat_t t)
      then error (Printf.sprintf "Type of case (%s) does not match type of switch expression (%s)"
                     (print_typ pat_t)
                     (print_typ t))
                 pat.range;
      if not case_exists
      then error (Printf.sprintf "Case (%s) is not in the enumerated type %s"
                    (print_expr pat)
                    (print_typ enum_t))
           pat.range;
      let f = check_field env false f in
      pat, f
    in
    let cases = List.map check_case cases in
    head, cases

let mk_env (g:global_env) =
  { this_typ = (tunknown, with_dummy_range "");
    locals = H.create 10;
    globals = g }

let check_params (env:env) (ps:list param) : ML unit =
  ps |> List.iter (fun (t, p) ->
      check_typ env t;
      add_local env p t)

let bind_decl (e:global_env) (d:decl) : ML decl =
  match d.v with
  | Comment _ -> d

  | Define i c ->
    add_global e i d (Some (type_of_constant c));
    d

  | Enum t i cases ->
    let env = mk_env e in
    check_typ env t;
    cases |> List.iter (fun i ->
      let _, t' = check_expr env (with_dummy_range (Identifier i)) in
      if not (eq_typ t t')
      then error (Printf.sprintf "Inconsistent type of enumeration identifier: Expected %s, got %s"
                   (print_typ t)
                   (print_typ t'))
                 d.range);
    add_global e i d None;
    d

  | Record tdnames params fields ->
    let env = mk_env e in
    check_params env params;
    let fields = fields |> List.map (check_field env true) in
    let fields = fields |> List.map (fun f ->
      match f.v with
      | FieldComment _ -> f
      | Field sf ->
        with_range
          (Field ({ sf with field_dependence = is_used env sf.field_ident }))
          f.range)
    in
    let d = with_range (Record tdnames params fields) d.range in
    add_global e tdnames.typedef_name d None;
    d

  | CaseType tdnames params switch ->
    let env = mk_env e in
    check_params env params;
    let switch = check_switch env switch in
    let d = with_range (CaseType tdnames params switch) d.range in
    add_global e tdnames.typedef_name d None;
    d

let prog = list decl

let initial_global_env () =
  let e = H.create 10 in
  let nullary_decl i =
    let td_name = {
      typedef_name = i;
      typedef_abbrev = i;
      typedef_ptr_abbrev = i
    }
    in
    { v = Record td_name [] [];
      range = dummy_range }
  in
  [ "UINT32"; "RNDIS_REQUEST_ID"; "RNDIS_OID";
    "RNDIS_HANDLE"; "RNDIS_PACKET"; "opaque" ]
  |> List.iter (fun i ->
    let i = { v = i; range=dummy_range} in
    add_global e i (nullary_decl i) None);
  e

let bind_prog (p:prog) : ML prog =
  let e = initial_global_env() in
  List.map (bind_decl e) p
