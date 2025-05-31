import 'package:flutter/material.dart';

import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Uint8List? coloringBookBytes; // The image shown and filled by the user
  Uint8List? regionMapBytes; // Add to your state
  Map<int, Offset> centroids = {}; // Store region centroids
  late img.Image sobelImage; // Add this
  late img.Image coloringBookImage; // The current coloring book image
  late List<List<int>> regionMap; // Region map for flood fill
  final List<img.Image> undoStack = [];
  final List<Color> palette = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.yellow,
    Colors.purple,
  ];
  Color selectedColor = Colors.red;

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  img.Image _applySobel(img.Image src) {
    final grayscale = img.grayscale(src);
    final width = grayscale.width;
    final height = grayscale.height;
    final result = img.Image(width: width, height: height);
    const threshold = 100;

    final gx = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    final gy = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        int sumX = 0, sumY = 0;
        for (int ky = 0; ky < 3; ky++) {
          for (int kx = 0; kx < 3; kx++) {
            final pixel = grayscale.getPixel(x + kx - 1, y + ky - 1);
            final luminance = img.getLuminance(pixel);
            sumX += (gx[ky][kx] * luminance).toInt();
            sumY += (gy[ky][kx] * luminance).toInt();
          }
        }
        final magnitude =
            (sqrt(
              (sumX * sumX + sumY * sumY).toDouble(),
            )).clamp(0, 255).toInt();
        final binary = magnitude > threshold ? 0 : 255;
        result.setPixelRgb(x, y, binary, binary, binary);
      }
    }
    return result;
  }

  Map<int, Offset> computeRegionCentroids(List<List<int>> regionMap) {
    final regionSums = <int, Offset>{};
    final regionCounts = <int, int>{};
    for (int y = 0; y < regionMap.length; y++) {
      for (int x = 0; x < regionMap[0].length; x++) {
        final id = regionMap[y][x];
        if (id != -1) {
          regionSums[id] =
              (regionSums[id] ?? Offset.zero) +
              Offset(x.toDouble(), y.toDouble());
          regionCounts[id] = (regionCounts[id] ?? 0) + 1;
        }
      }
    }
    final centroids = <int, Offset>{};
    regionSums.forEach((id, sum) {
      centroids[id] = sum / regionCounts[id]!.toDouble();
    });
    return centroids;
  }

  List<List<int>> _generateRegionMap(img.Image edgeImage) {
    final width = edgeImage.width;
    final height = edgeImage.height;
    final visited = List.generate(height, (_) => List.filled(width, false));
    final map = List.generate(height, (_) => List.filled(width, -1));
    int regionId = 0;

    void floodFill(int x, int y, int id) {
      final stack = <Point<int>>[Point(x, y)];
      while (stack.isNotEmpty) {
        final p = stack.removeLast();
        if (p.x < 0 || p.y < 0 || p.x >= width || p.y >= height) continue;
        if (visited[p.y][p.x]) continue;
        if (img.getLuminance(edgeImage.getPixel(p.x, p.y)) != 255) continue;
        visited[p.y][p.x] = true;
        map[p.y][p.x] = id;
        stack.addAll([
          Point(p.x + 1, p.y),
          Point(p.x - 1, p.y),
          Point(p.x, p.y + 1),
          Point(p.x, p.y - 1),
        ]);
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (!visited[y][x] &&
            img.getLuminance(edgeImage.getPixel(x, y)) == 255) {
          floodFill(x, y, regionId++);
        } else {
          visited[y][x] = true;
        }
      }
    }
    return map;
  }

  Future<void> _loadImages() async {
    final byteData = await rootBundle.load('assets/sample_one.jpg');
    final decoded = img.decodeImage(byteData.buffer.asUint8List())!;
    final sobel = _applySobel(decoded);
    sobelImage = img.Image.from(sobel); // Store the original Sobel

    coloringBookImage = img.Image.from(sobel);
    regionMap = _generateRegionMap(sobelImage);
    final fillable =
        regionMap.expand((row) => row).where((id) => id != -1).length;
    print('Fillable pixels: $fillable');
    setState(() {
      coloringBookBytes = Uint8List.fromList(img.encodePng(coloringBookImage));
      centroids = computeRegionCentroids(regionMap);
      regionMapBytes = visualizeRegionMap(regionMap); // Add this
    });
  }

  Uint8List visualizeRegionMap(List<List<int>> regionMap) {
    final height = regionMap.length;
    final width = regionMap[0].length;
    final img.Image vis = img.Image(width: width, height: height);

    // Assign a random color to each region
    final rng = Random(42);
    final regionColors = <int, List<int>>{};
    for (var row in regionMap) {
      for (var id in row) {
        if (id != -1 && !regionColors.containsKey(id)) {
          regionColors[id] = [
            rng.nextInt(256),
            rng.nextInt(256),
            rng.nextInt(256),
          ];
        }
      }
    }

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final id = regionMap[y][x];
        if (id == -1) {
          vis.setPixelRgb(x, y, 0, 0, 0); // black for edges
        } else {
          final c = regionColors[id]!;
          vis.setPixelRgb(x, y, c[0], c[1], c[2]);
        }
      }
    }
    return Uint8List.fromList(img.encodePng(vis));
  }

  Future<void> _animateFillRegion(int regionId) async {
    for (int y = 0; y < regionMap.length; y++) {
      for (int x = 0; x < regionMap[0].length; x++) {
        if (regionMap[y][x] == regionId) {
          coloringBookImage.setPixelRgb(
            x,
            y,
            selectedColor.red,
            selectedColor.green,
            selectedColor.blue,
          );
        }
      }
    }
    setState(() {
      coloringBookBytes = Uint8List.fromList(img.encodePng(coloringBookImage));
    });
  }

  // Future<void> _animateFillRegion(int regionId) async {
  //   final pixels = <Point<int>>[];
  //   for (int y = 0; y < regionMap.length; y++) {
  //     for (int x = 0; x < regionMap[0].length; x++) {
  //       if (regionMap[y][x] == regionId) {
  //         pixels.add(Point(x, y));
  //       }
  //     }
  //   }

  //   pixels.shuffle();

  //   const batchSize = 5000; // Much larger batch for less flicker
  //   for (int i = 0; i < pixels.length; i += batchSize) {
  //     final batch = pixels.skip(i).take(batchSize);
  //     for (final p in batch) {
  //       coloringBookImage.setPixelRgb(
  //         p.x,
  //         p.y,
  //         selectedColor.red,
  //         selectedColor.green,
  //         selectedColor.blue,
  //       );
  //     }
  //     setState(() {
  //       coloringBookBytes = Uint8List.fromList(
  //         img.encodePng(coloringBookImage),
  //       );
  //     });
  //     await Future.delayed(const Duration(milliseconds: 30));
  //   }
  //   // Ensure the last update is always shown
  //   setState(() {
  //     coloringBookBytes = Uint8List.fromList(img.encodePng(coloringBookImage));
  //   });
  // }

  // ... _applySobel and _generateRegionMap stay the same ...
  void _handleTap(LongPressStartDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx;
    final dy = details.localPosition.dy;
    final imgX = dx.toInt();
    final imgY = dy.toInt();
    if (imgX < 0 ||
        imgY < 0 ||
        imgX >= coloringBookImage.width ||
        imgY >= coloringBookImage.height)
      return;
    final regionId = regionMap[imgY][imgX];
    if (regionId == -1) return;

    undoStack.add(img.Image.from(coloringBookImage));
    _animateFillRegion(regionId); // Only animate!
  }

  void _undo() {
    if (undoStack.isNotEmpty) {
      setState(() {
        coloringBookImage = undoStack.removeLast();
        coloringBookBytes = Uint8List.fromList(
          img.encodePng(coloringBookImage),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child:
              coloringBookBytes == null
                  ? const CircularProgressIndicator()
                  : SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final scaleX =
                                constraints.maxWidth / coloringBookImage.width;
                            final scaleY =
                                constraints.maxHeight /
                                coloringBookImage.height;
                            return InteractiveViewer(
                              minScale: 1.0,
                              maxScale: 8.0,
                              child: GestureDetector(
                                onLongPressStart:
                                    (details) =>
                                        _handleTap(details, constraints),
                                child: Stack(
                                  children: [
                                    Image.memory(
                                      coloringBookBytes!,
                                      width: coloringBookImage.width.toDouble(),
                                      height:
                                          coloringBookImage.height.toDouble(),
                                      fit: BoxFit.fill,
                                    ),
                                    ...centroids.entries.map((entry) {
                                      final id = entry.key;
                                      final offset = entry.value;
                                      return Positioned(
                                        left: offset.dx * scaleX - 8,
                                        top: offset.dy * scaleY - 8,
                                        child: Container(
                                          color: Colors.white.withOpacity(0.7),
                                          padding: const EdgeInsets.all(2),
                                          child: Text(
                                            '$id',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _undo,
                                child: const Text("Undo"),
                              ),
                              Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children:
                                    palette.map((color) {
                                      return GestureDetector(
                                        onTap:
                                            () => setState(
                                              () => selectedColor = color,
                                            ),
                                        child: Container(
                                          margin: const EdgeInsets.all(4),
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color:
                                                  selectedColor == color
                                                      ? Colors.black
                                                      : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        Image.asset('assets/sample_one.jpg'),
                        if (regionMapBytes != null) ...[
                          const SizedBox(height: 20),
                          Image.memory(regionMapBytes!),
                        ],
                      ],
                    ),
                  ),
        ),
      ),
    );
  }
}
