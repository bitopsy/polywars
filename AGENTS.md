<!-- evolab:begin -->
## evolab (RTS AI coaching via MCP)
The `evolab` MCP server evolves and tests Lua AIs for Spring/Recoil games (polywars, voidborn, BAR). Tools are named `evolab_*`.
Loop for experiment NAME:
1. `evolab_status` - champions, fingerprints, operator success rates, stall, recent hypothesis verdicts.
2. `evolab_analyze` on the champion - who beats it, how do their fingerprints/genes differ?
3. `evolab_propose` 2-4 falsifiable hypotheses (small targeted gene changes, state the expected fingerprint shift).
4. `evolab_step` (a background job: if status is `running`, poll `evolab_job`). Refuted hypotheses are information; never retry them unchanged.
5. Every few generations: `evolab_round_robin`, `evolab_cross_eval` (multi-map), `evolab_dashboard`; report what learning curve, diversity,
   cycles (rock-paper-scissors) and operator stats say about HOW the search is going. Change strategy rather than tuning when stalled.
To start from the user's own Lua AI: `evolab_lua_candidates(path)` -> choose strategy-like literals -> `evolab_new_experiment(mode="lifted", seed_lua=path, selected=[...])`.
Use `backend="mock"` to rehearse; `backend="spring"` needs the engine (`evolab_doctor`). Never edit state.json by hand.
<!-- evolab:end -->
