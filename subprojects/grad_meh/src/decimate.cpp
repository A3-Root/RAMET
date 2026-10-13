#include "decimate.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>

namespace {

// Cells along the longest axis for the first attempt. Halved on every retry.
constexpr int DECIMATE_START_DIVISIONS = 256;

// Below this the shape stops being recognisable, so we give up instead.
constexpr int DECIMATE_MIN_DIVISIONS = 4;

// Grid coordinates are packed into one key; 21 bits each covers 2M cells per
// axis, far beyond DECIMATE_START_DIVISIONS.
constexpr int DECIMATE_KEY_BITS = 21;
constexpr int64_t DECIMATE_KEY_MASK = (int64_t{1} << DECIMATE_KEY_BITS) - 1;

int64_t cellKey(int64_t x, int64_t y, int64_t z)
{
    return ((x & DECIMATE_KEY_MASK) << (2 * DECIMATE_KEY_BITS)) | ((y & DECIMATE_KEY_MASK) << DECIMATE_KEY_BITS) |
           (z & DECIMATE_KEY_MASK);
}

// Triangles are deduplicated by their sorted corner triple, so two faces that
// land on the same three welded vertices only survive once.
int64_t triangleKey(uint32_t a, uint32_t b, uint32_t c)
{
    uint32_t lo = a;
    uint32_t mid = b;
    uint32_t hi = c;
    if (lo > mid) {
        std::swap(lo, mid);
    }
    if (mid > hi) {
        std::swap(mid, hi);
    }
    if (lo > mid) {
        std::swap(lo, mid);
    }
    return cellKey(lo, mid, hi);
}

struct Cluster
{
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
    uint32_t count = 0;
    uint32_t index = 0;
};

DecimatedMesh clusterAt(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                        const float origin[3], float cellSize)
{
    const auto vertexCount = static_cast<uint32_t>(vertices.size() / 3);
    const float inv = 1.0f / cellSize;

    // One cluster per occupied cell, remembering the average of its vertices so
    // the welded mesh keeps the original silhouette rather than snapping to
    // cell corners.
    std::unordered_map<int64_t, Cluster> clusters;
    std::vector<int64_t> vertexKeys(vertexCount, 0);
    for (uint32_t v = 0; v < vertexCount; v++) {
        const float px = vertices[v * 3 + 0];
        const float py = vertices[v * 3 + 1];
        const float pz = vertices[v * 3 + 2];
        const auto ix = static_cast<int64_t>(std::floor((px - origin[0]) * inv));
        const auto iy = static_cast<int64_t>(std::floor((py - origin[1]) * inv));
        const auto iz = static_cast<int64_t>(std::floor((pz - origin[2]) * inv));
        const int64_t key = cellKey(ix, iy, iz);
        vertexKeys[v] = key;

        auto& cluster = clusters[key];
        cluster.x += px;
        cluster.y += py;
        cluster.z += pz;
        cluster.count++;
    }

    DecimatedMesh result;
    result.cellSize = cellSize;
    result.vertices.reserve(clusters.size() * 3);
    uint32_t nextIndex = 0;
    for (auto& entry : clusters) {
        auto& cluster = entry.second;
        cluster.index = nextIndex++;
        const auto n = static_cast<double>(cluster.count);
        result.vertices.push_back(static_cast<float>(cluster.x / n));
        result.vertices.push_back(static_cast<float>(cluster.y / n));
        result.vertices.push_back(static_cast<float>(cluster.z / n));
    }

    std::unordered_set<int64_t> seenTriangles;
    seenTriangles.reserve(indices.size() / 3);
    result.indices.reserve(indices.size());
    for (size_t i = 0; i + 2 < indices.size(); i += 3) {
        const uint32_t v0 = indices[i + 0];
        const uint32_t v1 = indices[i + 1];
        const uint32_t v2 = indices[i + 2];
        if (v0 >= vertexCount || v1 >= vertexCount || v2 >= vertexCount) {
            continue;
        }
        const uint32_t a = clusters[vertexKeys[v0]].index;
        const uint32_t b = clusters[vertexKeys[v1]].index;
        const uint32_t c = clusters[vertexKeys[v2]].index;
        // Two corners in the same cell leave a point or a line, not a face.
        if (a == b || b == c || a == c) {
            continue;
        }
        if (!seenTriangles.insert(triangleKey(a, b, c)).second) {
            continue;
        }
        result.indices.push_back(a);
        result.indices.push_back(b);
        result.indices.push_back(c);
    }

    return result;
}

} // namespace

DecimatedMesh decimateMesh(const std::vector<float>& vertices, const std::vector<uint32_t>& indices,
                           size_t targetTriangles)
{
    DecimatedMesh unchanged;
    unchanged.vertices = vertices;
    unchanged.indices = indices;

    if (targetTriangles == 0 || vertices.size() < 9 || indices.size() < 3) {
        return unchanged;
    }
    if (indices.size() / 3 <= targetTriangles) {
        return unchanged;
    }

    float minima[3] = {vertices[0], vertices[1], vertices[2]};
    float maxima[3] = {vertices[0], vertices[1], vertices[2]};
    for (size_t i = 0; i + 2 < vertices.size(); i += 3) {
        for (int axis = 0; axis < 3; axis++) {
            minima[axis] = std::min(minima[axis], vertices[i + axis]);
            maxima[axis] = std::max(maxima[axis], vertices[i + axis]);
        }
    }

    const float extent = std::max({maxima[0] - minima[0], maxima[1] - minima[1], maxima[2] - minima[2]});
    if (!(extent > 0.0f)) {
        return unchanged;
    }

    // Start fine and coarsen: the first cell size that meets the budget keeps
    // the most detail.
    for (int divisions = DECIMATE_START_DIVISIONS; divisions >= DECIMATE_MIN_DIVISIONS; divisions /= 2) {
        const float cellSize = extent / static_cast<float>(divisions);
        if (!(cellSize > 0.0f)) {
            continue;
        }
        auto candidate = clusterAt(vertices, indices, minima, cellSize);
        if (candidate.indices.size() < 3) {
            continue;
        }
        if (candidate.indices.size() / 3 <= targetTriangles) {
            return candidate;
        }
    }

    return unchanged;
}
