// RAMET post_build: stage things that belong INSIDE @root_amet.
//
// HEMTT_OUT is the per-addon release dir — i.e. it IS @root_amet/. Everything
// written here ends up inside @root_amet in the produced zip.
//
// Sibling @-mods (@grad_meh, @ocap_renderterrain), the batch scripts, the
// Docker context and the process bat live OUTSIDE the @root_amet zip and are
// added by release.ps1 — see that script for the final bundle layout.

print("[RAMET post_build] staging in-addon assets");

let rfs = HEMTT_RFS;
let out = HEMTT_OUT;

// FlatDevil marker — FlatDevil scans loaded mods for this file
let fd_src = rfs.join("modules").join("$FLATDEVIL$");
if fd_src.exists() {
    fd_src.copy(out.join("$FLATDEVIL$"));
}

// ramet python module (referenced by $FLATDEVIL$ marker)
let ramet_src = rfs.join("ramet");
if ramet_src.exists() {
    ramet_src.copy(out.join("ramet"));
}

// docs ride along with @root_amet
let docs_src = rfs.join("docs");
if docs_src.exists() {
    docs_src.copy(out.join("docs"));
}

// tools/ post-processing python — referenced by batch scripts via relative path
let tools_src = rfs.join("tools");
if tools_src.exists() {
    tools_src.copy(out.join("tools"));
}

// batch/ operator runbook — sits inside @root_amet alongside tools/
let batch_src = rfs.join("batch");
if batch_src.exists() {
    batch_src.copy(out.join("batch"));
}

print("[RAMET post_build] done — run release.ps1 to produce the full sibling-mod bundle");
