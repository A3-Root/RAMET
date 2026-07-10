## Summary

Describe what changed and why.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Behavior change
- [ ] Documentation
- [ ] Refactor
- [ ] Other

## Affected Areas

- [ ] grad_meh export (spotlight UI / batch, `addons/grad_meh_main`, `addons/grad_meh_ui`)
- [ ] OCAP export (spotlight UI / batch, `addons/ocap_exporter`, `addons/ocap_ui`)
- [ ] In-game GMS export (`addons/a3me_main`, `addons/a3me_exporter`, `subprojects/arma3MapExporter`)
- [ ] Intercept host / diag-build detection (`addons/intercept_core`, `addons/main`)
- [ ] Post-processing pipeline (`tools/`, `tools/Dockerfile`, `map.json` schema)
- [ ] Deploy / zip packaging (`tools/deploy_to_planner.py`)
- [ ] Batch scripts (`batch/*.bat`, `batch/*.sh`)
- [ ] Native subprojects (`subprojects/grad_meh`, `subprojects/ocap-renderterrain`, `subprojects/arma3MapExporter`)
- [ ] Build/release (`release.ps1`, `release.sh`, `.hemtt/`)
- [ ] Documentation

## Validation

- [ ] `hemtt check -p -Lc14 -e` passes
- [ ] Tested in Arma 3 with `@CBA_A3` loaded (spotlight tiles and/or batch queue)
- [ ] Tested on both stable and diagnostic branches when diag-build detection is relevant
- [ ] Ran `batch\03_postprocess.bat` / `.sh` end to end when the post-process pipeline changed
- [ ] Ran `release.ps1` / `release.sh` end to end when build/release/`.hemtt` config changed
- [ ] Not applicable

## Documentation

- [ ] `README.md` updated if user-facing behavior changed
- [ ] `README_steam.md` updated if Workshop-facing behavior changed
- [ ] `docs/BULK_EXPORT.md` or `docs/SCHEMA.md` updated if workflows or `map.json` fields changed
- [ ] Not applicable
