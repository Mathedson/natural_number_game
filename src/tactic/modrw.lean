import tactic.interactive

open lean
open lean.parser

local postfix `?`:9001 := optional
local postfix *:9001 := many

namespace tactic
namespace interactive
open interactive interactive.types expr

private meta def resolve_name' (n : name) : tactic expr :=
do {
  p ← resolve_name n,
  match p with
  | expr.const n _ := mk_const n -- create metavars for universe levels
  | _              := i_to_expr p
  end
}

private meta def rw_goal (cfg : rewrite_cfg) (rs : list rw_rule) : tactic unit :=
rs.mmap' $ λ r, do
 save_info r.pos,
 eq_lemmas ← get_rule_eqn_lemmas r,
 orelse'
   (do e ← to_expr' r.rule, rewrite_target e {symm := r.symm, ..cfg})
   (eq_lemmas.mfirst $ λ n, do e ← mk_const n, rewrite_target e {symm := r.symm, ..cfg})
   (eq_lemmas.empty)

private meta def uses_hyp (e : expr) (h : expr) : bool :=
e.fold ff $ λ t _ r, r || to_bool (t = h)

private meta def rw_hyp (cfg : rewrite_cfg) : list rw_rule → expr → tactic unit
| []      hyp := skip
| (r::rs) hyp := do
  save_info r.pos,
  eq_lemmas ← get_rule_eqn_lemmas r,
  orelse'
    (do e ← to_expr' r.rule, when (not (uses_hyp e hyp)) $ rewrite_hyp e hyp {symm := r.symm, ..cfg} >>= rw_hyp rs)
    (eq_lemmas.mfirst $ λ n, do e ← mk_const n, rewrite_hyp e hyp {symm := r.symm, ..cfg} >>= rw_hyp rs)
    (eq_lemmas.empty)

private meta def rw_core (rs : parse rw_rules) (loca : parse location) (cfg : rewrite_cfg) : tactic unit :=
match loca with
| loc.wildcard := loca.try_apply (rw_hyp cfg rs.rules) (rw_goal cfg rs.rules)
| _            := loca.apply (rw_hyp cfg rs.rules) (rw_goal cfg rs.rules)
end >> (returnopt rs.end_pos >>= save_info <|> skip)

meta def rw' (q : parse rw_rules) (l : parse location) (cfg : rewrite_cfg := {}) : tactic unit :=
propagate_tags (rw_core q l cfg)

end interactive
end tactic
