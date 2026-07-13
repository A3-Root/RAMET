using System.Runtime.InteropServices;
using System.Text.Json;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.PixelFormats;
using SixLabors.ImageSharp.Processing;
using Image = SixLabors.ImageSharp.Image;
using Point = SixLabors.ImageSharp.Point;
using Rectangle = SixLabors.ImageSharp.Rectangle;

namespace MapExportExtension
{
    internal sealed class MapExportSession : IDisposable
    {
        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GetClientRect(nint hWnd, out RECT lpRect);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool ClientToScreen(nint hWnd, ref POINT lpPoint);

        [DllImport("user32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool SetCursorPos(int x, int y);

        [StructLayout(LayoutKind.Sequential)]
        private struct POINT
        {
            public int X;
            public int Y;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RECT
        {
            public int Left;
            public int Top;
            public int Right;
            public int Bottom;
        }

        private readonly PackageIndex _map;
        private readonly string _dataPath;

        // RAMET: explicit session state machine, polled by ramet.ingame.status().
        public enum ExportStatus { Idle, Running, Saving, Packing, Done, Error }
        private static volatile int _statusInt = (int)ExportStatus.Idle;
        private static string _lastError = string.Empty;
        public static ExportStatus Status => (ExportStatus)_statusInt;
        public static string LastError => _lastError;
        public static void SetStatus(ExportStatus s, string err = "")
        {
            _statusInt = (int)s;
            _lastError = err ?? string.Empty;
        }

        private double _safeZoneX;
        private double _safeZoneY;
        private double _safeZoneW;
        private double _safeZoneH;
        private int _screenX;
        private int _screenY;
        private int _screenW;
        private int _screenH;
        private int _oneW;
        private int _oneH;
        private int _oneWPx;
        private int _oneHPx;
        private bool _isHiRes;

        // RAMET: aerial orthographic imagery layer (cherry-picked from upstream v2.2.0).
        // Saved as aerial.png + index_aerial.json (PNG, not .himg) at base maxZoom+1.
        private PackageIndex? _aerialMap;
        private Image<Rgb24>? _aerialFullImage;
        private ScreenShotTileMetrics? _aerial;
        private double _adjustedWorldWidth;

        public Image<Rgba32>? FullImage { get; private set; }

        public MapExportSession(string worldName, double worldSize, object?[]? cities, string title, double? offsetX, double? offsetY)
        {
            _map = new PackageIndex()
            {
                GameName = "arma3",
                SizeInMeters = worldSize,
                MapName = worldName.ToLowerInvariant(),
                EnglishTitle = title,
                Locations = cities?.Cast<object[]>().Select(c => new PackageLocation((string)c[0], 0, (double)((object[])c[1])[0], (double)((object[])c[1])[1])).ToArray() ?? Array.Empty<PackageLocation>(),
                Images = [new PackageImage(0, 1, "base.png")],
                Culture = string.Empty,
                OriginX = -(offsetX ?? 0),
                OriginY = (offsetY ?? 0) - worldSize,
                SteamWorkshopId = Environment.GetEnvironmentVariable("A3ME_WORKSHOP_ID"),
                AppendAttribution = Environment.GetEnvironmentVariable("A3ME_WORKSHOP_AUTHOR") // Use steam workshop author as default attribution (can be edited later on GameMapStorage)
            };

            var overrideBase = Environment.GetEnvironmentVariable("RAMET_INGAME_OUTPUT_DIR");
            if (!string.IsNullOrWhiteSpace(overrideBase))
            {
                _dataPath = Path.Combine(overrideBase, _map.MapName);
            }
            else
            {
                var arma3Root = Path.GetDirectoryName(System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName)
                    ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
                _dataPath = Path.Combine(arma3Root, "RAMET_Output", "raw", _map.MapName, "a3me");
            }
            Directory.CreateDirectory(_dataPath);
            SetStatus(ExportStatus.Running);
        }

        public void Calibrate(double[] safeZone, double[] pA, double[] pB, int w, int h)
        {
            _safeZoneX = safeZone[0];
            _safeZoneY = safeZone[1];
            _safeZoneW = safeZone[2];
            _safeZoneH = safeZone[3];

            // We assume that the game window will not be moved or resized during the session, so we only get the position once at the start
            var hwnd = System.Diagnostics.Process.GetCurrentProcess().MainWindowHandle;
            GetClientRect(hwnd, out RECT clientRect);
            var origin = new POINT { X = 0, Y = 0 };
            ClientToScreen(hwnd, ref origin);
            _screenX = origin.X;
            _screenY = origin.Y;
            _screenW = clientRect.Right;
            _screenH = clientRect.Bottom;

            Extension.InfoMessage($"ScreenX={_screenX} ScreenY={_screenY} ScreenH={_screenH} ScreenW={_screenW}");

            var pxA = ArmaToScreen(pA);
            var pxB = ArmaToScreen(pB);

            _oneW = w;
            _oneH = h;
            _oneWPx = pxB.X - pxA.X;
            _oneHPx = pxA.Y - pxB.Y;

            var fullWidthInitialPx = _map.SizeInMeters * _oneWPx / w;
            var fullHeightInitialPx = _map.SizeInMeters * _oneHPx / h;
            var fullSizeInitialPx = Math.Max(fullWidthInitialPx, fullHeightInitialPx);

            if (_isHiRes)
            {
                CalibrateHiRes();
            }
            else
            {
                CalibrateInitial(fullWidthInitialPx, fullHeightInitialPx, fullSizeInitialPx);
            }
        }

        private void CalibrateInitial(double fullWidthInitialPx, double fullHeightInitialPx, double fullSizeInitialPx)
        {
            var tileSizePx = (int)Math.Ceiling(fullSizeInitialPx);

            int maxZoom = 0;
            while (tileSizePx > 400)
            {
                tileSizePx /= 2;
                maxZoom++;
            }
            tileSizePx++;

            var fullSizePx = tileSizePx * (1 << maxZoom);

            _map.TileSize = tileSizePx;
            _map.Images[0].MaxZoom = maxZoom;
            _map.DefaultZoom = Math.Max(2, maxZoom / 2);

            var adjustedWorldWidth = fullSizePx * _map.SizeInMeters / fullWidthInitialPx;
            var adjustedWorldHeight = fullSizePx * _map.SizeInMeters / fullHeightInitialPx;
            _adjustedWorldWidth = adjustedWorldWidth; // RAMET: retained for aerial tile metrics

            _map.FactorX = tileSizePx / adjustedWorldWidth;
            _map.FactorY = tileSizePx / adjustedWorldHeight;

            WriteIndexJson();

            FullImage?.Dispose();
            FullImage = new Image<Rgba32>(fullSizePx, fullSizePx, new Rgba32(221, 221, 221));
        }

        private void CalibrateHiRes()
        {
            var hiresMinZoom = _map.Images[0].MaxZoom + 1;
            var fullSizePx = _map.TileSize * (1 << hiresMinZoom);

            FullImage?.Dispose();
            FullImage = new Image<Rgba32>(fullSizePx, fullSizePx, new Rgba32(221, 221, 221));
        }

        public void HiResStart()
        {
            _isHiRes = true;
            FullImage?.Dispose();
            FullImage = null;
        }

        public void Stop()
        {
            SetStatus(ExportStatus.Saving);
            if (FullImage != null)
            {
                FullImage.SaveAsPng(Path.Combine(_dataPath, "base.png"));
                FullImage.Dispose();
                FullImage = null;
            }
        }

        public void HiResStop()
        {
            SetStatus(ExportStatus.Saving);
            if (FullImage != null)
            {
                FullImage.SaveAsPng(Path.Combine(_dataPath, "hires.png"));
                FullImage.Dispose();
                FullImage = null;

                if (!_map.Images.Any(i => i.FileName == "hires.png"))
                {
                    var hiresMinZoom = _map.Images[0].MaxZoom + 1;
                    _map.Images = [.. _map.Images, new PackageImage(hiresMinZoom, hiresMinZoom, "hires.png")];
                    WriteIndexJson();
                }
            }
        }

        // --- RAMET: aerial orthographic imagery (cherry-picked from upstream v2.2.0) ---

        public void AerialCalibrate(double tileSizeM)
        {
            var aerialMaxZoom = _map.Images[0].MaxZoom + 1; // RAMET: +1 (not upstream +2) to keep within the hires memory envelope
            var fullSizePx = _map.TileSize * (1 << aerialMaxZoom);

            _aerial = new ScreenShotTileMetrics(tileSizeM, fullSizePx, _adjustedWorldWidth);

            Extension.InfoMessage($"Aerial: {_aerial}");
            _aerialFullImage?.Dispose();
            _aerialFullImage = new Image<Rgb24>(fullSizePx, fullSizePx, new Rgb24(221, 221, 221));
        }

        public void AerialScreenShot(int x, int y, double[] pA, double[] pB, double[] pC, double[] pD)
        {
            if (_aerialFullImage == null || _aerial == null)
            {
                Extension.ErrorMessage("Invalid state: AerialCalibrate was not called");
                return;
            }

            // D -- B
            // |    |
            // A -- C
            var pxA = ArmaToScreen(pA); // SW corner
            var pxB = ArmaToScreen(pB); // NE corner
            var pxC = ArmaToScreen(pC); // SE corner
            var pxD = ArmaToScreen(pD); // NW corner

            AerialScreenShotRectified(x, y, pxA, pxB, pxC, pxD);
        }

        private void AerialScreenShotRectified(int x, int y, Point pxA, Point pxB, Point pxC, Point pxD)
        {
            if (_aerialFullImage == null || _aerial == null)
            {
                Extension.ErrorMessage("Invalid state");
                return;
            }

            // Bounding box of the screen quad for cropping
            var cropLeft = Math.Min(Math.Min(pxA.X, pxB.X), Math.Min(pxC.X, pxD.X));
            var cropTop = Math.Min(Math.Min(pxA.Y, pxB.Y), Math.Min(pxC.Y, pxD.Y));
            var cropRight = Math.Max(Math.Max(pxA.X, pxB.X), Math.Max(pxC.X, pxD.X));
            var cropBottom = Math.Max(Math.Max(pxA.Y, pxB.Y), Math.Max(pxC.Y, pxD.Y));
            var crop = new Rectangle(cropLeft, cropTop, cropRight - cropLeft, cropBottom - cropTop);

            Extension.InfoMessage($"Aerial: X={x} Y={y} Crop={crop}");

            // Quad corners expressed relative to the cropped region
            double ax = pxA.X - cropLeft, ay = pxA.Y - cropTop; // SW
            double bx = pxB.X - cropLeft, by = pxB.Y - cropTop; // NE
            double cx = pxC.X - cropLeft, cy = pxC.Y - cropTop; // SE
            double dx = pxD.X - cropLeft, dy = pxD.Y - cropTop; // NW

            var tilePx = _aerial.Pixel;

            using var rawBase = TakeScreenShot();
            rawBase.Mutate(i => i.Crop(crop));

            // Copy source pixels for random-access sampling
            var raw = (Image<Rgba32>)rawBase;
            var srcPixels = new Rgba32[raw.Width * raw.Height];
            raw.CopyPixelDataTo(srcPixels);
            var srcWidth = raw.Width;
            var srcHeight = raw.Height;

            // Inverse homography: output rectangle → source quad (for per-pixel inverse mapping)
            //   (0,0)             → D (NW)
            //   (tilePx, 0)       → B (NE)
            //   (0,      tilePx)  → A (SW)
            //   (tilePx, tilePx)  → C (SE)
            var hInv = ComputeHomography(
                0, 0, dx, dy,
                tilePx, 0, bx, by,
                0, tilePx, ax, ay,
                tilePx, tilePx, cx, cy);

            using var rectified = new Image<Rgba32>(tilePx, tilePx);
            rectified.ProcessPixelRows(accessor =>
            {
                for (int oy = 0; oy < tilePx; oy++)
                {
                    var row = accessor.GetRowSpan(oy);
                    for (int ox = 0; ox < tilePx; ox++)
                    {
                        var (sx, sy) = ProjectPoint(hInv, ox, oy);
                        var x0 = (int)Math.Floor(sx);
                        var y0 = (int)Math.Floor(sy);
                        var x1 = x0 + 1;
                        var y1 = y0 + 1;
                        if (x0 >= 0 && y0 >= 0 && x1 < srcWidth && y1 < srcHeight)
                        {
                            var fx = sx - x0;
                            var fy = sy - y0;
                            var c00 = srcPixels[y0 * srcWidth + x0];
                            var c10 = srcPixels[y0 * srcWidth + x1];
                            var c01 = srcPixels[y1 * srcWidth + x0];
                            var c11 = srcPixels[y1 * srcWidth + x1];
                            row[ox] = new Rgba32(
                                (byte)(c00.R * (1 - fx) * (1 - fy) + c10.R * fx * (1 - fy) + c01.R * (1 - fx) * fy + c11.R * fx * fy),
                                (byte)(c00.G * (1 - fx) * (1 - fy) + c10.G * fx * (1 - fy) + c01.G * (1 - fx) * fy + c11.G * fx * fy),
                                (byte)(c00.B * (1 - fx) * (1 - fy) + c10.B * fx * (1 - fy) + c01.B * (1 - fx) * fy + c11.B * fx * fy),
                                (byte)(c00.A * (1 - fx) * (1 - fy) + c10.A * fx * (1 - fy) + c01.A * (1 - fx) * fy + c11.A * fx * fy)
                            );
                        }
                        else if ((uint)x0 < (uint)srcWidth && (uint)y0 < (uint)srcHeight)
                        {
                            // Near the border: fall back to nearest-neighbor
                            row[ox] = srcPixels[y0 * srcWidth + x0];
                        }
                    }
                }
            });

            // Composite into full aerial image
            var point = _aerial.GetTileTopLeft(x, y);
            _aerialFullImage.Mutate(i => i.DrawImage(rectified, point, 1f));
        }

        public void AerialStop()
        {
            SetStatus(ExportStatus.Saving);
            if (_aerialFullImage == null)
            {
                return;
            }

            var fileName = "aerial.png";
            _aerialFullImage.SaveAsPng(Path.Combine(_dataPath, fileName));
            _aerialFullImage.Dispose();
            _aerialFullImage = null;

            var aerialMaxZoom = _map.Images[0].MaxZoom + 1;
            _aerialMap = new PackageIndex()
            {
                GameName = _map.GameName,
                SizeInMeters = _map.SizeInMeters,
                MapName = _map.MapName,
                EnglishTitle = _map.EnglishTitle,
                Locations = _map.Locations,
                Images = [new PackageImage(0, aerialMaxZoom, fileName)],
                Culture = _map.Culture,
                OriginX = _map.OriginX,
                OriginY = _map.OriginY,
                FactorX = _map.FactorX,
                FactorY = _map.FactorY,
                DefaultZoom = _map.DefaultZoom,
                TileSize = _map.TileSize,
                Type = 2, // Aerial
                SteamWorkshopId = _map.SteamWorkshopId,
                AppendAttribution = _map.AppendAttribution
            };
            WriteIndexJson("index_aerial.json", _aerialMap);
        }

        public void ScreenShot(int x, int y, double[] pA, double[] pB)
        {
            if (FullImage == null)
            {
                return;
            }

            var pxA = ArmaToScreen(pA);
            var pxB = ArmaToScreen(pB);

            var crop = new Rectangle(pxA.X, pxB.Y, _oneWPx, _oneHPx);
            var point = new Point((x / _oneW) * _oneWPx, FullImage.Height - ((y / _oneH) * _oneHPx) - _oneHPx);
            using var data = TakeScreenShot();
            data.Mutate(i => i.Crop(crop));
            FullImage.Mutate(i => i.DrawImage(data, point, 1f));
        }

        public void Pack()
        {
            SetStatus(ExportStatus.Done);
            Extension.Callback("Complete", _map.MapName);
        }

        public void Dispose()
        {
            FullImage?.Dispose();
            FullImage = null;
            _aerialFullImage?.Dispose();
            _aerialFullImage = null;
        }

        private void WriteIndexJson()
        {
            WriteIndexJson("index.json", _map);
        }

        private void WriteIndexJson(string fileName, PackageIndex packageIndex)
        {
            var json = JsonSerializer.Serialize(packageIndex, PackageIndexContext.Default.PackageIndex);
            File.WriteAllText(Path.Combine(_dataPath, fileName), json);
        }

        // --- RAMET: projective / homography helpers (from upstream v2.2.0) ---

        private static double[] BasisToPoints(double x1, double y1, double x2, double y2, double x3, double y3, double x4, double y4)
        {
            double[] m = [x1, x2, x3, y1, y2, y3, 1, 1, 1];
            double[] v = MultMV(Adj(m), [x4, y4, 1]);
            return MultMM(m, [v[0], 0, 0, 0, v[1], 0, 0, 0, v[2]]);
        }

        private static double[] Adj(double[] m) =>
        [
            m[4]*m[8]-m[5]*m[7], m[2]*m[7]-m[1]*m[8], m[1]*m[5]-m[2]*m[4],
            m[5]*m[6]-m[3]*m[8], m[0]*m[8]-m[2]*m[6], m[2]*m[3]-m[0]*m[5],
            m[3]*m[7]-m[4]*m[6], m[1]*m[6]-m[0]*m[7], m[0]*m[4]-m[1]*m[3]
        ];

        private static double[] MultMM(double[] a, double[] b)
        {
            var c = new double[9];
            for (int i = 0; i < 3; i++)
                for (int j = 0; j < 3; j++)
                {
                    double cij = 0;
                    for (int k = 0; k < 3; k++)
                        cij += a[3 * i + k] * b[3 * k + j];
                    c[3 * i + j] = cij;
                }
            return c;
        }

        private static double[] MultMV(double[] m, double[] v) =>
        [
            m[0]*v[0] + m[1]*v[1] + m[2]*v[2],
            m[3]*v[0] + m[4]*v[1] + m[5]*v[2],
            m[6]*v[0] + m[7]*v[1] + m[8]*v[2]
        ];

        // Compute the 3×3 homography matrix mapping (x1s,y1s)→(x1d,y1d) .. (x4s,y4s)→(x4d,y4d)
        private static double[] ComputeHomography(
            double x1s, double y1s, double x1d, double y1d,
            double x2s, double y2s, double x2d, double y2d,
            double x3s, double y3s, double x3d, double y3d,
            double x4s, double y4s, double x4d, double y4d)
        {
            var s = BasisToPoints(x1s, y1s, x2s, y2s, x3s, y3s, x4s, y4s);
            var d = BasisToPoints(x1d, y1d, x2d, y2d, x3d, y3d, x4d, y4d);
            var m = MultMM(d, Adj(s));
            var scale = 1.0 / m[8];
            for (int i = 0; i < 9; i++) m[i] *= scale;
            return m;
        }

        private static (double x, double y) ProjectPoint(double[] m, double x, double y)
        {
            var v = MultMV(m, [x, y, 1]);
            return (v[0] / v[2], v[1] / v[2]);
        }

        private Point ArmaToScreen(double[] point)
        {
            return new Point(
                (int)Math.Floor((point[0] - _safeZoneX) * _screenW / _safeZoneW),
                (int)Math.Ceiling((point[1] - _safeZoneY) * _screenH / _safeZoneH));
        }

        private Image TakeScreenShot()
        {
            SetCursorPos(_screenX, _screenY + _screenH - 1);
            using var bitmap = new System.Drawing.Bitmap(_screenW, _screenH);
            using (var g = System.Drawing.Graphics.FromImage(bitmap))
            {
                g.CopyFromScreen(new System.Drawing.Point(_screenX, _screenY), System.Drawing.Point.Empty, new System.Drawing.Size(_screenW, _screenH));
            }
            using var ms = new MemoryStream();
            bitmap.Save(ms, System.Drawing.Imaging.ImageFormat.Png);
            return Image.Load(ms.ToArray());
        }
    }
}
