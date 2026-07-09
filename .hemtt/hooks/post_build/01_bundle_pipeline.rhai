// RAMET post_build: stage everything that ships INSIDE @root_amet but isn't
// a PBO — the FlatDevil marker, the ramet/ + ocap_renderterrain python
// packages, the ocap docker context + process bat, docs/tools/batch, and
// the four native DLLs. HEMTT_OUT is @root_amet/ itself: everything written
// here ends up inside the produced zip.
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

// ocap_renderterrain python package: FlatDevil module (modules/ocap_renderterrain)
// merged with its docker context (subprojects/ocap-renderterrain/ocap-renderterrain)
// — same merge the old ocap subproject post_build hook performed.
let ocap_pkg_out = out.join("ocap_renderterrain");
let ocap_module_src = rfs.join("modules").join("ocap_renderterrain");
if ocap_module_src.exists() {
    ocap_module_src.copy(ocap_pkg_out);
} else {
    print("[RAMET post_build] WARN: modules/ocap_renderterrain missing");
}
let ocap_docker_src = rfs.join("subprojects").join("ocap-renderterrain").join("ocap-renderterrain");
if ocap_docker_src.exists() {
    ocap_docker_src.copy(ocap_pkg_out);
} else {
    print("[RAMET post_build] WARN: subprojects/ocap-renderterrain/ocap-renderterrain (docker context) missing");
}

// ocap_renderterrain_process.bat — sits next to ocap_renderterrain/ at @root_amet root
let ocap_bat_src = rfs.join("subprojects").join("ocap-renderterrain").join("ocap_renderterrain_process.bat");
if ocap_bat_src.exists() {
    ocap_bat_src.copy(out.join("ocap_renderterrain_process.bat"));
} else {
    print("[RAMET post_build] WARN: ocap_renderterrain_process.bat missing");
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

print("[RAMET post_build] done");
