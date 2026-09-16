#include "voxelize.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>

namespace {

// Largest grid the voxelizer will use along one axis. Beyond this a model is
// voxelized coarser than asked for rather than spending minutes on it.
constexpr int VOXEL_MAX_DIVISIONS = 512;
// Samples taken along one triangle edge. Caps the cost of very large faces.
constexpr int VOXEL_MAX_TRIANGLE_STEPS = 256;
// Triangle budget for one proxy. A model over budget is rebuilt with bigger
// voxels; a viewer instancing thousands of these cannot afford detail here.
constexpr size_t VOXEL_MAX_TRIANGLES = 60000;
// How many times the voxel size may be doubled to get under that budget.
constexpr int VOXEL_MAX_ATTEMPTS = 5;
// Cell budget for the flood fill that finds the outside of a model. Beyond it
// the fill is skipped and enclosed cavities keep their (invisible) faces.
constexpr size_t VOXEL_MAX_FILL_CELLS = 8000000;

struct Voxel
{
    int x = 0;
    int y = 0;
    int z = 0;

    bool operator==(const Voxel& other) const
    {
        return x == other.x && y == other.y && z == other.z;
    }
};

struct VoxelHash
{
    size_t operator()(const Voxel& v) const noexcept
    {
        // Three 21-bit fields, enough for VOXEL_MAX_DIVISIONS in either direction.
        const uint64_t key = (static_cast<uint64_t>(static_cast<uint32_t>(v.x) & 0x1FFFFFu)) |
                             (static_cast<uint64_t>(static_cast<uint32_t>(v.y) & 0x1FFFFFu) << 21) |
                             (static_cast<uint64_t>(static_cast<uint32_t>(v.z) & 0x1FFFFFu) << 42);
        return std::hash<uint64_t>{}(key);
    }
};

// Face order: +z, -z, +x, -x, +y, -y.
constexpr int FACE_COUNT = 6;
constexpr int NEIGHBOUR_OFFSETS[FACE_COUNT][3] = {
    {0, 0, 1}, {0, 0, -1}, {1, 0, 0}, {-1, 0, 0}, {0, 1, 0}, {0, -1, 0},
};
// Per face: which voxel component stays constant across the plane, and which
// two span it.
constexpr int FACE_PLANE_COMPONENT[FACE_COUNT] = {2, 2, 0, 0, 1, 1};
constexpr int FACE_GRID_A_COMPONENT[FACE_COUNT] = {0, 0, 2, 2, 0, 0};
constexpr int FACE_GRID_B_COMPONENT[FACE_COUNT] = {1, 1, 1, 1, 2, 2};

int voxelComponent(const Voxel& v, int component)
{
    if (component == 0) {
        return v.x;
    }
    if (component == 1) {
        return v.y;
    }
    return v.z;
}

int64_t cellKey(int a, int b)
{
    return (static_cast<int64_t>(a) << 32) | static_cast<uint32_t>(b);
}

// One merged rectangle of a voxel plane, written out as two triangles wound so
// the face points along its own normal.
void emitVoxelQuad(int face, int planeCoord, int gridA, int gridB, int w, int h, float voxelSize,
                   const float origin[3], std::vector<float>& vertices, std::vector<uint32_t>& indices)
{
    const float planeOrigin = origin[FACE_PLANE_COMPONENT[face]];
    const float aOrigin = origin[FACE_GRID_A_COMPONENT[face]];
    const float bOrigin = origin[FACE_GRID_B_COMPONENT[face]];
    const float planePos = planeOrigin + static_cast<float>(planeCoord + (face % 2 == 0 ? 1 : 0)) * voxelSize;
    const float a0 = aOrigin + static_cast<float>(gridA) * voxelSize;
    const float a1 = aOrigin + static_cast<float>(gridA + w) * voxelSize;
    const float b0 = bOrigin + static_cast<float>(gridB) * voxelSize;
    const float b1 = bOrigin + static_cast<float>(gridB + h) * voxelSize;

    float corners[4][3];
    switch (face) {
    case 0:  // +z
        corners[0][0] = a0; corners[0][1] = b0; corners[0][2] = planePos;
        corners[1][0] = a1; corners[1][1] = b0; corners[1][2] = planePos;
        corners[2][0] = a1; corners[2][1] = b1; corners[2][2] = planePos;
        corners[3][0] = a0; corners[3][1] = b1; corners[3][2] = planePos;
        break;
    case 1:  // -z
        corners[0][0] = a1; corners[0][1] = b0; corners[0][2] = planePos;
        corners[1][0] = a0; corners[1][1] = b0; corners[1][2] = planePos;
        corners[2][0] = a0; corners[2][1] = b1; corners[2][2] = planePos;
        corners[3][0] = a1; corners[3][1] = b1; corners[3][2] = planePos;
        break;
    case 2:  // +x
        corners[0][0] = planePos; corners[0][1] = b0; corners[0][2] = a1;
        corners[1][0] = planePos; corners[1][1] = b0; corners[1][2] = a0;
        corners[2][0] = planePos; corners[2][1] = b1; corners[2][2] = a0;
        corners[3][0] = planePos; corners[3][1] = b1; corners[3][2] = a1;
        break;
    case 3:  // -x
        corners[0][0] = planePos; corners[0][1] = b0; corners[0][2] = a0;
        corners[1][0] = planePos; corners[1][1] = b0; corners[1][2] = a1;
        corners[2][0] = planePos; corners[2][1] = b1; corners[2][2] = a1;
        corners[3][0] = planePos; corners[3][1] = b1; corners[3][2] = a0;
        break;
    case 4:  // +y
        corners[0][0] = a0; corners[0][1] = planePos; corners[0][2] = b1;
        corners[1][0] = a1; corners[1][1] = planePos; corners[1][2] = b1;
        corners[2][0] = a1; corners[2][1] = planePos; corners[2][2] = b0;
        corners[3][0] = a0; corners[3][1] = planePos; corners[3][2] = b0;
        break;
    default:  // -y
        corners[0][0] = a0; corners[0][1] = planePos; corners[0][2] = b0;
        corners[1][0] = a1; corners[1][1] = planePos; corners[1][2] = b0;
        corners[2][0] = a1; corners[2][1] = planePos; corners[2][2] = b1;
        corners[3][0] = a0; corners[3][1] = planePos; corners[3][2] = b1;
        break;
    }

    // Quads are never shared between faces because their normals differ, so
    // corners are appended rather than looked up; the viewer computes normals.
    const auto base = static_cast<uint32_t>(vertices.size() / 3);
    for (const auto& corner : corners) {
        vertices.push_back(corner[0]);
        vertices.push_back(corner[1]);
        vertices.push_back(corner[2]);
    }
    indices.push_back(base);
    indices.push_back(base + 1);
    indices.push_back(base + 2);
    indices.push_back(base);
    indices.push_back(base + 2);
    indices.push_back(base + 3);
}

using VoxelSet = std::unordered_set<Voxel, VoxelHash>;

// Marks every voxel touched by a vertex or by the surface of a triangle. The
// grid is anchored at the model's own minimum and its last cell along each axis
// absorbs the far surface, so the proxy occupies exactly the model's bounds
// instead of spilling into an extra half-empty layer.
VoxelSet collectVoxels(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                       float voxelSize, const float origin[3], const int dims[3])
{
    VoxelSet occupied;
    occupied.reserve(vertices.size() / 3);
    const float invVoxelSize = 1.0f / voxelSize;

    const auto axisIndex = [&](float value, int axis) {
        const int i = static_cast<int>(std::floor((value - origin[axis]) * invVoxelSize));
        return std::clamp(i, 0, dims[axis] - 1);
    };
    const auto addVoxel = [&](float x, float y, float z) {
        occupied.insert(Voxel{axisIndex(x, 0), axisIndex(y, 1), axisIndex(z, 2)});
    };

    for (size_t i = 0; i + 2 < vertices.size(); i += 3) {
        addVoxel(vertices[i], vertices[i + 1], vertices[i + 2]);
    }

    // Sample every triangle's surface so thin walls, railings and roofs survive
    // even when their corners land in the same voxel.
    const float step = std::max(0.05f, voxelSize / 8.0f);
    const auto vertexCount = static_cast<uint32_t>(vertices.size() / 3);
    for (size_t t = 0; t + 2 < indices.size(); t += 3) {
        const uint32_t ia = indices[t];
        const uint32_t ib = indices[t + 1];
        const uint32_t ic = indices[t + 2];
        if (ia >= vertexCount || ib >= vertexCount || ic >= vertexCount) {
            continue;
        }
        const float* p0 = &vertices[static_cast<size_t>(ia) * 3];
        const float e1[3] = {vertices[static_cast<size_t>(ib) * 3] - p0[0],
                             vertices[static_cast<size_t>(ib) * 3 + 1] - p0[1],
                             vertices[static_cast<size_t>(ib) * 3 + 2] - p0[2]};
        const float e2[3] = {vertices[static_cast<size_t>(ic) * 3] - p0[0],
                             vertices[static_cast<size_t>(ic) * 3 + 1] - p0[1],
                             vertices[static_cast<size_t>(ic) * 3 + 2] - p0[2]};
        const float len1 = std::sqrt(e1[0] * e1[0] + e1[1] * e1[1] + e1[2] * e1[2]);
        const float len2 = std::sqrt(e2[0] * e2[0] + e2[1] * e2[1] + e2[2] * e2[2]);
        const int steps1 = std::clamp(static_cast<int>(std::ceil(len1 / step)), 1, VOXEL_MAX_TRIANGLE_STEPS);
        const int steps2 = std::clamp(static_cast<int>(std::ceil(len2 / step)), 1, VOXEL_MAX_TRIANGLE_STEPS);
        for (int si = 0; si <= steps1; si++) {
            const float u = static_cast<float>(si) / static_cast<float>(steps1);
            for (int sj = 0; sj <= steps2; sj++) {
                const float v = static_cast<float>(sj) / static_cast<float>(steps2);
                if (u + v > 1.0f) {
                    break;
                }
                addVoxel(p0[0] + u * e1[0] + v * e2[0], p0[1] + u * e1[1] + v * e2[1],
                         p0[2] + u * e1[2] + v * e2[2]);
            }
        }
    }

    return occupied;
}

// Empty cells reachable from outside the model, as a padded dense grid. A model
// whose grid would be too large returns an empty grid, which the caller reads as
// "treat every empty neighbour as outside".
struct ExteriorGrid
{
    std::vector<char> cells;  // 1 = reachable from outside
    int min[3] = {0, 0, 0};
    int dim[3] = {0, 0, 0};

    bool valid() const { return !cells.empty(); }

    bool isOutside(int x, int y, int z) const
    {
        const int lx = x - min[0];
        const int ly = y - min[1];
        const int lz = z - min[2];
        if (lx < 0 || ly < 0 || lz < 0 || lx >= dim[0] || ly >= dim[1] || lz >= dim[2]) {
            return true;
        }
        return cells[(static_cast<size_t>(lz) * dim[1] + ly) * dim[0] + lx] != 0;
    }
};

ExteriorGrid collectExterior(const VoxelSet& occupied)
{
    ExteriorGrid grid;
    int lo[3] = {INT32_MAX, INT32_MAX, INT32_MAX};
    int hi[3] = {INT32_MIN, INT32_MIN, INT32_MIN};
    for (const auto& v : occupied) {
        const int p[3] = {v.x, v.y, v.z};
        for (int c = 0; c < 3; c++) {
            lo[c] = std::min(lo[c], p[c]);
            hi[c] = std::max(hi[c], p[c]);
        }
    }

    size_t cellCount = 1;
    for (int c = 0; c < 3; c++) {
        grid.min[c] = lo[c] - 1;
        grid.dim[c] = (hi[c] - lo[c]) + 3;  // one empty layer on each side
        cellCount *= static_cast<size_t>(grid.dim[c]);
        if (cellCount > VOXEL_MAX_FILL_CELLS) {
            return ExteriorGrid{};
        }
    }

    grid.cells.assign(cellCount, 0);
    const auto index = [&](int x, int y, int z) {
        return (static_cast<size_t>(z) * grid.dim[1] + y) * grid.dim[0] + x;
    };

    // Flood fill inwards from a corner of the padding layer, which is empty by
    // construction, so anything it cannot reach is an enclosed cavity.
    std::vector<int> stack;
    stack.reserve(1024);
    grid.cells[index(0, 0, 0)] = 1;
    stack.push_back(0);
    while (!stack.empty()) {
        const int flat = stack.back();
        stack.pop_back();
        const int x = flat % grid.dim[0];
        const int y = (flat / grid.dim[0]) % grid.dim[1];
        const int z = flat / (grid.dim[0] * grid.dim[1]);
        for (int face = 0; face < FACE_COUNT; face++) {
            const int nx = x + NEIGHBOUR_OFFSETS[face][0];
            const int ny = y + NEIGHBOUR_OFFSETS[face][1];
            const int nz = z + NEIGHBOUR_OFFSETS[face][2];
            if (nx < 0 || ny < 0 || nz < 0 || nx >= grid.dim[0] || ny >= grid.dim[1] || nz >= grid.dim[2]) {
                continue;
            }
            const size_t ni = index(nx, ny, nz);
            if (grid.cells[ni] != 0) {
                continue;
            }
            if (occupied.count(Voxel{nx + grid.min[0], ny + grid.min[1], nz + grid.min[2]}) > 0) {
                continue;
            }
            grid.cells[ni] = 1;
            stack.push_back(static_cast<int>(ni));
        }
    }
    return grid;
}

// Turns the outer shell of the occupied set into merged quads.
void greedyMesh(const VoxelSet& occupied, const ExteriorGrid& exterior, float voxelSize,
                const float origin[3], VoxelMesh& out)
{
    // Collect the visible faces, grouped by direction and by the plane they sit
    // in. A face is visible when its neighbour is empty and, where the fill ran,
    // that empty neighbour connects to the outside.
    std::unordered_map<int, std::unordered_set<int64_t>> planeFaces[FACE_COUNT];
    for (const auto& voxel : occupied) {
        for (int face = 0; face < FACE_COUNT; face++) {
            const Voxel neighbour{voxel.x + NEIGHBOUR_OFFSETS[face][0], voxel.y + NEIGHBOUR_OFFSETS[face][1],
                                  voxel.z + NEIGHBOUR_OFFSETS[face][2]};
            if (occupied.count(neighbour) > 0) {
                continue;
            }
            if (exterior.valid() && !exterior.isOutside(neighbour.x, neighbour.y, neighbour.z)) {
                continue;
            }
            planeFaces[face][voxelComponent(voxel, FACE_PLANE_COMPONENT[face])].insert(
                cellKey(voxelComponent(voxel, FACE_GRID_A_COMPONENT[face]),
                        voxelComponent(voxel, FACE_GRID_B_COMPONENT[face])));
        }
    }

    // Greedy-merge each plane's cells into as few rectangles as possible.
    for (int face = 0; face < FACE_COUNT; face++) {
        for (const auto& planeEntry : planeFaces[face]) {
            const int planeCoord = planeEntry.first;
            const auto& cells = planeEntry.second;
            if (cells.empty()) {
                continue;
            }
            int minA = INT32_MAX;
            int maxA = INT32_MIN;
            int minB = INT32_MAX;
            int maxB = INT32_MIN;
            for (const auto key : cells) {
                const int a = static_cast<int>(key >> 32);
                const int b = static_cast<int>(static_cast<uint32_t>(key & 0xFFFFFFFF));
                minA = std::min(minA, a);
                maxA = std::max(maxA, a);
                minB = std::min(minB, b);
                maxB = std::max(maxB, b);
            }
            const int gridW = maxA - minA + 1;
            const int gridH = maxB - minB + 1;
            std::vector<char> visited(static_cast<size_t>(gridW) * static_cast<size_t>(gridH), 0);
            const auto isFree = [&](int a, int b) {
                return cells.count(cellKey(a, b)) > 0 &&
                       visited[static_cast<size_t>(b - minB) * gridW + (a - minA)] == 0;
            };

            for (int b = minB; b <= maxB; b++) {
                for (int a = minA; a <= maxA; a++) {
                    if (!isFree(a, b)) {
                        continue;
                    }
                    int w = 1;
                    while (a + w <= maxA && isFree(a + w, b)) {
                        w++;
                    }
                    int h = 1;
                    while (b + h <= maxB) {
                        bool rowFree = true;
                        for (int d = 0; d < w; d++) {
                            if (!isFree(a + d, b + h)) {
                                rowFree = false;
                                break;
                            }
                        }
                        if (!rowFree) {
                            break;
                        }
                        h++;
                    }
                    for (int db = 0; db < h; db++) {
                        for (int da = 0; da < w; da++) {
                            visited[static_cast<size_t>(b + db - minB) * gridW + (a + da - minA)] = 1;
                        }
                    }
                    emitVoxelQuad(face, planeCoord, a, b, w, h, voxelSize, origin, out.vertices,
                                  out.indices);
                }
            }
        }
    }
}

}  // namespace

VoxelMesh buildVoxelMesh(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                         float targetVoxelSize)
{
    VoxelMesh out;
    if (vertices.size() < 9 || indices.size() < 3 || !(targetVoxelSize > 0.0f)) {
        return out;
    }

    float minima[3] = {vertices[0], vertices[1], vertices[2]};
    float maxima[3] = {vertices[0], vertices[1], vertices[2]};
    for (size_t i = 0; i + 2 < vertices.size(); i += 3) {
        for (int c = 0; c < 3; c++) {
            minima[c] = std::min(minima[c], vertices[i + c]);
            maxima[c] = std::max(maxima[c], vertices[i + c]);
        }
    }
    const float maxExtent = std::max({maxima[0] - minima[0], maxima[1] - minima[1], maxima[2] - minima[2]});
    if (!(maxExtent > 0.0f) || !std::isfinite(maxExtent)) {
        return out;
    }

    for (int attempt = 0; attempt < VOXEL_MAX_ATTEMPTS; attempt++) {
        const float wanted = targetVoxelSize * static_cast<float>(1 << attempt);
        int divisions = std::max(1, static_cast<int>(std::ceil(maxExtent / wanted)));
        divisions = std::min(divisions, VOXEL_MAX_DIVISIONS);
        const float voxelSize = std::clamp(maxExtent / static_cast<float>(divisions), 0.05f, 10.0f);

        int dims[3];
        for (int c = 0; c < 3; c++) {
            dims[c] = std::max(1, static_cast<int>(std::ceil((maxima[c] - minima[c]) / voxelSize)));
        }

        const VoxelSet occupied = collectVoxels(vertices, indices, voxelSize, minima, dims);
        if (occupied.empty()) {
            return out;
        }

        out.vertices.clear();
        out.indices.clear();
        greedyMesh(occupied, collectExterior(occupied), voxelSize, minima, out);
        if (out.indices.empty()) {
            out.vertices.clear();
            return out;
        }

        out.voxelSize = voxelSize;
        if (out.indices.size() / 3 <= VOXEL_MAX_TRIANGLES || divisions <= 1) {
            break;
        }
        // Over budget: try again with voxels twice as large.
    }
    return out;
}
