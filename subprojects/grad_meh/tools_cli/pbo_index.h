#pragma once

#include <cstdint>
#include <string>
#include <vector>

// One model file found inside a PBO.
struct PboModelEntry
{
    // Full logical path, lower case with backslashes and no leading slash —
    // e.g. "a3\structures_f\civ\garage\garage_v1_f.p3d". This is the join key
    // the planner and the Zeus export both use.
    std::string logicalPath;
    // Path of the entry inside the PBO, exactly as the archive stores it.
    // Passed back to get_entry_data verbatim so the lookup is an exact match.
    std::string entryPath;
    // Absolute path of the containing PBO.
    std::string pboPath;
    uint32_t size = 0;
};

// Walks the given directories for *.pbo and lists every .p3d entry in them.
//
// grad_meh's own findPboPath resolves logical paths by scanning the live Arma
// process's open file handles, which is useless outside the game. Here the
// mapping comes from each archive's own "prefix" property instead.
//
// Archives that cannot be opened are reported through badArchives and skipped.
std::vector<PboModelEntry> indexModels(const std::vector<std::string>& modRoots,
                                       std::vector<std::string>& badArchives);

// Reads one entry's bytes. Returns false when the entry is missing or empty.
bool readEntry(const std::string& pboPath, const std::string& entryPath, std::vector<uint8_t>& out);
