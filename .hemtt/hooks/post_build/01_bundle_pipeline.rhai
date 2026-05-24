// RAMET post_build: bundle the full pipeline alongside the @root_amet mod.
//
// Pattern mirrors ocap-renderterrain/.hemtt/hooks/post_build/01_bundle_archangel_runtime.rhai.
// HEMTT_OUT is the build output dir (becomes the zipped release root).
// HEMTT_RFS is the repo file system root.

print("[RAMET post_build] bundling pipeline");

let rfs = HEMTT_RFS;
let out = HEMTT_OUT;

// --- Archangel marker — registers ramet python module ---
let arch_src = rfs.join("modules").join("$ARCHANGEL$");
if arch_src.exists() {
    arch_src.copy(out.join("$ARCHANGEL$"));
}

// --- ramet python module (lands at <Arma3>/ramet, Archangel adds it to sys.path) ---
let ramet_src = rfs.join("ramet");
if ramet_src.exists() {
    ramet_src.copy(out.join("ramet"));
}

// --- batch scripts (operator runbook) ---
let batch_src = rfs.join("batch");
if batch_src.exists() {
    batch_src.copy(out.join("batch"));
}

// --- tools/ post-processing python ---
let tools_src = rfs.join("tools");
if tools_src.exists() {
    tools_src.copy(out.join("tools"));
}

// --- docs ---
let docs_src = rfs.join("docs");
if docs_src.exists() {
    docs_src.copy(out.join("docs"));
}

// --- ocap-renderterrain Docker context + companion bat ---
let or_dockerctx = rfs.join("subprojects").join("ocap-renderterrain").join("ocap-renderterrain");
if or_dockerctx.exists() {
    or_dockerctx.copy(out.join("ocap_renderterrain"));
}
let or_processbat = rfs.join("subprojects").join("ocap-renderterrain").join("ocap_renderterrain_process.bat");
if or_processbat.exists() {
    or_processbat.copy(out.join("ocap_renderterrain_process.bat"));
}

// --- @grad_meh mod (from subprojects/grad_meh/releases/{ver}/@grad_meh) ---
let gm_releases = rfs.join("subprojects").join("grad_meh").join("releases");
if gm_releases.exists() {
    // operator-determined latest. Easiest: glob *.zip OR copy releases/current/@grad_meh.
    // We attempt the "current" symlink/folder pattern hemtt produces.
    let gm_current = gm_releases.join("current").join("@grad_meh");
    if gm_current.exists() {
        gm_current.copy(out.join("@grad_meh"));
    } else {
        print("[RAMET post_build] WARN: subprojects/grad_meh/releases/current/@grad_meh missing — bundle will not include @grad_meh");
    }
}

// --- @ocap_renderterrain mod ---
let or_releases = rfs.join("subprojects").join("ocap-renderterrain").join("releases");
if or_releases.exists() {
    let or_current = or_releases.join("current").join("@ocap_renderterrain");
    if or_current.exists() {
        or_current.copy(out.join("@ocap_renderterrain"));
    } else {
        print("[RAMET post_build] WARN: subprojects/ocap-renderterrain/releases/current/@ocap_renderterrain missing");
    }
}

print("[RAMET post_build] done");
