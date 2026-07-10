// RAMET post_build: stage everything that ships INSIDE @root_amet but isn't
// a PBO — the FlatDevil marker, the ramet/ python package, the ocap docker
// context + process launcher, docs/tools/batch, and the four native DLLs.
// HEMTT_OUT is @root_amet/ itself: everything written here ends up inside
// the produced zip. There is no in-game Docker trigger anymore — post-
// processing only ever runs via batch\03_postprocess.bat / .sh.
//
// Missing DLLs (native chain not built this session) are warned, not fatal —
// `hemtt check`/`hemtt build` must still succeed for SQF-only iteration.

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

// ocap-renderterrain docker context — copied to a top-level ocap_renderterrain/
// folder (alongside the process launcher below) for batch\03_postprocess to find.
let ocap_pkg_out = out.join("ocap_renderterrain");
let ocap_docker_src = rfs.join("subprojects").join("ocap-renderterrain").join("ocap-renderterrain");
if ocap_docker_src.exists() {
    ocap_docker_src.copy(ocap_pkg_out);
} else {
    print("[RAMET post_build] WARN: subprojects/ocap-renderterrain/ocap-renderterrain (docker context) missing");
}

// ocap_renderterrain_process.bat/.sh — sit next to ocap_renderterrain/ at @root_amet root
let ocap_bat_src = rfs.join("subprojects").join("ocap-renderterrain").join("ocap_renderterrain_process.bat");
if ocap_bat_src.exists() {
    ocap_bat_src.copy(out.join("ocap_renderterrain_process.bat"));
} else {
    print("[RAMET post_build] WARN: ocap_renderterrain_process.bat missing");
}
let ocap_sh_src = rfs.join("subprojects").join("ocap-renderterrain").join("ocap_renderterrain_process.sh");
if ocap_sh_src.exists() {
    ocap_sh_src.copy(out.join("ocap_renderterrain_process.sh"));
} else {
    print("[RAMET post_build] WARN: ocap_renderterrain_process.sh missing");
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

// subprojects/ native source is bundled via .hemtt/project.toml [files].include
// ("subprojects/**") instead of here — that's HEMTT's native mechanism for loose,
// non-PBO directories and keeps this hook focused on generated/merged content.

// Native DLLs — grad_meh ships at @root_amet root AND under intercept/ (Intercept
// scans <mod>/intercept/*.dll for plugins to load).
let grad_meh_dll = rfs.join("subprojects").join("grad_meh").join("build").join("lib64").join("grad_meh_x64.dll");
if grad_meh_dll.exists() {
    grad_meh_dll.copy(out.join("grad_meh_x64.dll"));
    out.join("intercept").create_dir_all();
    grad_meh_dll.copy(out.join("intercept").join("grad_meh_x64.dll"));
} else {
    print("[RAMET post_build] WARN: grad_meh_x64.dll missing — run release.ps1 -RebuildGradMehDll");
}

let ocap_exporter_dll = rfs.join("subprojects").join("ocap-renderterrain").join("ocap-exporter").join("ocap_exporter_x64.dll");
if ocap_exporter_dll.exists() {
    ocap_exporter_dll.copy(out.join("ocap_exporter_x64.dll"));
} else {
    print("[RAMET post_build] WARN: ocap_exporter_x64.dll missing");
}

let a3me_dll = rfs.join("subprojects").join("arma3MapExporter").join("publish").join("MapExportExtension_x64.dll");
if a3me_dll.exists() {
    a3me_dll.copy(out.join("MapExportExtension_x64.dll"));
} else {
    print("[RAMET post_build] WARN: MapExportExtension_x64.dll missing — run dotnet publish (see release.ps1)");
}

let intercept_dll = rfs.join("vendor").join("intercept").join("intercept_x64.dll");
if intercept_dll.exists() {
    intercept_dll.copy(out.join("intercept_x64.dll"));
} else {
    print("[RAMET post_build] WARN: vendor/intercept/intercept_x64.dll missing");
}

// Remove generated Python caches and debug symbols from the staged output.
let generated_cache_dirs = [
    out.join("ramet").join("__pycache__"),
    out.join("tools").join("__pycache__"),
    out.join("ocap_renderterrain").join("__pycache__")
];
for dir in generated_cache_dirs {
    if dir.exists() {
        dir.remove_dir_all();
    }
}

let generated_debug_files = [
    out.join("subprojects").join("grad_meh").join("intercept").join("rv").join("intercept_x64.pdb")
];
for file in generated_debug_files {
    if file.exists() {
        file.remove_file();
    }
}

print("[RAMET post_build] done");
