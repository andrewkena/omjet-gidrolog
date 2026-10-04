#include "DepthGrid.h"

#include <QtGui/QPainter>

#include <algorithm>
#include <cmath>
#include <limits>

namespace {
constexpr double kPi = 3.14159265358979323846;
constexpr double kEarthRadiusM = 6378137.0;
}

// ---------------------------------------------------------------------------- DepthGrid

DepthGrid::DepthGrid(QObject *parent)
    : QObject(parent)
{
    _flushTimer.setInterval(500);
    _flushTimer.setSingleShot(true);
    (void) connect(&_flushTimer, &QTimer::timeout, this, &DepthGrid::_flushDirty);
}

DepthGrid::~DepthGrid()
{
    qDeleteAll(_tiles);
}

void DepthGrid::setDepthMin(double depthMin)
{
    if (!qFuzzyCompare(depthMin + 1.0, _depthMin + 1.0)) {
        _depthMin = depthMin;
        emit depthMinChanged();
        _recolorAll();
    }
}

void DepthGrid::setDepthMax(double depthMax)
{
    if (!qFuzzyCompare(depthMax + 1.0, _depthMax + 1.0)) {
        _depthMax = depthMax;
        emit depthMaxChanged();
        _recolorAll();
    }
}

void DepthGrid::clear()
{
    qDeleteAll(_tiles);
    _tiles.clear();
    _tileList.clear();
    _dirtyTiles.clear();
    _haveOrigin = false;
    _soundingCount = 0;
    _lastRegionIx = std::numeric_limits<int>::min();
    _lastRegionIy = std::numeric_limits<int>::min();
    emit tilesChanged();
    emit soundingCountChanged();
}

DepthGrid::Tile *DepthGrid::_tile(int tileX, int tileY) const
{
    return _tiles.value(_key(tileX, tileY), nullptr);
}

DepthGrid::Tile *DepthGrid::_tileForCell(int ix, int iy, bool create, int *px, int *py)
{
    const int tileX = _floorDiv(ix, kTileSize);
    const int tileY = _floorDiv(iy, kTileSize);
    *px = ix - (tileX * kTileSize);
    *py = (kTileSize - 1) - (iy - (tileY * kTileSize));  // image row 0 is the northern edge

    Tile *tile = _tile(tileX, tileY);
    if (!tile && create) {
        tile = new Tile;
        const int cells = kTileSize * kTileSize;
        tile->sum.assign(cells, 0.0f);
        tile->count.assign(cells, 0);
        tile->display.assign(cells, std::numeric_limits<float>::quiet_NaN());
        tile->image = QImage(kTileSize, kTileSize, QImage::Format_ARGB32_Premultiplied);
        tile->image.fill(Qt::transparent);
        _tiles.insert(_key(tileX, tileY), tile);

        // Top-left (north-west) corner of the tile in WGS84
        const double northM = static_cast<double>((tileY + 1) * kTileSize) * _cellSize;
        const double eastM = static_cast<double>(tileX * kTileSize) * _cellSize;
        QVariantMap entry;
        entry[QStringLiteral("tx")] = tileX;
        entry[QStringLiteral("ty")] = tileY;
        entry[QStringLiteral("lat")] = _originLat + (northM / _metersPerDegLat);
        entry[QStringLiteral("lon")] = _originLon + (eastM / _metersPerDegLon);
        _tileList.append(entry);
        emit tilesChanged();
    }
    return tile;
}

float DepthGrid::_measured(int ix, int iy) const
{
    const int tileX = _floorDiv(ix, kTileSize);
    const int tileY = _floorDiv(iy, kTileSize);
    const Tile *tile = _tile(tileX, tileY);
    if (!tile) {
        return std::numeric_limits<float>::quiet_NaN();
    }
    const int px = ix - (tileX * kTileSize);
    const int py = (kTileSize - 1) - (iy - (tileY * kTileSize));
    const int i = (py * kTileSize) + px;
    return (tile->count[i] > 0) ? (tile->sum[i] / tile->count[i]) : std::numeric_limits<float>::quiet_NaN();
}

void DepthGrid::addSounding(double lat, double lon, double depth)
{
    if (!std::isfinite(lat) || !std::isfinite(lon) || !std::isfinite(depth) || (lat == 0.0 && lon == 0.0)) {
        return;
    }

    if (!_haveOrigin) {
        _haveOrigin = true;
        _originLat = lat;
        _originLon = lon;
        _metersPerDegLat = kEarthRadiusM * kPi / 180.0;
        _metersPerDegLon = _metersPerDegLat * std::cos(lat * kPi / 180.0);
    }

    const double northM = (lat - _originLat) * _metersPerDegLat;
    const double eastM = (lon - _originLon) * _metersPerDegLon;
    const int ix = static_cast<int>(std::floor(eastM / _cellSize));
    const int iy = static_cast<int>(std::floor(northM / _cellSize));
    if (std::abs(ix) > kMaxCells || std::abs(iy) > kMaxCells) {
        return;
    }

    int px = 0;
    int py = 0;
    Tile *tile = _tileForCell(ix, iy, true, &px, &py);
    const int i = (py * kTileSize) + px;
    if (tile->count[i] < std::numeric_limits<uint16_t>::max()) {
        tile->sum[i] += static_cast<float>(depth);
        tile->count[i]++;
    }

    // Re-evaluate every cell whose interpolated value can depend on this one.
    // Consecutive soundings in the same cell only change that cell's mean, so the costly region pass is skipped.
    if (ix == _lastRegionIx && iy == _lastRegionIy) {
        tile->display[i] = tile->sum[i] / tile->count[i];
        _colorPixel(tile, px, py);
        _dirtyTiles.insert(_key(_floorDiv(ix, kTileSize), _floorDiv(iy, kTileSize)));
    } else {
        _lastRegionIx = ix;
        _lastRegionIy = iy;
        _updateRegion(ix, iy);
    }

    _soundingCount++;
    emit soundingCountChanged();

    if (!_flushTimer.isActive()) {
        _flushTimer.start();
    }
}

void DepthGrid::_updateRegion(int ix, int iy)
{
    struct Sounding {
        int     x;
        int     y;
        float   value;
    };

    const int r = _idwRadiusCells;
    const int r2 = r * r;
    const int near2 = _nearRadiusCells * _nearRadiusCells;

    // Measured cells that can influence the affected region (radius r around the new sounding)
    std::vector<Sounding> soundings;
    for (int y = iy - (2 * r); y <= iy + (2 * r); y++) {
        for (int x = ix - (2 * r); x <= ix + (2 * r); x++) {
            const float m = _measured(x, y);
            if (!std::isnan(m)) {
                soundings.push_back({ x, y, m });
            }
        }
    }

    for (int cy = iy - r; cy <= iy + r; cy++) {
        for (int cx = ix - r; cx <= ix + r; cx++) {
            if (((cx - ix) * (cx - ix)) + ((cy - iy) * (cy - iy)) > r2) {
                continue;
            }

            float value = _measured(cx, cy);
            if (std::isnan(value)) {
                // IDW (1/d^2) over soundings within r. Filled if a sounding is within the near radius,
                // or if soundings surround the cell (>= _minQuadrants sides), i.e. the cell lies
                // between neighbouring passes - never extrapolated outwards past the outermost pass.
                double weightSum = 0.0;
                double valueSum = 0.0;
                int minD2 = std::numeric_limits<int>::max();
                int quadrants = 0;
                for (const Sounding &p : soundings) {
                    const int dx = p.x - cx;
                    const int dy = p.y - cy;
                    const int d2 = (dx * dx) + (dy * dy);
                    if (d2 > r2) {
                        continue;
                    }
                    const double w = 1.0 / d2;
                    weightSum += w;
                    valueSum += w * p.value;
                    minD2 = std::min(minD2, d2);
                    quadrants |= (dx >= 0 ? 1 : 2) << (dy >= 0 ? 0 : 2);
                }
                const int quadrantCount = ((quadrants & 1) ? 1 : 0) + ((quadrants & 2) ? 1 : 0) + ((quadrants & 4) ? 1 : 0) + ((quadrants & 8) ? 1 : 0);
                if (weightSum > 0.0 && (minD2 <= near2 || quadrantCount >= _minQuadrants)) {
                    value = static_cast<float>(valueSum / weightSum);
                }
            }

            if (std::isnan(value)) {
                continue;   // nothing measured nearby / would be extrapolation
            }

            int px = 0;
            int py = 0;
            Tile *tile = _tileForCell(cx, cy, true, &px, &py);
            tile->display[(py * kTileSize) + px] = value;
            _colorPixel(tile, px, py);
            _dirtyTiles.insert(_key(_floorDiv(cx, kTileSize), _floorDiv(cy, kTileSize)));
        }
    }
}

QRgb DepthGrid::_color(float depth) const
{
    // Same gradient and quantization as the depth-colored track in FlyViewMap.qml:
    // red (<= min) -> yellow -> green -> cyan -> blue (>= max), 24 levels
    const double range = std::max(0.01, _depthMax - _depthMin);
    double t = std::clamp((depth - _depthMin) / range, 0.0, 1.0);
    t = std::round(t * (kColorLevels - 1)) / (kColorLevels - 1);

    static const double stops[5][4] = {
        { 0.00, 1, 0, 0 },
        { 0.25, 1, 1, 0 },
        { 0.50, 0, 1, 0 },
        { 0.75, 0, 1, 1 },
        { 1.00, 0, 0, 1 },
    };
    for (int i = 1; i < 5; i++) {
        if (t <= stops[i][0]) {
            const double f = (t - stops[i - 1][0]) / (stops[i][0] - stops[i - 1][0]);
            const auto c = [&](int k) { return static_cast<int>(std::lround(255.0 * (stops[i - 1][k] + (stops[i][k] - stops[i - 1][k]) * f))); };
            return qRgba(c(1), c(2), c(3), 255);
        }
    }
    return qRgba(0, 0, 255, 255);
}

void DepthGrid::_colorPixel(Tile *tile, int px, int py) const
{
    const float value = tile->display[(py * kTileSize) + px];
    tile->image.setPixel(px, py, std::isnan(value) ? qRgba(0, 0, 0, 0) : _color(value));
}

void DepthGrid::_recolorAll()
{
    for (auto it = _tiles.cbegin(); it != _tiles.cend(); ++it) {
        Tile *tile = it.value();
        for (int py = 0; py < kTileSize; py++) {
            for (int px = 0; px < kTileSize; px++) {
                _colorPixel(tile, px, py);
            }
        }
        _dirtyTiles.insert(it.key());
    }
    _flushDirty();
}

void DepthGrid::_flushDirty()
{
    const QSet<quint64> dirty = _dirtyTiles;
    _dirtyTiles.clear();
    for (const quint64 key : dirty) {
        emit tileUpdated(static_cast<int>(static_cast<qint32>(key >> 32)), static_cast<int>(static_cast<qint32>(key & 0xffffffffu)));
    }
}

QImage DepthGrid::tileImage(int tileX, int tileY) const
{
    const Tile *tile = _tile(tileX, tileY);
    return tile ? tile->image : QImage();
}

// ---------------------------------------------------------------------------- DepthGridTile

DepthGridTile::DepthGridTile(QQuickItem *parent)
    : QQuickPaintedItem(parent)
{
    setImplicitSize(DepthGrid::kTileSize, DepthGrid::kTileSize);
    setAntialiasing(false);
}

void DepthGridTile::setGrid(DepthGrid *grid)
{
    if (_grid == grid) {
        return;
    }
    if (_grid) {
        (void) disconnect(_grid, &DepthGrid::tileUpdated, this, &DepthGridTile::_tileUpdated);
    }
    _grid = grid;
    if (_grid) {
        (void) connect(_grid, &DepthGrid::tileUpdated, this, &DepthGridTile::_tileUpdated);
    }
    emit gridChanged();
    update();
}

void DepthGridTile::setTileX(int tileX)
{
    if (_tileX != tileX) {
        _tileX = tileX;
        emit tileXChanged();
        update();
    }
}

void DepthGridTile::setTileY(int tileY)
{
    if (_tileY != tileY) {
        _tileY = tileY;
        emit tileYChanged();
        update();
    }
}

void DepthGridTile::_tileUpdated(int tileX, int tileY)
{
    if (tileX == _tileX && tileY == _tileY) {
        update();
    }
}

void DepthGridTile::paint(QPainter *painter)
{
    if (!_grid) {
        return;
    }
    const QImage image = _grid->tileImage(_tileX, _tileY);
    if (!image.isNull()) {
        painter->drawImage(boundingRect(), image);
    }
}
