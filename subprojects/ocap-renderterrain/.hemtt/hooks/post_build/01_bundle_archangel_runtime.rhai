let output = HEMTT_OUT;
let runtime = output.join("ocap_renderterrain");

HEMTT_RFS.join("modules").join("$ARCHANGEL$").copy(output.join("$ARCHANGEL$"));
HEMTT_RFS.join("modules").join("ocap_renderterrain").copy(runtime);
HEMTT_RFS.join("ocap-renderterrain").copy(runtime);
HEMTT_RFS.join("ocap-exporter").join("ocap_exporter_x64.dll").copy(output.join("ocap_exporter_x64.dll"));
HEMTT_RFS.join("ocap_renderterrain_process.bat").copy(output.join("ocap_renderterrain_process.bat"));

runtime.join(".gitignore").remove_file();
runtime.join(".vscode").remove_dir_all();
