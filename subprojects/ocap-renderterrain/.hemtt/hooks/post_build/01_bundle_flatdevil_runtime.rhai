let output = HEMTT_OUT;
let runtime = output.join("ocap_renderterrain");

HEMTT_RFS.join("modules").join("$FLATDEVIL$").copy(output.join("$FLATDEVIL$"));
HEMTT_RFS.join("modules").join("ocap_renderterrain").copy(runtime);
HEMTT_RFS.join("ocap-renderterrain").copy(runtime);
HEMTT_RFS.join("ocap-exporter").join("ocap_exporter_x64.dll").copy(output.join("ocap_exporter_x64.dll"));
HEMTT_RFS.join("ocap_renderterrain_process.bat").copy(output.join("ocap_renderterrain_process.bat"));

if runtime.join(".gitignore").exists() {
    runtime.join(".gitignore").remove_file();
}
if runtime.join(".vscode").exists() {
    runtime.join(".vscode").remove_dir_all();
}
