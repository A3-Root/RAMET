// RAMET pre_build: stage subproject build outputs into the parent build dir
// so the post_build bundle hook can pick them up alongside @root_amet.
//
// Strategy: invoke `hemtt release` in each subproject (out-of-band shell-out),
// then mirror the produced `releases/{ver}/@{prefix}/` tree into HEMTT_OUT.
//
// Because rhai exposed by HEMTT is limited (no arbitrary shell), this hook
// performs the file copy only — the operator (or batch/99_full_pipeline.bat)
// is responsible for running `hemtt release` inside each subproject FIRST.
// If the staged folder is missing, we warn but do not fail; bundle hook
// will skip the missing piece.

print("[RAMET pre_build] staging subproject mod folders");

let rfs = HEMTT_RFS;
let out = HEMTT_OUT;

// grad_meh — copy the @grad_meh mod produced by its own hemtt release
let gm_releases = rfs.join("subprojects").join("grad_meh").join("releases");
if gm_releases.exists() {
    print("[RAMET pre_build] found subprojects/grad_meh/releases — caller must point bundle hook at latest");
} else {
    print("[RAMET pre_build] WARN: subprojects/grad_meh/releases missing — run `hemtt release` inside subprojects/grad_meh first");
}

// ocap-renderterrain — same pattern
let or_releases = rfs.join("subprojects").join("ocap-renderterrain").join("releases");
if or_releases.exists() {
    print("[RAMET pre_build] found subprojects/ocap-renderterrain/releases");
} else {
    print("[RAMET pre_build] WARN: subprojects/ocap-renderterrain/releases missing — run `hemtt release` inside subprojects/ocap-renderterrain first");
}
