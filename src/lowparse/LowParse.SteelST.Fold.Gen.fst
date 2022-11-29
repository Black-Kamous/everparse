module LowParse.SteelST.Fold.Gen

#set-options "--ide_id_info_off"

open Steel.ST.GenElim
open LowParse.SteelST.Combinators
open LowParse.SteelST.List
open LowParse.SteelST.Int
open LowParse.SteelST.FLData
open LowParse.Spec.VLGen

let impl_action
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#ret_t: Type)
  (#pre: state_i)
  (#post: state_i)
  (p: Ghost.erased (stt state_t ret_t pre post))
  (pi: stt_impl_t cl p)
  (#ty: Type)
  (#kty: parser_kind)
  (pty: parser kty ty)
  (with_size: bool)
: Tot (fold_impl_t cl pty with_size (action_fold p))
= fun kpre kpost (#vbin: v kty ty) (bin: byte_array) _ ->
    pi (kpre `star` aparse pty bin vbin) kpost

let impl_ret
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#ret_t: Type)
  (i: state_i)
  (v: ret_t)
: Tot (stt_impl_t cl (ret #state_i #state_t #i v))
= fun kpre kpost bout h k_success k_failure ->
    k_success bout h v

let impl_rewrite_parser
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#ret_t: Type)
  (#pre: state_i)
  (#post: state_i)
  (#ty: Type)
  (p: Ghost.erased (fold_t state_t ty ret_t pre post))
  (#kty: Ghost.erased parser_kind)
  (#pty: parser kty ty)
  (#with_size: bool)
  (pi: fold_impl_t cl pty with_size p)
  (#kty': Ghost.erased parser_kind)
  (pty': parser kty' ty)
: Pure (fold_impl_t cl pty' with_size p)
    (requires (forall x . parse pty' x == parse pty x))
    (ensures (fun _ -> True))
= fun kpre kpost (#vbin': v kty' ty) (bin: byte_array) bin_sz bout h k_success k_failure ->
    let vbin : v kty ty = rewrite_aparse bin pty in
    let restore (#opened: _) () : STGhostT unit opened
      (aparse pty bin vbin)
      (fun _ -> aparse pty' bin vbin')
    = let _ = rewrite_aparse bin pty' in
      vpattern_rewrite (aparse pty' bin) vbin'
    in
    pi
      kpre kpost #vbin bin bin_sz bout h
      (fun bout1 h1 v1 ->
        restore ();
        k_success bout1 h1 v1
      )
      (fun h1 v1 ->
        restore ();
        k_failure h1 v1)

let impl_read
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (i: state_i)
  (#ty: Type)
  (#kty: Ghost.erased parser_kind)
  (#pty: parser kty ty)
  (rty: leaf_reader pty)
  (with_size: bool)
: Tot (fold_impl_t cl pty with_size (fold_read #state_i #state_t #i #ty ()))
= fun kpre kpost (#vbin: v kty ty) (bin: byte_array) _ bout h k_success k_failure ->
    let v = rty bin in
    k_success bout h v

let impl_bind
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#ty: Type)
  (#kty: Ghost.erased parser_kind)
  (pty: parser kty ty)
  (#ret1: Type)
  (#pre1: _)
  (#post1: _)
  (#ret2: _)
  (#post2: _)
  (f: Ghost.erased (fold_t state_t ty ret1 pre1 post1))
  (with_size: bool)
  (impl_f: fold_impl_t cl pty with_size f)
  (g: Ghost.erased ((x: ret1) -> fold_t state_t ty ret2 post1 post2))
  (impl_g: ((x: ret1) -> fold_impl_t cl pty with_size (Ghost.reveal g x)))
  (g_prf: ((x: ret1) -> fold_state_inc cl (Ghost.reveal g x)))
: Tot (fold_impl_t cl pty with_size (bind_fold f g))
= fun kpre kpost (#vbin: v kty ty) (bin: byte_array) bin_sz bout h k_success k_failure ->
    impl_f
      kpre kpost bin bin_sz bout h
      (fun bout1 h1 v1 ->
        impl_g v1
          kpre kpost bin bin_sz bout1 h1 k_success k_failure
      )
      (fun h1 v1 ->
        let h2 = get_return_state (Ghost.reveal g v1 vbin.contents) h1 in
        let v2 = get_return_value (Ghost.reveal g v1 vbin.contents) h1 in
        g_prf v1 vbin.contents h1;
        cl.ll_state_failure_inc h1 h2;
        k_failure h2 v2
      )

let impl_if_gen
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#ret: Type)
  (#pre: _)
  (#post: _)
  (x: bool)
  (t1: (squash (x == true) -> Type))
  (f1: Ghost.erased (squash (x == true) -> fold_t state_t (t1 ()) ret pre post))
  (#k: Ghost.erased parser_kind)
  (p1: (squash (x == true) -> parser k (t1 ())))
  (with_size: bool)
  (impl_f1: squash (x == true) -> fold_impl_t cl (p1 ()) with_size (Ghost.reveal f1 ()))
  (t2: (squash (x == false) -> Type))
  (f2: Ghost.erased (squash (x == false) -> fold_t state_t (t2 ()) ret pre post))
  (p2: (squash (x == false) -> parser k (t2 ())))
  (impl_f2: squash (x == false) -> fold_impl_t cl (p2 ()) with_size (Ghost.reveal f2 ()))
: Tot (fold_impl_t cl #ret #pre #post #(ifthenelse x t1 t2) #k (ifthenelse_dep x t1 t2 (parser k) p1 p2) with_size (ifthenelse_dep x t1 t2 (fun t -> fold_t state_t t ret pre post) (Ghost.reveal f1) (Ghost.reveal f2)))
= fun kpre kpost #vbin bin bin_sz bout h k_success k_failure ->
    if x
    then coerce (fold_impl_t cl #ret #pre #post #(ifthenelse x t1 t2) #k (ifthenelse_dep x t1 t2 (parser k) p1 p2) with_size (ifthenelse_dep x t1 t2 (fun t -> fold_t state_t t ret pre post) (Ghost.reveal f1) (Ghost.reveal f2))) (impl_f1 ()) kpre kpost bin bin_sz bout h k_success k_failure
    else coerce (fold_impl_t cl #ret #pre #post #(ifthenelse x t1 t2) #k (ifthenelse_dep x t1 t2 (parser k) p1 p2) with_size (ifthenelse_dep x t1 t2 (fun t -> fold_t state_t t ret pre post) (Ghost.reveal f1) (Ghost.reveal f2))) (impl_f2 ()) kpre kpost bin bin_sz bout h k_success k_failure

let impl_if
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#t: Type)
  (#ret: Type)
  (#pre: _)
  (#post: _)
  (x: bool)
  (f1: Ghost.erased (squash (x == true) -> fold_t state_t t ret pre post))
  (#k: Ghost.erased parser_kind)
  (p: parser k t)
  (with_size: bool)
  (impl_f1: squash (x == true) -> fold_impl_t cl p with_size (Ghost.reveal f1 ()))
  (f2: Ghost.erased (squash (x == false) -> fold_t state_t t ret pre post))
  (impl_f2: squash (x == false) -> fold_impl_t cl p with_size (Ghost.reveal f2 ()))
: Tot (fold_impl_t cl p with_size (if x then Ghost.reveal f1 () else Ghost.reveal f2 ()))
= coerce _ (impl_if_gen cl x (fun _ -> t) f1 (fun _ -> p) with_size impl_f1 (fun _ -> t) f2 (fun _ -> p) impl_f2)

let impl_pair
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#t1: Type)
  (#t2: Type)
  (#ret1: Type)
  (#pre1: _)
  (#post1: _)
  (f1: Ghost.erased (fold_t state_t t1 ret1 pre1 post1))
  (#k1: Ghost.erased parser_kind)
  (#p1: parser k1 t1)
  (impl_f1: fold_impl_t cl p1 false f1)
  (j1: jumper p1) // MUST be computed OUTSIDE of impl_pair
  (#ret2: _)
  (#post2: _)
  (f2: Ghost.erased ((x: ret1) -> fold_t state_t t2 ret2 post1 post2))
  (#k2: Ghost.erased parser_kind)
  (#p2: parser k2 t2)
  (with_size: bool)
  (impl_f2: ((x: ret1) -> fold_impl_t cl p2 with_size (Ghost.reveal f2 x)))
  (f2_prf: ((x: ret1) -> fold_state_inc cl (Ghost.reveal f2 x))) 
: Pure (fold_impl_t cl (p1 `nondep_then` p2) with_size (fold_pair f1 f2))
    (requires (k1.parser_kind_subkind == Some ParserStrong))
    (ensures (fun _ -> True))
= fun kpre kpost #vbin bin bin_sz bout h k_success k_failure ->
  let _ = g_split_pair _ _ _ in
  let _ = gen_elim () in
  let bin1_sz = get_parsed_size j1 _ in
  let bin2 = hop_aparse_aparse_with_size p1 p2 _ bin1_sz _ in
  let vbin1 = vpattern_replace (aparse p1 bin) in
  let vbin2 = vpattern_replace (aparse p2 bin2) in
  let restore (#opened: _) () : STGhostT unit opened
    (aparse p1 bin vbin1 `star` aparse p2 bin2 vbin2)
    (fun _ -> aparse (p1 `nondep_then` p2) bin vbin)
  =
    let _ = merge_pair p1 p2 bin bin2 in
    rewrite (aparse _ bin _) (aparse (p1 `nondep_then` p2) bin vbin)
  in
  impl_f1
    (kpre `star` aparse p2 bin2 vbin2) kpost
    bin () bout h
    (fun bout1 h1 v1 ->
      impl_f2 v1
        (kpre `star` aparse p1 bin vbin1) kpost
        bin2 (if with_size then bin_sz `SZ.sub` bin1_sz else ()) bout1 h1
        (fun bout2 h2 v2 ->
          restore ();
          k_success bout2 h2 v2
        )
        (fun h2 v2 ->
          restore ();
          k_failure h2 v2
        )
    )
    (fun h1 v1 ->
      let h2 = get_return_state (Ghost.reveal f2 v1 vbin2.contents) h1 in
      let v2 = get_return_value (Ghost.reveal f2 v1 vbin2.contents) h1 in
      f2_prf v1 vbin2.contents h1;
      cl.ll_state_failure_inc h1 h2;
      restore ();
      k_failure h2 v2
    )

let impl_choice
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#kt: Type)
  (#t: (kt -> Type))
  (#ret_t: Type)
  (#pre: _)
  (#post: _)
  (f: Ghost.erased ((x: kt) -> fold_t state_t (t x) ret_t pre post))
  (#ktk: Ghost.erased parser_kind)
  (#ktp: parser ktk kt)
  (j: jumper ktp)
  (r: leaf_reader ktp)
  (#k: parser_kind)
  (p: (x: kt) -> parser k (t x))
  (with_size: bool)
  (impl_f: (x: kt) -> fold_impl_t cl (p x) with_size (Ghost.reveal f x))
: Pure (fold_impl_t cl (parse_dtuple2 ktp p) with_size (fold_choice f))
    (requires (ktk.parser_kind_subkind == Some ParserStrong))
    (ensures (fun _ -> True))
= fun kpre kpost #vbin bin bin_sz bout h k_success k_failure ->
  let _ = ghost_split_dtuple2
    ktp
    p
    bin
  in
  let _ = gen_elim () in
  let bin1_sz = get_parsed_size j bin in
  let bin_pl = hop_dtuple2_tag_with_size ktp p bin bin1_sz _ in
  let tag = read_dtuple2_tag r p bin bin_pl in
  let _ = gen_elim () in
  let vbin_tag = vpattern_replace (aparse ktp bin) in
  let vbin_pl = vpattern_replace (aparse (p tag) bin_pl) in
  let restore (#opened: _) () : STGhostT unit opened
    (aparse ktp bin vbin_tag `star` aparse (p tag) bin_pl vbin_pl)
    (fun _ -> aparse (parse_dtuple2 ktp p) bin vbin)
  =
    let _ = intro_dtuple2 ktp p bin bin_pl in
    rewrite (aparse _ bin _) (aparse (parse_dtuple2 ktp p) bin vbin)
  in
  impl_f tag
    (kpre `star` aparse ktp bin vbin_tag) kpost
    bin_pl (if with_size then bin_sz `SZ.sub` bin1_sz else ()) bout h
    (fun bout' h' v' ->
      restore ();
      k_success bout' h' v'
    )
    (fun h' v' ->
      restore ();
      k_failure h' v'
    )

module R = Steel.ST.Reference

(* for loop *)

unfold
let impl_for_inv_true_prop0
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (from: SZ.t)
  (h: state_t inv)
  (cont: bool)
: Tot prop
=
  SZ.v from0 <= SZ.v from /\
  fold_for inv (SZ.v from0) (SZ.v (if SZ.v from <= SZ.v to then from else to)) f l h0 == ((), h) /\
  (cont == (SZ.v from < SZ.v to))

let impl_for_inv_true_prop
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (from: SZ.t)
  (h: state_t inv)
  (cont: bool)
: Tot prop
= impl_for_inv_true_prop0 inv from0 to f l h0 from h cont

[@@__reduce__]
let impl_for_inv_aux_true
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (cont: bool)
: Tot vprop
= exists_ (fun (h: state_t inv) ->
    cl.ll_state_match h out `star`
    pure (
      impl_for_inv_true_prop inv from0 to f l h0 from h cont
    )
  )

let fold_for_loop_body
  #state_i (state_t: _)
  (inv: state_i)
  (t: Type)
  (from0: SZ.t) (to: SZ.t)
: Tot Type
= Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv)

let impl_for_inv_aux_false_prop
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (h: state_t inv)
  (cont: bool)
  (from: SZ.t)
: Tot prop
=
    SZ.v from0 <= SZ.v from /\ SZ.v from <= SZ.v to /\
    fold_for inv (SZ.v from0) (SZ.v from) f l h0 == ((), h) /\
    cont == false

[@@__reduce__]
let impl_for_inv_aux_false0
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (cont: bool)
  (from: SZ.t)
: Tot vprop
=
  exists_ (fun h ->
    cl.ll_state_failure h `star`
    pure (impl_for_inv_aux_false_prop inv from0 to f l h0 h cont from)
  )

let impl_for_inv_aux_false
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (cont: bool)
: (from: SZ.t) ->
  Tot vprop
=
  impl_for_inv_aux_false0 cl inv from0 to f l h0 cont

let intro_impl_for_inv_aux_false
  (#opened: _)
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (cont: bool)
  (from: SZ.t)
  (h: state_t inv)
: STGhost unit opened
    (cl.ll_state_failure h)
    (fun _ -> impl_for_inv_aux_false cl inv from0 to f l h0 cont from)
    (impl_for_inv_aux_false_prop inv from0 to f l h0 h cont from)
    (fun _ -> True)
= noop ();
  rewrite
    (impl_for_inv_aux_false0 cl inv from0 to f l h0 cont from)
    (impl_for_inv_aux_false cl inv from0 to f l h0 cont from)

let impl_for_inv_aux
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (no_interrupt: bool)
  (cont: bool)
: Tot vprop
= if no_interrupt
  then impl_for_inv_aux_true cl inv from0 to f l h0 out from cont
  else exists_ (impl_for_inv_aux_false cl inv from0 to f l h0 cont)

let intro_impl_for_inv_aux_true
  #state_i #state_t #ll_state #ll_state_ptr
  (#opened: _)
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (cont: bool)
  (h: state_t inv)
: STGhost unit opened
    (cl.ll_state_match h out)
    (fun _ -> impl_for_inv_aux cl inv from0 to f l h0 out from true cont)
    (impl_for_inv_true_prop inv from0 to f l h0 from h cont)
    (fun _ -> True)
= intro_pure (
    impl_for_inv_true_prop inv from0 to f l h0 from h cont
  );
  rewrite
    (impl_for_inv_aux_true cl inv from0 to f l h0 out from cont)
    (impl_for_inv_aux cl inv from0 to f l h0 out from true cont)

let elim_impl_for_inv_aux_true
  #opened
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (no_interrupt: bool)
  (cont: bool)
: STGhost (Ghost.erased (state_t inv)) opened
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (fun h -> cl.ll_state_match h out)
    (no_interrupt == true)
    (fun h -> impl_for_inv_true_prop inv from0 to f l h0 from h cont)
=
  rewrite
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (impl_for_inv_aux_true cl inv from0 to f l h0 out from cont);
  let gh = elim_exists () in
  let _ = gen_elim () in
  gh

let elim_impl_for_inv_aux_false
  #opened
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (no_interrupt: bool)
  (cont: bool)
: STGhost (Ghost.erased (SZ.t & state_t inv)) opened
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (fun r -> cl.ll_state_failure (sndp r))
    (no_interrupt == false)
    (fun r ->
      impl_for_inv_aux_false_prop inv from0 to f l h0 (sndp r) cont (fstp r)
    )
=
  rewrite
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (exists_ (impl_for_inv_aux_false0 cl inv from0 to f l h0 cont));
  let from' = elim_exists () in
  let _ = gen_elim () in
  let h = vpattern (fun h -> cl.ll_state_failure h) in
  let r = Ghost.hide (Ghost.reveal from', h) in
  rewrite (cl.ll_state_failure _) (cl.ll_state_failure (sndp r));
  r

let impl_for_inv_aux_cont_true
  (#opened: _)
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (no_interrupt: bool)
  (cont: bool)
: STGhost unit opened
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (fun _ -> impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (cont == true)
    (fun h -> no_interrupt == true)
= if no_interrupt
  then noop ()
  else begin
    let _ = elim_impl_for_inv_aux_false _ _ _ _ _ _ _ _ _ _ _ in
    rewrite // by contradiction
      (cl.ll_state_failure _)
      (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
  end

[@@__reduce__]
let impl_for_inv0
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (bin: byte_array)
  (vl: v k t)
  (bh: ll_state_ptr)
  (h0: state_t inv)
  (bfrom: R.ref SZ.t)
  (b_no_interrupt: R.ref bool)
  (bcont: R.ref bool)
  (cont: bool)
: Tot vprop
= exists_ (fun out -> exists_ (fun from -> exists_ (fun no_interrupt ->
    aparse p bin vl `star`
    cl.ll_state_pts_to bh out `star`
    R.pts_to bfrom full_perm from `star`
    R.pts_to b_no_interrupt full_perm no_interrupt `star`
    R.pts_to bcont full_perm cont `star`
    impl_for_inv_aux cl inv from0 to f vl.contents h0 out from no_interrupt cont
  )))

let impl_for_inv
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (bin: byte_array)
  (vl: v k t)
  (bh: ll_state_ptr)
  (h0: state_t inv)
  (bfrom: R.ref SZ.t)
  (b_no_interrupt: R.ref bool)
  (bcont: R.ref bool)
  (cont: bool)
: Tot vprop
= impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont cont

inline_for_extraction
let impl_for_test
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (bin: byte_array)
  (vl: v k t)
  (bh: ll_state_ptr)
  (h0: Ghost.erased (state_t inv))
  (bfrom: R.ref SZ.t)
  (b_no_interrupt: R.ref bool)
  (bcont: R.ref bool)
  (_: unit)
: STT bool
    (exists_ (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont))
    (fun cont -> impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont cont)
= let gcont = elim_exists () in
  rewrite
    (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont gcont)
    (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont gcont);
  let _ = gen_elim () in
  let cont = R.read bcont in
  rewrite
    (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont gcont)
    (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont cont);
  return cont

let rec fold_for_snoc
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (from0 to: nat)
  (f: (x: nat { from0 <= x /\ x < to }) -> fold_t state_t t unit inv inv)
  (from: nat)
  (i: t)
  (s: state_t inv)
: Lemma
  (requires (from0 <= from /\ from < to))
  (ensures (
    let (_, s1) = fold_for inv from0 from f i s in
    fold_for inv from0 (from + 1) f i s == Ghost.reveal f (from) i s1
  ))
  (decreases (from - from0))
= if from = from0
  then ()
  else
    let (_, s1) = Ghost.reveal f from0 i s in
    fold_for_snoc inv (from0 + 1) to f from i s1

inline_for_extraction
let impl_for_body
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (bin: byte_array)
  (vl: v k t)
  (bh: ll_state_ptr)
  (h0: Ghost.erased (state_t inv))
  (bfrom: R.ref SZ.t)
  (b_no_interrupt: R.ref bool)
  (bcont: R.ref bool)
  (fi: (x: SZ.t { SZ.v from0 <= SZ.v x /\ SZ.v x < SZ.v to }) -> fold_impl_t cl p false (Ghost.reveal f (SZ.v x)))
  (wl: load_ll_state_ptr_t cl inv)
  (ws: store_ll_state_ptr_t cl inv)
  (_: unit)
: STT unit
    (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont true)
    (fun _ -> exists_ (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont))
=
  rewrite
    (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont true)
    (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont true);
  let _ = gen_elim () in
  impl_for_inv_aux_cont_true cl inv from0 to f vl.contents h0 _ _ _ _;
  vpattern_rewrite (R.pts_to b_no_interrupt full_perm) true;
  let _ = elim_impl_for_inv_aux_true cl inv from0 to f vl.contents h0 _ _ _ _ in
  cl.ll_state_match_shape _ _;
  let from1 = read_replace bfrom in
  let from2 = SZ.add from1 1sz in
  fold_for_snoc inv (SZ.v from0) (SZ.v to) f (SZ.v from1) vl.contents h0;
  wl bh (fun out1 ->
    vpattern_rewrite (cl.ll_state_match _) out1;
    fi from1
      (
        R.pts_to b_no_interrupt full_perm true `star`
        R.pts_to bcont full_perm true `star`
        R.pts_to bfrom full_perm from1 `star`
        cl.ll_state_pts_to bh out1
      )
      (exists_ (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont))
      bin () out1 _
      (fun out2 h2 _ ->
        R.write bfrom from2;
        cl.ll_state_match_shape _ _;
        ws bh out2;
        let cont2 = from2 `SZ.lt` to in
        R.write bcont cont2;
        intro_impl_for_inv_aux_true cl inv from0 to f vl.contents h0 out2 from2 cont2 h2;
        rewrite
          (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont cont2)
          (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont cont2);
        noop ()
      )
      (fun h2 _ ->
        R.write b_no_interrupt false;
        R.write bcont false;
        intro_impl_for_inv_aux_false cl inv from0 to f vl.contents h0 false from2 h2;
        rewrite
          (exists_ (impl_for_inv_aux_false cl inv from0 to f vl.contents h0 false))
          (impl_for_inv_aux cl inv from0 to f vl.contents h0 out1 from1 false false);
        rewrite
          (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont false)
          (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont false);
        noop ()
      )
  )

let rec fold_for_inc_aux
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: nat) (to: nat)
  (f: ((x: nat { from0 <= x /\ x < to }) -> fold_t state_t t unit inv inv))
  (l: t)
  (h0: state_t inv)
  (from: nat)
  (prf: (x: nat { from0 <= x /\ x < to }) -> fold_state_inc cl (f x))
: Lemma
  (requires (
    from0 <= from /\ from <= to
  ))
  (ensures (
    sndp (fold_for inv from0 to f l h0) `cl.state_ge`
    sndp (fold_for inv from0 from f l h0)
  ))
  (decreases (to - from))
= 
  let (_, h1) = fold_for inv from0 from f l h0 in
  if to = from
  then cl.state_ge_refl h1
  else begin
    fold_for_snoc inv from0 to f from l h0;
    prf from l h1;
    let from' = from + 1 in
    fold_for_inc_aux cl inv from0 to f l h0 from' prf;
    let (_, h2) = fold_for inv from0 from' f l h0 in
    let (_, h3) = fold_for inv from0 to f l h0 in
    cl.state_ge_trans h3 h2 h1
  end

let fold_for_inc
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: nat) (to: nat)
  (f: ((x: nat { from0 <= x /\ x < to }) -> fold_t state_t t unit inv inv))
  (prf: (x: nat { from0 <= x /\ x < to }) -> fold_state_inc cl (f x))
: Tot (fold_state_inc cl (fold_for inv from0 to f))
= fun i h ->
  if from0 > to
  then cl.state_ge_refl h
  else fold_for_inc_aux cl inv from0 to f i h from0 prf

let elim_impl_for_inv_aux_false_strong
  (#opened: _)
  (#state_i: _) (#state_t: _) (#ll_state: _) (#ll_state_ptr: _)
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (prf: (x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_state_inc cl (Ghost.reveal f x))
  (l: t)
  (h0: state_t inv)
  (out: ll_state)
  (from: SZ.t)
  (no_interrupt: bool)
  (cont: bool)
: STGhost (Ghost.erased (state_t inv)) opened
    (impl_for_inv_aux cl inv from0 to f l h0 out from no_interrupt cont)
    (fun r -> cl.ll_state_failure r)
    (no_interrupt == false)
    (fun r ->
      Ghost.reveal r == sndp (fold_for inv (SZ.v from0) (SZ.v to) f l h0)
    )
= let r0 = elim_impl_for_inv_aux_false _ _ _ _ _ _ _ _ _ _ _ in
  fold_for_inc_aux cl inv (SZ.v from0) (SZ.v to) f l h0 (SZ.v (fstp r0)) prf;
  let res = get_return_state (fold_for inv (SZ.v from0) (SZ.v to) f l) h0 in
  cl.ll_state_failure_inc (sndp r0) res;
  res

inline_for_extraction
let impl_for_post
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (from0: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (bin: byte_array)
  (vl: v k t)
  (bh: ll_state_ptr)
  (h0: Ghost.erased (state_t inv))
  (bfrom: R.ref SZ.t)
  (b_no_interrupt: R.ref bool)
  (bcont: R.ref bool)
  (kpre kpost: vprop)
  (k_success: (
    (bout': ll_state) ->
    (h': Ghost.erased (state_t inv)) ->
    (v: unit) ->
    ST unit
      (kpre `star`
        aparse p bin vl `star`
        cl.ll_state_match h' bout')
      (fun _ -> kpost)
      (
        fold_for inv (SZ.v from0) (SZ.v to) f vl.contents h0 == (v, Ghost.reveal h')
      )
      (fun _ -> True)
  ))
  (k_failure: (
    (h': Ghost.erased (state_t inv)) ->
    (v: Ghost.erased unit) ->
    ST unit
      (kpre `star`
        aparse p bin vl `star`
        cl.ll_state_failure h')
      (fun _ -> kpost)
      (
        fold_for inv (SZ.v from0) (SZ.v to) f vl.contents h0 == (Ghost.reveal v, Ghost.reveal h')
      )
      (fun _ -> True)
  ))
  (prf: (x: nat { SZ.v from0 <= x /\ x < SZ.v to }) -> fold_state_inc cl (Ghost.reveal f x))
  (wl: load_ll_state_ptr_t cl inv)
: STT unit
    (kpre `star` impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont false)
    (fun _ -> kpost `star`
      exists_ (cl.ll_state_pts_to bh) `star`
      exists_ (R.pts_to bfrom full_perm) `star`
      exists_ (R.pts_to b_no_interrupt full_perm) `star`
      exists_ (R.pts_to bcont full_perm)
    )
=
    rewrite
      (impl_for_inv cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont false)
      (impl_for_inv0 cl inv p from0 to f bin vl bh h0 bfrom b_no_interrupt bcont false);
    let _ = gen_elim () in
    let no_interrupt = read_replace b_no_interrupt in
    if no_interrupt
    then begin
      let h' = elim_impl_for_inv_aux_true  cl inv from0 to f vl.contents _ _ _ _ _ in
      cl.ll_state_match_shape _ _;
      wl bh (fun out' ->
        vpattern_rewrite (cl.ll_state_match _) out';
        k_success out' h' ()
      )
    end else begin
      let r = elim_impl_for_inv_aux_false_strong cl inv from0 to f prf vl.contents _ _ _ _ _ in
      k_failure r ()
    end

#set-options "--print_universes --print_implicits"

let impl_for
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (from: SZ.t) (to: SZ.t)
  (f: Ghost.erased ((x: nat { SZ.v from <= x /\ x < SZ.v to }) -> fold_t state_t t unit inv inv))
  (prf: (x: nat { SZ.v from <= x /\ x < SZ.v to }) -> fold_state_inc cl (Ghost.reveal f x))
  (fi: (x: SZ.t { SZ.v from <= SZ.v x /\ SZ.v x < SZ.v to }) -> fold_impl_t cl p false (Ghost.reveal f (SZ.v x)))
  (with_size: bool)
  (wc: with_ll_state_ptr_t cl inv) // same
  (wl: load_ll_state_ptr_t cl inv)
  (ws: store_ll_state_ptr_t cl inv)
: Tot (fold_impl_t cl p with_size (fold_for inv (SZ.v from) (SZ.v to) f))
= fun kpre kpost #vbin bin _ bout h k_success k_failure ->
  cl.ll_state_match_shape _ _;
  let cont = from `SZ.lt` to in
  wc bout (fun bh ->
  with_local from (fun bfrom ->
  with_local true (fun b_no_interrupt ->
  with_local cont (fun bcont ->
    intro_impl_for_inv_aux_true cl inv from to f vbin.contents h bout from cont h;
    rewrite
      (impl_for_inv0 cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont cont)
      (impl_for_inv cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont cont);
    Steel.ST.Loops.while_loop
      (impl_for_inv cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont)
      (impl_for_test cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont)
      (impl_for_body cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont fi wl ws);
    impl_for_post cl inv p from to f bin vbin bh h bfrom b_no_interrupt bcont kpre kpost k_success k_failure prf wl
  ))))

let intro_nlist
  (#opened: _)
  (n: nat)
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (#vb: v parse_list_kind (list t))
  (b: byte_array)
: STGhost (v (parse_filter_kind parse_list_kind) (nlist n t)) opened
    (aparse (parse_list p) b vb)
    (fun vb' -> aparse (parse_nlist n p) b vb')
    (List.Tot.length vb.contents == n)
    (fun vb' ->
      array_of' vb' == array_of' vb /\
      (vb'.contents <: list t) == vb.contents
    )
= let _ = intro_filter _ (fun l -> List.Tot.length l = n) b in
  let _ = intro_synth _ (fun (x: parse_filter_refine _) -> (x <: (nlist n t))) b () in
  rewrite_aparse b (parse_nlist n p)

let elim_nlist
  (#opened: _)
  (n: nat)
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (#vb: v (parse_filter_kind parse_list_kind) (nlist n t))
  (b: byte_array)
: STGhost (v parse_list_kind (list t)) opened
    (aparse (parse_nlist n p) b vb)
    (fun vb' -> aparse (parse_list p) b vb')
    True
    (fun vb' ->
      array_of' vb' == array_of' vb /\
      (vb.contents <: list t) == vb'.contents
    )
= let _ = rewrite_aparse b (parse_nlist0 n p) in
  let _ = elim_synth _ _ b () in
  elim_filter _ _ b

#restart-solver

let parse_vlgen_alt_body_sz_t
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (n: SZ.t)
: Tot Type
= parse_vlgen_alt_body_t p (SZ.v n)

let synth_vlgen_alt_sz_payload
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (x: dtuple2 _ (parse_vlgen_alt_body_sz_t p))
: GTot t
= dsnd x

let synth_vlgen_alt_sz_payload_injective
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
: Lemma
  (synth_injective (synth_vlgen_alt_sz_payload p))
  [SMTPat (synth_injective (synth_vlgen_alt_sz_payload p))]
= synth_vlgen_alt_payload_injective p;
  assert (forall (x: dtuple2 _ (parse_vlgen_alt_body_sz_t p)) . synth_vlgen_alt_sz_payload p x == synth_vlgen_alt_payload p (| SZ.v (dfst x), dsnd x |) )

let parse_vlgen_alt_sz_body
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (n': SZ.t)
: Tot (parser _ (parse_vlgen_alt_body_sz_t p n'))
=
  parse_strict (weaken parse_vlgen_alt_payload_kind (parse_fldata p (SZ.v n')))

let parse_vlgen_alt_sz_eq
  (#sk: parser_kind)
  (sp: parser sk SZ.t)
  (#k: parser_kind)
  (#t: Type)
  (p: parser k t)
  (b: bytes)
: Lemma
  (parse (parse_vlgen_alt (sp `parse_synth` size_v) p) b ==
    parse (((sp `parse_dtuple2` parse_vlgen_alt_sz_body p) `parse_synth` synth_vlgen_alt_sz_payload p)) b)
= parse_vlgen_alt_eq (sp `parse_synth` size_v) p b;
  parse_synth_eq sp size_v b;
  parse_synth_eq (sp `parse_dtuple2` parse_vlgen_alt_sz_body p) (synth_vlgen_alt_sz_payload p) b;
  parse_dtuple2_eq sp (parse_vlgen_alt_sz_body p) b

inline_for_extraction
let validate_vlgen_alt_sz_body
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (#p: parser k t)
  (validate_fldata: (
    (sz32: SZ.t) ->
    Tot (validator (parse_fldata p (SZ.v sz32)))
  ))
  (n': SZ.t)
: Tot (validator (parse_vlgen_alt_sz_body p n'))
= // FIXME: validate_strict breaks at extraction
  rewrite_validator
    (validate_weaken parse_vlgen_alt_payload_kind (validate_fldata n') ())
    (parse_vlgen_alt_sz_body p n')

inline_for_extraction
let validate_vlgen_alt_sz'
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk SZ.t)
  (sv: validator sp)
  (sr: leaf_reader sp)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (#p: parser k t)
  (validate_fldata: (
    (sz32: SZ.t) ->
    Tot (validator (parse_fldata p (SZ.v sz32)))
  ))
  (sq: squash (sk.parser_kind_subkind == Some ParserStrong))
: validator ((sp `parse_dtuple2` parse_vlgen_alt_sz_body p) `parse_synth` synth_vlgen_alt_sz_payload p)
= validate_synth
        (validate_dtuple2
          sv
          sr
          (parse_vlgen_alt_sz_body p)
          (validate_vlgen_alt_sz_body validate_fldata)
        )
        (synth_vlgen_alt_sz_payload p)
        (synth_vlgen_alt_sz_payload_injective p)

inline_for_extraction
let validate_vlgen_alt_sz
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk SZ.t)
  (sv: validator sp)
  (sr: leaf_reader sp)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (#p: parser k t)
  (validate_fldata: (
    (sz32: SZ.t) ->
    Tot (validator (parse_fldata p (SZ.v sz32)))
  ))
: Pure (validator (parse_vlgen_alt (sp `parse_synth` size_v) p))
    (requires sk.parser_kind_subkind == Some ParserStrong)
    (ensures (fun _ -> True))
= rewrite_validator'
    (validate_vlgen_alt_sz'
      sv
      sr
      validate_fldata
      ()
    )
    (parse_vlgen_alt (sp `parse_synth` size_v) p)
    (fun b -> parse_vlgen_alt_sz_eq sp p b)

inline_for_extraction
let jump_vlgen_alt_sz'
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk SZ.t)
  (sv: jumper sp)
  (sr: leaf_reader sp)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (sq: squash (sk.parser_kind_subkind == Some ParserStrong))
: jumper ((sp `parse_dtuple2` parse_vlgen_alt_sz_body p) `parse_synth` synth_vlgen_alt_sz_payload p)
= jump_synth
        (jump_dtuple2
          sv
          sr
          (parse_vlgen_alt_sz_body p)
          (fun n' ->
            jump_strict
              (jump_weaken
                parse_vlgen_alt_payload_kind
                (jump_fldata p n')
                ()
              )
          )
        )
        (synth_vlgen_alt_sz_payload p)
        (synth_vlgen_alt_sz_payload_injective p)

inline_for_extraction
let jump_vlgen_alt_sz
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk SZ.t)
  (sv: jumper sp)
  (sr: leaf_reader sp)
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
: Pure (jumper (parse_vlgen_alt (sp `parse_synth` size_v) p))
    (requires sk.parser_kind_subkind == Some ParserStrong)
    (ensures (fun _ -> True))
= rewrite_jumper'
    (jump_vlgen_alt_sz'
      sv
      sr
      p
      ()
    )
    (parse_vlgen_alt (sp `parse_synth` size_v) p)
    (fun b -> parse_vlgen_alt_sz_eq sp p b)

let validate_size_prefixed
  (#st: Type)
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk st)
  (sv: validator sp)
  (sr: leaf_reader sp)
  (sz: (st -> SZ.t) { synth_injective sz })
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (#p: parser k t)
  (v: ((s: SZ.t) -> validator (parse_fldata p (SZ.v s))))
: Pure (validator (parse_size_prefixed sp sz p)) 
    (requires (sk.parser_kind_subkind == Some ParserStrong))
    (ensures (fun _ -> True))
=
    validate_vlgen_alt_sz
      (validate_synth sv sz ())
      (read_synth sr sz (fun x -> sz x) ())
      v

let jump_size_prefixed
  (#st: Type)
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk st)
  (sv: jumper sp)
  (sr: leaf_reader sp)
  (sz: (st -> SZ.t) { synth_injective sz })
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
: Pure (jumper (parse_size_prefixed sp sz p)) 
    (requires (sk.parser_kind_subkind == Some ParserStrong))
    (ensures (fun _ -> True))
=
    jump_vlgen_alt_sz
      (jump_synth sv sz ())
      (read_synth sr sz (fun x -> sz x) ())
      p

#push-options "--z3rlimit 16"
#restart-solver

let intro_parse_size_prefixed
  (#opened: _)
  (#st: Type)
  (#sk: Ghost.erased parser_kind)
  (sp: parser sk st)
  (sz: (st -> SZ.t) { synth_injective sz })
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (#vbs: v _ _)
  (bs: byte_array)
  (#vb: v _ _)
  (b: byte_array)
: STGhost (v _ _) opened
    (aparse (parse_synth sp sz) bs vbs `star`
      aparse p b vb)
    (fun vbs' -> aparse (parse_size_prefixed sp sz p) bs vbs')
    (sk.parser_kind_subkind == Some ParserStrong /\
      AP.adjacent (array_of' vbs) (array_of' vb) /\
      SZ.v vbs.contents == AP.length (array_of' vb))
    (fun vbs' ->
      AP.merge_into (array_of' vbs) (array_of' vb) (array_of' vbs') /\
      vbs'.contents == vb.contents
    )
= let n = SZ.v vbs.contents in
  let _ = intro_fldata _ n b in
  let _ = rewrite_aparse b (weaken parse_vlgen_alt_payload_kind (parse_fldata p n)) in
  let _ = intro_parse_strict _ b in
  let vbs = intro_synth _ size_v bs () in
  let _ = rewrite_aparse b (parse_vlgen_alt_body p vbs.contents) in
  let _ = intro_dtuple2
    _
    #_
    #(parse_vlgen_alt_body_t p)
    (parse_vlgen_alt_body p)
    bs b
  in
  let _ = intro_synth _ (synth_vlgen_alt_payload p) bs (synth_vlgen_alt_payload_injective p) in
  rewrite_aparse bs (parse_size_prefixed sp sz p)

#pop-options

#push-options "--z3rlimit 32"
#restart-solver

let elim_parse_size_prefixed
  (#opened: _)
  (#st: Type)
  (#sk: Ghost.erased parser_kind)
  (sp: parser sk st)
  (sz: (st -> SZ.t) { synth_injective sz })
  (#k: Ghost.erased parser_kind)
  (#t: Type)
  (p: parser k t)
  (#vb: v _ _)
  (b: byte_array)
: STGhost (Ghost.erased byte_array) opened
    (aparse (parse_size_prefixed sp sz p) b vb)
    (fun bl -> exists_ (fun (vb': v _ _) -> exists_ (fun (vbl: v _ _) ->
      aparse (parse_synth sp sz) b vb' `star`
      aparse p bl vbl `star` pure (
      AP.merge_into (array_of' vb') (array_of' vbl) (array_of' vb) /\
      SZ.v vb'.contents == AP.length (array_of' vbl) /\
      vbl.contents == vb.contents
    ))))
    (sk.parser_kind_subkind == Some ParserStrong)
    (fun _ -> True)
= synth_vlgen_alt_payload_injective p;
  let _ = rewrite_aparse b ((((sp `parse_synth` sz) `parse_synth` size_v) `parse_dtuple2` parse_vlgen_alt_body p) `parse_synth` synth_vlgen_alt_payload p) in
  let _ = elim_synth _ _ b () in
  let bl = ghost_split_dtuple2
    (parse_synth (parse_synth sp sz) size_v)
    (parse_vlgen_alt_body p)
    b
  in
  let _ = gen_elim () in
  let n = ghost_dtuple2_tag _ _ b bl in
  let _ = gen_elim () in
  let _ = elim_synth _ _ b () in
  let _ = rewrite_aparse bl (parse_strict (weaken parse_vlgen_alt_payload_kind (parse_fldata p n))) in
  let _ = elim_parse_strict _ bl in
  let _ = rewrite_aparse bl (parse_fldata p n) in
  let _ = elim_fldata p _ bl in
  bl

let impl_size_prefixed
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#st: Type)
  (#sk: Ghost.erased parser_kind)
  (#sp: parser sk st)
  (sj: jumper sp)
  (sr: leaf_reader sp)
  (sz: (st -> SZ.t) { synth_injective sz })
  (#t: Type)
  (#k: Ghost.erased parser_kind)
  (#p: parser k t)
  (#ret_t: _) (#pre: _) (#post: _)
  (f: Ghost.erased (fold_t state_t t ret_t pre post))
  (body_with_size: bool)
  (fi: fold_impl_t cl p body_with_size f)
  (with_size: bool)
: Pure (fold_impl_t cl (parse_size_prefixed sp sz p) with_size (Ghost.reveal f))
    (requires (sk.parser_kind_subkind == Some ParserStrong))
    (ensures (fun _ -> True))
= fun kpre kpost #vbin bin _ bout h k_success k_failure ->
  let _ = elim_parse_size_prefixed sp sz p bin in
  let _ = gen_elim () in
  let v_hdr = vpattern_replace (aparse (parse_synth sp sz) bin) in
  let sz_pl =
    if body_with_size
    returns ST (if body_with_size then SZ.t else unit)
      (aparse (parse_synth sp sz) bin v_hdr)
      (fun _ -> aparse (parse_synth sp sz) bin v_hdr)
      True
      (fun sz_pl -> body_with_size ==> sz_pl == v_hdr.contents)
    then read_synth' sr sz () bin
    else return ()
  in
  let b_pl = hop_aparse_aparse (jump_synth sj sz ()) _ bin _ in
  let v_pl = vpattern_replace (aparse p b_pl) in
  let restore (#opened: _) () : STGhostT unit opened
    (aparse (parse_synth sp sz) bin v_hdr `star`
      aparse p b_pl v_pl)
    (fun _ -> aparse (parse_size_prefixed sp sz p) bin vbin)
  = let _ = intro_parse_size_prefixed _ _ _ _ _ in
    vpattern_rewrite (aparse (parse_size_prefixed sp sz p) bin) vbin
  in
  noop ();
  fi
    (kpre `star`
      aparse (parse_synth sp sz) bin v_hdr)
    kpost
    b_pl sz_pl
    bout h
    (fun out' h' v' ->
      restore ();
      k_success out' h' v'
    )
    (fun h' v' ->
      restore ();
      k_failure h' v'
    )

let impl_list_index
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (#k: Ghost.erased parser_kind)
  (#p: parser k t)
  (jp: jumper p)
  (n: SZ.t)
  (idx: (i: SZ.t { SZ.v i < SZ.v n }))
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (fi: fold_impl_t cl p false f)
  (with_size: bool)
: Pure (fold_impl_t cl (parse_nlist (SZ.v n) p) with_size (fold_list_index inv (SZ.v n) (SZ.v idx) f))
    (requires  k.parser_kind_subkind == Some ParserStrong)
    (ensures (fun _ -> True))
= fun kpre kpost #vbin bin _ bout h k_success k_failure ->
  let _ = elim_nlist _ _ bin in
  let b = list_nth jp bin idx in
  let _ = gen_elim () in
  let vbin_l = vpattern_replace (aparse (parse_list p) bin) in
  let vb = vpattern_replace (aparse p b) in
  let vbin_r = vpattern_replace (aparse (parse_list p) (list_nth_tail _ _ _ _)) in
  let bin_r = vpattern_replace_erased (fun bin_r -> aparse (parse_list p) bin_r vbin_r) in
  let restore (#opened: _) () : STGhostT unit opened
    (aparse (parse_list p) bin vbin_l `star`
      aparse p b vb `star`
      aparse (parse_list p) bin_r vbin_r)
    (fun _ -> aparse (parse_nlist (SZ.v n) p) bin vbin)
  = let _ = intro_cons p b bin_r in
    let _ = list_append p bin b in
    let _ = intro_nlist (SZ.v n) p bin in
    rewrite
      (aparse (parse_nlist (SZ.v n) p) bin _)
      (aparse (parse_nlist (SZ.v n) p) bin vbin)
  in
  fi
    (kpre `star`
      aparse (parse_list p) bin vbin_l `star`
      aparse (parse_list p) bin_r vbin_r)
    kpost
    b () bout h
    (fun out' h' v' ->
      restore ();
      k_success out' h' v'
    )
    (fun h' v' ->
      restore ();
      k_failure h' v'
    )

#pop-options

let impl_list_index_of
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (#k: Ghost.erased parser_kind)
  (#p: parser k t)
  (jp: jumper p)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (fi: fold_impl_t cl p false f)
  (with_size: bool)
  (n: SZ.t)
  (idx: Ghost.erased ((i: nat { i < SZ.v n }) -> Tot (i: nat { i < SZ.v n })))
  (idx' : (i: SZ.t) -> Pure SZ.t (requires SZ.v i < SZ.v n) (ensures fun j -> SZ.v j == Ghost.reveal idx (SZ.v i)))
  (j: SZ.t {SZ.v j < SZ.v n})
: Pure (fold_impl_t cl (parse_nlist (SZ.v n) p) with_size (fold_list_index_of inv f (SZ.v n) idx (SZ.v j)))
    (requires  k.parser_kind_subkind == Some ParserStrong)
    (ensures (fun _ -> True))
= impl_list_index cl inv jp n (idx' j) f fi with_size

#push-options "--z3rlimit 16"
#restart-solver

let impl_for_list
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (#k: parser_kind)
  (#p: parser k t)
  (j: jumper p)
  (fi: fold_impl_t cl p false f)
  (prf: fold_state_inc cl f)
  (idx: array_index_fn)
  (wc: with_ll_state_ptr_t cl inv)
  (wl: load_ll_state_ptr_t cl inv)
  (ws: store_ll_state_ptr_t cl inv)
: Pure (fold_impl_t cl (parse_list p) true (fold_for_list inv f idx.array_index_f_nat))
    (requires (
      k.parser_kind_subkind == Some ParserStrong
    ))
    (ensures (fun _ -> True))
= fun kpre kpost #vbin bin in_sz bout h k_success k_failure ->
  let n = list_length j bin in_sz in
  let vl_l = intro_nlist (SZ.v n) _ bin in
  let restore (#opened: _) () : STGhostT unit opened
    (
      aparse (parse_nlist (SZ.v n) p) bin vl_l)
    (fun _ -> aparse (parse_list p) bin vbin)
  =
    let _ = elim_nlist _ _ bin in
    rewrite (aparse _ bin _) (aparse (parse_list p) bin vbin)
  in
  impl_for
    cl inv
    (parse_nlist (SZ.v n) p)
    0sz
    n
    (fold_list_index_of inv f (SZ.v n) (idx.array_index_f_nat (SZ.v n)))
    (fun x i s -> prf (List.Tot.index i (idx.array_index_f_nat (SZ.v n) x)) s)
    (impl_list_index_of cl inv j f fi false n (idx.array_index_f_nat (SZ.v n)) (idx.array_index_f_sz n))
    false wc wl ws
    kpre
    kpost
    bin () bout h
    (fun out' h' v' ->
      restore ();
      k_success out' h' v'
    )
    (fun h' v' ->
      restore ();
      k_failure h' v'
    )

#pop-options

(* list fold *)

let impl_list_hole_inv_prop
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (h0: state_t inv)
  (l: list t)
  (h: state_t inv)
: Tot prop
=
  fold_list inv f l h0 == ((), h)

[@@__reduce__]
let impl_list_hole_inv_true
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (bh: ll_state_ptr)
  (h0: state_t inv)
  (l: list t)
: Tot vprop
= exists_ (fun (h: state_t inv) -> exists_ (fun out ->
    cl.ll_state_match h out `star`
    cl.ll_state_pts_to bh out `star`
    pure (
      impl_list_hole_inv_prop inv f h0 l h
    )
  ))

[@@__reduce__]
let impl_list_hole_inv_false
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (bh: ll_state_ptr)
  (h0: state_t inv)
  (l: list t)
: Tot vprop
= 
  exists_ (cl.ll_state_pts_to bh) `star`
  exists_ (fun h ->
    cl.ll_state_failure h `star`
    pure (impl_list_hole_inv_prop inv f h0 l h)
  )

let impl_list_hole_inv
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (bh: ll_state_ptr)
  (h0: state_t inv)
  (cont: bool)
  (l: list t)
: Tot vprop
= if cont
  then impl_list_hole_inv_true cl inv f bh h0 l
  else impl_list_hole_inv_false cl inv f bh h0 l

inline_for_extraction
let impl_list_post_true
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (#k: Ghost.erased parser_kind)
  (p: parser k t)
  (w: load_ll_state_ptr_t cl inv)
  (#vbin: _)
  (bin: byte_array)
  (h: Ghost.erased (state_t inv))
  (kpre kpost: vprop)
  (k_success: (
    (out': ll_state) ->
    (h': Ghost.erased (state_t inv)) ->
    (v: unit) ->
    ST unit
      (kpre `star` aparse (parse_list p) bin vbin `star`
        cl.ll_state_match h' out')
      (fun _ -> kpost)
      (
        fold_list inv f vbin.contents h == (v, Ghost.reveal h')
      )
      (fun _ -> True)
  ))
  (bh: ll_state_ptr)
  (cont: bool)
  (l: Ghost.erased (list t))
: ST unit
    (kpre `star` aparse (parse_list p) bin vbin `star`
      impl_list_hole_inv cl inv f bh h cont l)
    (fun _ ->
      kpost `star`
      exists_ (cl.ll_state_pts_to bh)
    )
    (cont == true /\
      Ghost.reveal l == vbin.contents)
    (fun _ -> True)
=
  rewrite
    (impl_list_hole_inv cl inv f bh h cont l)
    (impl_list_hole_inv_true cl inv f bh h l);
  let _ = gen_elim () in
  cl.ll_state_match_shape _ _;
  w bh (fun out' ->
    vpattern_rewrite (cl.ll_state_match _) out';
    k_success _ _ ()
  )

inline_for_extraction
let impl_list_post_false
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (#k: Ghost.erased parser_kind)
  (p: parser k t)
  (#vbin: _)
  (bin: byte_array)
  (h: Ghost.erased (state_t inv))
  (kpre kpost: vprop)
  (k_failure: (
    (h': Ghost.erased (state_t inv)) ->
    (v: Ghost.erased unit) ->
    ST unit
      (kpre `star` aparse (parse_list p) bin vbin `star` cl.ll_state_failure h')
      (fun _ -> kpost)
      (
        fold_list inv f vbin.contents h == (Ghost.reveal v, Ghost.reveal h')
      )
      (fun _ -> True)
  ))
  (bh: ll_state_ptr)
  (cont: bool)
  (l: Ghost.erased (list t))
: ST unit
    (kpre `star` aparse (parse_list p) bin vbin `star`
      impl_list_hole_inv cl inv f bh h cont l)
    (fun _ ->
      kpost `star`
      exists_ (cl.ll_state_pts_to bh)
    )
    (cont == false /\
      Ghost.reveal l == vbin.contents)
    (fun _ -> True)
=
  rewrite
    (impl_list_hole_inv cl inv f bh h cont l)
    (impl_list_hole_inv_false cl inv f bh h l);
  let _ = gen_elim () in
  k_failure _ ()

let rec fold_list_append
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv (inv))
  (state: state_t inv)
  (l1 l2: list t)
: Lemma
  (ensures (fold_list inv f (l1 `List.Tot.append` l2) state ==
    (let (_, state1) = fold_list inv f l1 state in
    fold_list inv f l2 state1)))
  (decreases l1)
= match l1 with
  | [] -> ()
  | a :: q ->
    let (_, state0) = f a state in
    fold_list_append inv f state0 q l2

let fold_list_snoc
  #state_i #state_t
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv (inv))
  (state: state_t inv)
  (l: list t)
  (x: t)
: Lemma
  (ensures (fold_list inv f (List.Tot.snoc (l, x)) state ==
    (let (_, state1) = fold_list inv f l state in
    f x state1)))
= fold_list_append inv f state l [x]

inline_for_extraction
let impl_list_body_false
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (prf: fold_state_inc cl f)
  (#k: parser_kind)
  (p: parser k t)
  (bh: ll_state_ptr)
  (h0: Ghost.erased (state_t inv))
  (#opened: _)
  (va: v k t { AP.length (array_of' va) > 0 })
  (a: byte_array)
  (l: Ghost.erased (list t))
: STGhostT unit opened
    (aparse p a va `star` impl_list_hole_inv cl inv f bh h0 false l)
    (fun _ -> aparse p a va `star` impl_list_hole_inv cl inv f bh h0 false (List.Tot.snoc (Ghost.reveal l, va.contents)))
= rewrite
    (impl_list_hole_inv cl inv f bh h0 false l)
    (impl_list_hole_inv_false cl inv f bh h0 l);
  let _ = gen_elim () in
  fold_list_snoc inv f h0 l va.contents;
  prf va.contents (sndp (fold_list inv f l h0));
  cl.ll_state_failure_inc _ (sndp (fold_list inv f (List.Tot.snoc (Ghost.reveal l, va.contents)) h0));
  rewrite
    (impl_list_hole_inv_false cl inv f bh h0 (List.Tot.snoc (Ghost.reveal l, va.contents)))
    (impl_list_hole_inv cl inv f bh h0 false (List.Tot.snoc (Ghost.reveal l, va.contents)))

inline_for_extraction
let impl_list_body_true
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (#k: Ghost.erased parser_kind)
  (p: parser k t)
  (impl_f: fold_impl_t cl p false f)
  (wl: load_ll_state_ptr_t cl inv)
  (ws: store_ll_state_ptr_t cl inv)
  (bh: ll_state_ptr)
  (h0: Ghost.erased (state_t inv))
  (va: v k t { AP.length (array_of' va) > 0 })
  (a: byte_array)
  (l: Ghost.erased (list t))
: STT bool
    (aparse p a va `star` impl_list_hole_inv cl inv f bh h0 true l)
    (fun res -> aparse p a va `star` impl_list_hole_inv cl inv f bh h0 res (List.Tot.snoc (Ghost.reveal l, va.contents)))
= with_local true (fun bres ->
    rewrite
      (impl_list_hole_inv cl inv f bh h0 true l)
      (impl_list_hole_inv_true cl inv f bh h0 l);
    let _ = gen_elim () in
    cl.ll_state_match_shape _ _;
    wl bh (fun out ->
      fold_list_snoc inv f h0 l va.contents;
      vpattern_rewrite (cl.ll_state_match _) out;
      impl_f
        (cl.ll_state_pts_to bh out `star` R.pts_to bres full_perm true)
        (aparse p a va `star` exists_ (fun res -> R.pts_to bres full_perm res `star` impl_list_hole_inv cl inv f bh h0 res (List.Tot.snoc (Ghost.reveal l, va.contents))))
        a ()
        out
        _
        (fun out' h' _ ->
          cl.ll_state_match_shape _ _;
          ws bh out' ;
          rewrite
            (impl_list_hole_inv_true cl inv f bh h0 (List.Tot.snoc (Ghost.reveal l, va.contents)))
            (impl_list_hole_inv cl inv f bh h0 true (List.Tot.snoc (Ghost.reveal l, va.contents)));
          noop ()
        )
        (fun h' _ ->
          R.write bres false;
          rewrite
            (impl_list_hole_inv_false cl inv f bh h0 (List.Tot.snoc (Ghost.reveal l, va.contents)))
            (impl_list_hole_inv cl inv f bh h0 false (List.Tot.snoc (Ghost.reveal l, va.contents)));
          noop ()
        )
      ;
      let _ = gen_elim () in
      let res = R.read bres in
      rewrite
        (impl_list_hole_inv cl inv f bh h0 _ _)
        (impl_list_hole_inv cl inv f bh h0 res (List.Tot.snoc (Ghost.reveal l, va.contents)));
      return res
  ))

#push-options "--z3rlimit 32"
#restart-solver

inline_for_extraction
let impl_list
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: Ghost.erased (fold_t state_t t unit inv inv))
  (prf: fold_state_inc cl f)
  (#k: Ghost.erased parser_kind)
  (p: parser k t)
  (impl_f: fold_impl_t cl p false f)
  (j: jumper p) // MUST be computed OUTSIDE of impl_list
  (wc: with_ll_state_ptr_t cl inv) // same
  (wl: load_ll_state_ptr_t cl inv)
  (ws: store_ll_state_ptr_t cl inv)
: Pure (fold_impl_t cl (parse_list p) true (fold_list inv f))
    (requires (
      k.parser_kind_subkind == Some ParserStrong
    ))
    (ensures (fun _ -> True))
= fun kpre kpost #vl_l bin in_sz bout h k_success k_failure ->
  cl.ll_state_match_shape _ _;
  wc bout (fun bh ->
    noop ();
    rewrite
      (impl_list_hole_inv_true cl inv f bh h [])
      (impl_list_hole_inv cl inv f bh h true []);
    let cont = list_iter_with_interrupt
      j
      (impl_list_hole_inv cl inv f bh h)
      (impl_list_body_true cl inv f p impl_f wl ws bh h)
      (impl_list_body_false cl inv f prf p bh h)
      bin
      in_sz
    in
    if cont
    then impl_list_post_true cl inv f p wl bin h kpre kpost k_success bh cont _
    else impl_list_post_false cl inv f p bin h kpre kpost k_failure bh cont _
  )

#pop-options

(* Implementing programs *)

let rec fold_list_inc'
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (prf: fold_state_inc cl f)
  (input: list t)
  (s: state_t inv)
: Lemma
  (ensures (
    let (v, s') = fold_list inv f input s in
    s' `cl.state_ge` s
  ))
  (decreases input)
= match input with
  | [] -> cl.state_ge_refl s
  | hd :: tl ->
    prf hd s;
    let (_, s1) = f hd s in
    fold_list_inc' cl inv f prf tl s1;
    let (_, s2) = fold_list inv f tl s1 in
    cl.state_ge_trans s2 s1 s

let fold_list_inc
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (prf: fold_state_inc cl f)
: Tot (fold_state_inc cl (fold_list inv f))
= fold_list_inc' cl inv f prf

let fold_for_list_inc
  #state_i #state_t #ll_state #ll_state_ptr
  (cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (inv: state_i)
  (#t: Type)
  (f: fold_t state_t t unit inv inv)
  (prf: fold_state_inc cl f)
  (idx: ((n: nat) -> (x: nat {x < n}) -> (y: nat {y < n})))
: Tot (fold_state_inc cl (fold_for_list inv f idx))
= fun l s ->
  let n = List.Tot.length l in
  fold_for_inc cl inv 0 n (fold_list_index_of inv f n (idx n))
    (fun i l s -> prf (List.Tot.index l (idx n i)) s)
    l s

let rec prog_inc
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#action_t: (t: Type) -> (pre: state_i) -> (post: state_i) -> Type)
  (#action_sem: ((#t: Type) -> (#pre: _) -> (#post: _) -> action_t t pre post -> stt state_t t pre post))
  (a_cl: action_impl cl action_t action_sem)
  (#ret_t: Type)
  (#pre: state_i)
  (#post: state_i)
  (#ne #pr: bool)
  (#ty: typ type_of_scalar ne pr)
  (p: prog type_of_scalar state_t action_t ty ret_t pre post)
: Tot (fold_state_inc cl (sem action_sem p))
  (decreases p)
= fun input s ->
  match p with
  | PRet _ -> cl.state_ge_refl s
  | PAction a ->
    a_cl.a_inc a s
  | PBind f g ->
    prog_inc a_cl f input s;
    let (v1, s1) = sem action_sem f input s in
    prog_inc a_cl (g v1) input s1;
    let (_, s2) = sem action_sem (g v1) input s1 in
    cl.state_ge_trans s2 s1 s
  | PScalar _ _ -> cl.state_ge_refl s
  | PIfP x ptrue pfalse ->
    if x
    then prog_inc a_cl (ptrue ()) input s
    else prog_inc a_cl (pfalse ()) input s
  | PIfT x ptrue pfalse ->
    if x
    then prog_inc a_cl (ptrue ()) (coerce _ input) s
    else prog_inc a_cl (pfalse ()) (coerce _ input) s
  | PPair #_ #_ #_ #_ #_ #_ #t1 #_ #_ #t2 f1 f2 ->
    let (input1, input2) = (input <: type_of_typ (TPair t1 t2)) in
    prog_inc a_cl f1 input1 s;
    let (v1, s1) = sem action_sem f1 input1 s in
    prog_inc a_cl (f2 v1) input2 s1;
    let (_, s2) = sem action_sem (f2 v1) input2 s1 in
    cl.state_ge_trans s2 s1 s
  | PList i f ->
    fold_list_inc
      cl
      (sem action_sem f)
      (fun i s -> prog_inc a_cl f i s)
      input
      s
  | PListFor i idx f ->
    fold_for_list_inc
      cl
      _
      (sem action_sem f)
      (prog_inc a_cl f)
      idx.array_index_f_nat
      input
      s
  | PChoice #_ #_ #_ #_ #_ #sc #_ #_ #t f ->
    let (| tag, payload |) = (input <: type_of_typ (TChoice sc t)) in
    prog_inc a_cl (f tag) payload s
  | PSizePrefixed _ _ p ->
    prog_inc a_cl p (coerce _ input) s

let validate_ifthenelse
  (#k: parser_kind)
  (x: bool)
  (ttrue: (squash (x == true) -> Type))
  (tfalse: (squash (x == false) -> Type))
  (ptrue: (squash (x == true) -> parser k (ttrue ())))
  (pfalse: (squash (x == false) -> parser k (tfalse ())))
  (jtrue: (squash (x == true) -> validator (ptrue ())))
  (jfalse: (squash (x == false) -> validator (pfalse ())))
: Tot (validator #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse))
= fun a len err ->
  if x
  then coerce (validator #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse)) (jtrue ()) a len err
  else coerce (validator #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse)) (jfalse ()) a len err

let validate_TPair
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (#ne1 #ne2 #pr2: bool)
  (t1: typ type_of_scalar ne1 false)
  (v1: validator (parser_of_typ p_of_s t1))
  (t2: typ type_of_scalar ne2 pr2)
  (v2: validator (parser_of_typ p_of_s t2))
: Tot (validator (parser_of_typ p_of_s (TPair t1 t2)))
= validate_weaken (pkind (ne1 || ne2) pr2) (validate_pair v1 v2) ()

let validate_TChoice
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (s: scalar_t)
  (#ne: bool)
  (#pr: bool)
  (body: (type_of_scalar s -> typ type_of_scalar ne pr))
  (body_v: ((k: type_of_scalar s) -> validator (parser_of_typ p_of_s (body k))))
: Tot (validator (parser_of_typ p_of_s (TChoice s body)))
= 
  validate_weaken (pkind true pr)
    (validate_dtuple2
      (p_of_s s).scalar_validator
      (p_of_s s).scalar_reader
      _
      body_v
    )
    ()

let validate_TSizePrefixed
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (s: scalar_t)
  (sz: (type_of_scalar s -> SZ.t) {synth_injective sz})
  (#ne: bool)
  (#pr: bool)
  (t: typ type_of_scalar ne pr)
  (v: validator (parser_of_typ p_of_s t))
: Tot (validator (parser_of_typ p_of_s (TSizePrefixed s sz t)))
= validate_weaken (pkind true false)
    (validate_size_prefixed
      (p_of_s s).scalar_validator
      (p_of_s s).scalar_reader
      sz
      #_ #_ #(parser_of_typ p_of_s t)
//      (fun (sz: SZ.t) -> admit_validator ())
      (if pr
      then (fun sz -> validate_fldata_consumes_all v sz)
      else (fun sz -> validate_fldata_gen v sz)
      )
    )
    ()

let validate_TIf
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (#ne: bool)
  (#pr: bool)
  (b: bool)
  (ttrue: (squash (b == true) -> typ type_of_scalar ne pr))
  (vtrue: ((sq: squash (b == true)) -> validator (parser_of_typ p_of_s (ttrue ()))))
  (tfalse: (squash (b == false) -> typ type_of_scalar ne pr))
  (vfalse: ((sq: squash (b == false)) -> validator (parser_of_typ p_of_s (tfalse ()))))
: Tot (validator (parser_of_typ p_of_s (TIf b ttrue tfalse)))
= coerce _ (validate_ifthenelse
    b
    (fun _ -> type_of_typ (ttrue ()))
    (fun _ -> type_of_typ (tfalse ()))
    (fun _ -> parser_of_typ p_of_s (ttrue ()))
    (fun _ -> parser_of_typ p_of_s (tfalse ()))
    vtrue
    vfalse
  )

let validate_TList
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (#t: typ type_of_scalar true false)
  (v: validator (parser_of_typ p_of_s t))
: Tot (validator (parser_of_typ p_of_s (TList t)))
= LowParse.SteelST.List.validate_list v

let validate_TUnit
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
: Tot (validator (parser_of_typ p_of_s TUnit))
= validate_weaken (pkind false false) (validate_total_constant_size parse_empty 0sz) ()

let validate_TFalse
  (#scalar_t: Type)
  (#type_of_scalar: (scalar_t -> Type))
  (p_of_s: ((s: scalar_t) -> scalar_ops (type_of_scalar s)))
  (ne pr: bool)
: Tot (validator (parser_of_typ p_of_s (TFalse ne pr)))
= validate_fail _ _ ()

let jump_ifthenelse
  (#k: parser_kind)
  (x: bool)
  (ttrue: (squash (x == true) -> Type))
  (tfalse: (squash (x == false) -> Type))
  (ptrue: (squash (x == true) -> parser k (ttrue ())))
  (pfalse: (squash (x == false) -> parser k (tfalse ())))
  (jtrue: (squash (x == true) -> jumper (ptrue ())))
  (jfalse: (squash (x == false) -> jumper (pfalse ())))
: Tot (jumper #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse))
= fun a ->
  if x
  then coerce (jumper #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse)) (jtrue ()) a
  else coerce (jumper #k #(ifthenelse x ttrue tfalse) (ifthenelse_dep x ttrue tfalse (parser k) ptrue pfalse)) (jfalse ()) a

let extract_impl_stt'_unit
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (f: Ghost.erased (stt state_t unit pre post))
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (kpre0: vprop)
  (fi: (kpre: vprop) -> (kpost: vprop) -> stt_impl_t' cl f (kpre0 `star` kpre) kpost)
: STT bool
    (vpre `star` kpre0)
    (fun res -> extract_impl_unit_post cl pre post f h res `star` kpre0)
= mk (fun out ->
    with_local true (fun bres ->
      fi
        (R.pts_to bres full_perm true)
        (kpre0 `star` exists_ (fun res ->
          R.pts_to bres full_perm res `star`
          extract_impl_unit_post cl pre post f h res
        ))
        out
        h
        (fun out' h' _ ->
          rewrite
            (exists_ (cl.ll_state_match h'))
            (extract_impl_unit_post cl pre post f h true);
          noop ()
        )
        (fun h' _ ->
          R.write bres false;
          rewrite
            (cl.ll_state_failure h')
            (extract_impl_unit_post cl pre post f h false);
          noop ()
        );
      let _ = gen_elim () in
      let res = R.read bres in
      vpattern_rewrite (extract_impl_unit_post cl pre post f h) res;
      return res
    )
  )

let extract_impl_stt_unit
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (#f: Ghost.erased (stt state_t unit pre post))
  (fi: stt_impl_t cl f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
: STT bool
    (vpre)
    (fun res -> extract_impl_unit_post cl pre post f h res)
= extract_impl_stt'_unit
    f mk emp fi

let extract_impl_fold_unit
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (#t: Type)
  (#f: Ghost.erased (fold_t state_t t unit pre post))
  (#k: parser_kind)
  (#p: parser k t)
  (#with_size: bool)
  (fi: fold_impl_t cl p with_size f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
: Tot (extract_impl_fold_unit_t fi mk)
= fun vbin bin bin_sz ->
  extract_impl_stt'_unit
    (Ghost.reveal f vbin.contents)
    mk
    (aparse p bin vbin)
    (fun kpre kpost -> fi kpre kpost #vbin bin bin_sz)

let extract_impl_stt'
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (#rett: Type)
  (f: Ghost.erased (stt state_t rett pre post))
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (kpre0: vprop)
  (fi: (kpre: vprop) -> (kpost: vprop) -> stt_impl_t' cl f (kpre0 `star` kpre) kpost)
  (r: R.ref rett)
: STT bool
    (vpre `star` kpre0 `star` exists_ (R.pts_to r full_perm))
    (fun res -> extract_impl_post cl pre post r f h res `star` kpre0)
= mk (fun out ->
    with_local true (fun bres ->
      fi
        (R.pts_to bres full_perm true `star`
          exists_ (R.pts_to r full_perm))
        (kpre0 `star` exists_ (fun res ->
          R.pts_to bres full_perm res `star`
          extract_impl_post cl pre post r f h res
        ))
        out
        h
        (fun out' h' v ->
          let _ = gen_elim () in
          R.write r v;
          rewrite
            (exists_ (cl.ll_state_match h') `star` R.pts_to r full_perm v)
            (extract_impl_post cl pre post r f h true);
          noop ()
        )
        (fun h' _ ->
          R.write bres false;
          rewrite
            (cl.ll_state_failure h' `star` exists_ (R.pts_to r full_perm))
            (extract_impl_post cl pre post r f h false);
          noop ()
        );
      let _ = gen_elim () in
      let res = R.read bres in
      vpattern_rewrite (extract_impl_post cl pre post r f h) res;
      return res
    )
  )

let extract_impl_stt
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (#t: Type)
  (#f: Ghost.erased (stt state_t t pre post))
  (fi: stt_impl_t cl f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (r: R.ref t)
: STT bool
    (vpre `star` exists_ (R.pts_to r full_perm))
    (fun res -> extract_impl_post cl pre post r f h res)
= extract_impl_stt'
    f mk emp fi r

let extract_impl_fold
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (#pre #post: state_i)
  (#t: Type)
  (#rett: Type)
  (#f: Ghost.erased (fold_t state_t t rett pre post))
  (#k: parser_kind)
  (#p: parser k t)
  (#with_size: bool)
  (fi: fold_impl_t cl p with_size f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (vbin: v k t)
  (bin: byte_array)
  (bin_sz: (if with_size then size_of (array_of' vbin) else unit))
  (r: R.ref rett)
: STT bool
    (vpre `star` aparse p bin vbin `star` exists_ (R.pts_to r full_perm))
    (fun res -> extract_impl_post cl pre post r (Ghost.reveal f vbin.contents) h res `star` aparse p bin vbin)
= extract_impl_stt'
    (Ghost.reveal f vbin.contents)
    mk
    (aparse p bin vbin)
    (fun kpre kpost -> fi kpre kpost #vbin bin bin_sz)
    r

let extract_impl_stt'_no_failure
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (no_fail: no_ll_state_failure_t cl)
  (#pre #post: state_i)
  (#rett: Type0)
  (f: Ghost.erased (stt state_t rett pre post))
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (kpre0: vprop)
  (fi: (kpre: vprop) -> (kpost: vprop) -> stt_impl_t' cl f (kpre0 `star` kpre) kpost)
  (dummy: rett) // because Steel doesn't have uninitialized references yet
: STT rett
    (vpre `star` kpre0)
    (fun res -> 
      exists_ (fun (h': state_t post) ->
        exists_ (cl.ll_state_match h') `star`
        kpre0 `star`
        pure (Ghost.reveal f (Ghost.reveal h) == (res, h'))
    ))
= mk (fun out ->
    with_local dummy (fun bres ->
      fi
        (exists_ (R.pts_to bres full_perm))
        (kpre0 `star`
          exists_ (fun res -> exists_ (fun (h': state_t post) ->
            R.pts_to bres full_perm res `star`
            exists_ (cl.ll_state_match h') `star`
            pure (Ghost.reveal f (Ghost.reveal h) == (res, h'))
        )))
        out
        h
        (fun out' h' v ->
          let _ = gen_elim () in
          R.write bres v;
          noop ()
        )
        (fun h' _ ->
          no_fail _;
          rewrite // by contradiction
            (exists_ (R.pts_to bres full_perm))
            (exists_ (fun res -> exists_ (fun (h': state_t post) ->
              R.pts_to bres full_perm res `star`
              exists_ (cl.ll_state_match h') `star`
              pure (Ghost.reveal f (Ghost.reveal h) == (res, h'))
            )))
        );
      let _ = gen_elim () in
      let res = R.read bres in
      return res
    )
  )

let extract_impl_stt_no_failure
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (no_fail: no_ll_state_failure_t cl)
  (#pre #post: state_i)
  (#t: Type)
  (#f: Ghost.erased (stt state_t t pre post))
  (fi: stt_impl_t cl f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (dummy: t) // because Steel doesn't have uninitialized references yet
: STT t
    vpre
    (fun res -> 
      exists_ (fun (h': state_t post) ->
        exists_ (cl.ll_state_match h') `star`
        pure (Ghost.reveal f (Ghost.reveal h) == (res, h'))
    ))
= let res = extract_impl_stt'_no_failure no_fail f mk emp fi dummy in
  let _ = gen_elim () in
  return res

let extract_impl_fold_no_failure
  (#state_i: Type) (#state_t: state_i -> Type) (#ll_state: Type) (#ll_state_ptr: Type)
  (#cl: low_level_state state_i state_t ll_state ll_state_ptr)
  (no_fail: no_ll_state_failure_t cl)
  (#pre #post: state_i)
  (#t: Type)
  (#rett: Type)
  (#f: Ghost.erased (fold_t state_t t rett pre post))
  (#k: parser_kind)
  (#p: parser k t)
  (#with_size: bool)
  (fi: fold_impl_t cl p with_size f)
  (#vpre: vprop)
  (#h: Ghost.erased (state_t pre))
  (mk: mk_ll_state_t cl vpre h)
  (vbin: v k t)
  (bin: byte_array)
  (bin_sz: (if with_size then size_of (array_of' vbin) else unit))
  (dummy: rett)
: STT rett
    (vpre `star` aparse p bin vbin)
    (fun res -> 
      aparse p bin vbin `star`
      exists_ (fun (h': state_t post) ->
        exists_ (cl.ll_state_match h') `star`
        pure (Ghost.reveal f vbin.contents (Ghost.reveal h) == (res, h'))
    ))
= let res = extract_impl_stt'_no_failure no_fail
    (Ghost.reveal f vbin.contents)
    mk
    (aparse p bin vbin)
    (fun kpre kpost -> fi kpre kpost #vbin bin bin_sz)
    dummy
  in
  let _ = gen_elim () in
  return res
