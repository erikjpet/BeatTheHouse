extends "res://scripts/core/run_state.gd"

const POSTFIX_BOUNDARY_SEAM_KEY := "_postfix06_2_boundary_seam"
const POSTFIX_BOUNDARY_ERROR_AFTER_APPLY := "error_after_apply"
const POSTFIX_BOUNDARY_HEAT_TERMINAL := "heat_terminal"
const POSTFIX_BOUNDARY_DEBT_DUE_TERMINAL := "debt_due_terminal"
const POSTFIX_BOUNDARY_DEBT_DUE_NONTERMINAL := "debt_due_nonterminal"
const POSTFIX_BOUNDARY_CLOSING_TRAVEL := "closing_travel"

# The transaction contract installs a schema-valid causal state directly so it
# can qualify service-result fact publication without rendering a room. All
# ordinary fixtures still use RunState's complete production readiness proof.
func _scenario_semantic_ready() -> bool:
	if bool(current_environment.get("postfix06_2_fact_fixture", false)):
		return true
	return super._scenario_semantic_ready()


# Test-only boundary seams are stored in the environment graph rather than in a
# subclass scalar. detached_host_action_candidate() therefore carries the seam
# through the exact production clone/publish boundary under qualification.
# Each transition is injected only after the real boundary has completed, so a
# rejected action must discard both the production boundary and the injected
# terminal/error state.
func advance_environment_turns(amount: int = 1, profile_stages: bool = false) -> Dictionary:
	var result: Dictionary = super.advance_environment_turns(amount, profile_stages)
	return _apply_postfix_boundary_seam(result)


func advance_game_clock_minutes(amount: int) -> Dictionary:
	var result: Dictionary = super.advance_game_clock_minutes(amount)
	return _apply_postfix_boundary_seam(result)


func _apply_postfix_boundary_seam(result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)) or not bool(result.get("applied", false)):
		return result
	var mode := str(current_environment.get(POSTFIX_BOUNDARY_SEAM_KEY, ""))
	match mode:
		POSTFIX_BOUNDARY_ERROR_AFTER_APPLY:
			return {
				"ok": false,
				"applied": false,
				"failure_stage": POSTFIX_BOUNDARY_ERROR_AFTER_APPLY,
				"errors": ["Forced post-apply boundary rejection."],
			}
		POSTFIX_BOUNDARY_HEAT_TERMINAL:
			var heat_delta := maxi(0, 100 - suspicion_level())
			if heat_delta > 0:
				add_suspicion(
					"postfix_contract_boundary_heat",
					heat_delta,
					"behavior",
					false,
					{"environment_id": str(current_environment.get("id", ""))},
					true
				)
		POSTFIX_BOUNDARY_DEBT_DUE_TERMINAL, POSTFIX_BOUNDARY_DEBT_DUE_NONTERMINAL:
			# Timed service boundaries intentionally do not advance action debt in
			# production. This seam lets that distinct boundary implementation face
			# the same due-debt atomicity qualification without double-ticking the
			# ordinary environment-turn path.
			_advance_debt_clocks(1)
		POSTFIX_BOUNDARY_CLOSING_TRAVEL:
			begin_closing_time(current_environment, game_minute_of_day(), 1)
			force_closing_time_travel()
	return result
