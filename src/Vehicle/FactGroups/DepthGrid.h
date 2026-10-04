#pragma once

// GidroLog: live depth map (Lowrance "Genesis Live" style).
// Soundings are accumulated into a regular grid (cellSize metres, local east/north frame around the
// first sounding), gaps between survey lines are filled by IDW interpolation within idwRadiusCells,
// and the result is rendered as 256x256 colored raster tiles (DepthGridTile) that are overlaid on the map.
// Colors use the same gradient and quantization as the depth-colored track.

#include <QtCore/QHash>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QTimer>
#include <QtCore/QVariantList>
#include <QtGui/QImage>
#include <QtQmlIntegration/QtQmlIntegration>
#include <QtQuick/QQuickPaintedItem>

#include <limits>
#include <memory>
#include <vector>

class DepthGrid : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Owned by the vehicle sounder fact group")

    Q_PROPERTY(double       cellSize        READ cellSize                               CONSTANT)
    Q_PROPERTY(int          tileSize        READ tileSize                               CONSTANT)
    Q_PROPERTY(double       depthMin        READ depthMin   WRITE setDepthMin           NOTIFY depthMinChanged)
    Q_PROPERTY(double       depthMax        READ depthMax   WRITE setDepthMax           NOTIFY depthMaxChanged)
    Q_PROPERTY(QVariantList tiles           READ tiles                                  NOTIFY tilesChanged)
    Q_PROPERTY(int          soundingCount   READ soundingCount                          NOTIFY soundingCountChanged)

public:
    explicit DepthGrid(QObject *parent = nullptr);
    ~DepthGrid() override;

    static constexpr int kTileSize = 256;

    double cellSize() const { return _cellSize; }
    int tileSize() const { return kTileSize; }
    double depthMin() const { return _depthMin; }
    double depthMax() const { return _depthMax; }
    void setDepthMin(double depthMin);
    void setDepthMax(double depthMax);
    QVariantList tiles() const { return _tileList; }
    int soundingCount() const { return _soundingCount; }

    /// Adds one sounding (WGS84 position, depth in metres)
    void addSounding(double lat, double lon, double depth);

    Q_INVOKABLE void clear();

    /// Tile raster for DepthGridTile (null image if the tile does not exist)
    QImage tileImage(int tileX, int tileY) const;

signals:
    void depthMinChanged();
    void depthMaxChanged();
    void tilesChanged();
    void soundingCountChanged();
    void tileUpdated(int tileX, int tileY);

private:
    struct Tile {
        std::vector<float>      sum;        // sum of depths per cell
        std::vector<uint16_t>   count;      // soundings per cell
        std::vector<float>      display;    // measured or interpolated depth, NaN = empty
        QImage                  image;
    };

    static quint64 _key(int tileX, int tileY) { return (static_cast<quint64>(static_cast<quint32>(tileX)) << 32) | static_cast<quint32>(tileY); }
    static int _floorDiv(int a, int b) { return (a >= 0) ? (a / b) : -(((-a) + b - 1) / b); }

    Tile *_tile(int tileX, int tileY) const;
    Tile *_tileForCell(int ix, int iy, bool create, int *px, int *py);
    float _measured(int ix, int iy) const;
    void _updateRegion(int ix, int iy);
    void _colorPixel(Tile *tile, int px, int py) const;
    QRgb _color(float depth) const;
    void _recolorAll();
    void _flushDirty();

    double  _cellSize = 1.0;
    int     _nearRadiusCells = 8;       // always filled this close to a sounding
    int     _idwRadiusCells = 30;       // gaps between neighbouring passes are filled up to this distance
    int     _lastRegionIx = std::numeric_limits<int>::min();   // cell of the last full region update
    int     _lastRegionIy = std::numeric_limits<int>::min();
    int     _minQuadrants = 3;          // beyond the near radius: soundings needed on >= 3 sides (no extrapolation outwards)
    double  _depthMin = 0.0;
    double  _depthMax = 10.0;
    static constexpr int kColorLevels = 24;     // same as the depth-colored track
    static constexpr int kMaxCells = 20000;     // +/- 20 km from the origin at 1 m cells

    bool    _haveOrigin = false;
    double  _originLat = 0.0;
    double  _originLon = 0.0;
    double  _metersPerDegLat = 0.0;
    double  _metersPerDegLon = 0.0;

    QHash<quint64, Tile*>   _tiles;
    QVariantList            _tileList;
    QSet<quint64>           _dirtyTiles;
    QTimer                  _flushTimer;
    int                     _soundingCount = 0;
};

/// Paints one DepthGrid tile; placed on the map by a MapQuickItem with a fixed zoomLevel
class DepthGridTile : public QQuickPaintedItem
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(DepthGrid*   grid    READ grid   WRITE setGrid   NOTIFY gridChanged)
    Q_PROPERTY(int          tileX   READ tileX  WRITE setTileX  NOTIFY tileXChanged)
    Q_PROPERTY(int          tileY   READ tileY  WRITE setTileY  NOTIFY tileYChanged)

public:
    explicit DepthGridTile(QQuickItem *parent = nullptr);

    DepthGrid *grid() const { return _grid; }
    void setGrid(DepthGrid *grid);
    int tileX() const { return _tileX; }
    void setTileX(int tileX);
    int tileY() const { return _tileY; }
    void setTileY(int tileY);

    void paint(QPainter *painter) override;

signals:
    void gridChanged();
    void tileXChanged();
    void tileYChanged();

private slots:
    void _tileUpdated(int tileX, int tileY);

private:
    DepthGrid  *_grid = nullptr;
    int         _tileX = 0;
    int         _tileY = 0;
};
