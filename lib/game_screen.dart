import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

const int lifeValue = 1;
const int deathValue = -1;

enum GameStatus { Welcome, Playing }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  GameStatus _gameStatus = GameStatus.Welcome;
  int _score = 0;
  int _strikes = 0;
  final int _maxStrikes = 3;
  bool _isStrikeAnimationActive = false;
  final List<FallingObject> _objects = [];
  Timer? _spawnTimer;
  final Random _random = Random();
  AnimationController? _controller;
  double _speed = 2.0;
  Duration _spawnInterval = const Duration(milliseconds: 700);

  bool _isAngelActive = false;
  Angel? _angel;
  Timer? _angelTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_gameLoop);
  }

  void startGame() {
    setState(() {
      _gameStatus = GameStatus.Playing;
      _score = 0;
      _strikes = 0;
      _speed = 2.0;
      _spawnInterval = const Duration(milliseconds: 700);
      _objects.clear();
      _isAngelActive = false;
      _angel = null;
    });
    _spawnTimer?.cancel();
    _angelTimer?.cancel();
    _spawnTimer = Timer.periodic(_spawnInterval, _spawnObject);
    _controller?.forward();
  }

  void _spawnObject(Timer timer) {
    if (!mounted || _gameStatus != GameStatus.Playing) return;
    final screenWidth = MediaQuery.of(context).size.width;
    const babyRadius = 25.0;
    const elderlyRadius = 35.0;

    if (_random.nextDouble() < 0.35) {
      final minSeparation = babyRadius + elderlyRadius;
      final centerPoint = _random.nextDouble() * (screenWidth - (minSeparation * 2)) + minSeparation;
      final offset = (minSeparation / 2) + _random.nextDouble() * 20;
      double x1 = centerPoint - offset;
      double x2 = centerPoint + offset;
      final babyX = _random.nextBool() ? x1 : x2;
      final elderlyX = (babyX == x1) ? x2 : x1;

      _objects.add(FallingObject(
        x: babyX, y: -50, value: lifeValue, icon: Icons.child_friendly,
        color: Colors.green.shade800, backgroundColor: Colors.green.shade100, radius: babyRadius,
      ));
      _objects.add(FallingObject(
        x: elderlyX, y: -50, value: deathValue, icon: Icons.elderly,
        color: Colors.black, backgroundColor: Colors.grey.shade400, radius: elderlyRadius,
        horizontalSpeed: _random.nextDouble() * 2 + 2, direction: _random.nextBool() ? 1 : -1,
        verticalSpeed: _random.nextDouble() * 2 + 1,
      ));
    } else {
      final isLife = _random.nextDouble() > 0.4;
      _objects.add(FallingObject(
        x: _random.nextDouble() * screenWidth, y: -50, value: isLife ? lifeValue : deathValue,
        icon: isLife ? Icons.child_friendly : Icons.elderly,
        color: isLife ? Colors.green.shade800 : Colors.black,
        backgroundColor: isLife ? Colors.green.shade100 : Colors.grey.shade400,
        radius: isLife ? babyRadius : elderlyRadius,
        horizontalSpeed: isLife ? 0 : _random.nextDouble() * 2 + 2,
        direction: _random.nextBool() ? 1 : -1,
        verticalSpeed: isLife ? 0 : _random.nextDouble() * 2 + 1,
      ));
    }
  }

  void _gameLoop() {
    if (!mounted || _isStrikeAnimationActive || _gameStatus != GameStatus.Playing) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    setState(() {
      for (var obj in _objects) {
        if (obj.value == lifeValue) {
          obj.y += _speed;
        } else {
          obj.x += obj.horizontalSpeed * obj.direction;
          obj.y += obj.verticalSpeed * obj.verticalDirection;

          if (obj.x >= screenWidth - obj.radius) { obj.x = screenWidth - obj.radius; obj.direction *= -1; }
          else if (obj.x <= obj.radius) { obj.x = obj.radius; obj.direction *= -1; }
          if (obj.y >= screenHeight - obj.radius) { obj.y = screenHeight - obj.radius; obj.verticalDirection *= -1; }
          else if (obj.y <= obj.radius) { obj.y = obj.radius; obj.verticalDirection *= -1; }
        }
      }

      if (_isAngelActive && _angel != null) {
        if (_angel!.target == null || !_objects.contains(_angel!.target)) {
          _angel!.findTarget(_objects);
        }
        _angel!.move();
        if (_angel!.target != null) {
          final distanceToTarget = (Offset(_angel!.x, _angel!.y) - Offset(_angel!.target!.x, _angel!.target!.y)).distance;
          if (distanceToTarget < _angel!.radius + _angel!.target!.radius) {
            _score++;
            _objects.remove(_angel!.target);
            _angel!.target = null;
          }
        }
      }

      final missedBabies = _objects.where((obj) => obj.y > screenHeight + obj.radius && obj.value == lifeValue).toList();
      if (missedBabies.isNotEmpty) {
        _strikes += missedBabies.length;
        _objects.removeWhere((obj) => obj.y > screenHeight + obj.radius && obj.value == lifeValue);
        if (_strikes >= _maxStrikes) {
          _endGame();
        } else {
          _triggerStrikeAnimation();
        }
      }
    });
    _controller?.repeat();
  }

  void _handleTap(FallingObject obj) {
    if (_isStrikeAnimationActive) return;
    setState(() {
      if (obj.value == lifeValue) {
        _score++;
        _objects.remove(obj);
        if (_score > 0 && _score % 50 == 0) {
          _objects.removeWhere((o) => o.value == deathValue);
        }
        if (_score > 0 && _score % 25 == 0 && !_isAngelActive) {
          _activateAngelPowerUp();
        }
      } else if (obj.value == deathValue) {
        _objects.remove(obj);
        _endGame();
      }
    });
  }

  void _activateAngelPowerUp() {
    setState(() {
      _isAngelActive = true;
      _angel = Angel(x: MediaQuery.of(context).size.width / 2, y: 100);
    });
    _angelTimer?.cancel();
    _angelTimer = Timer(const Duration(seconds: 7), () {
      if (!mounted) return;
      setState(() {
        _isAngelActive = false;
        _angel = null;
      });
    });
  }

  void _triggerStrikeAnimation() {
    _controller?.stop();
    setState(() => _isStrikeAnimationActive = true);
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isStrikeAnimationActive = false);
      if (_strikes < _maxStrikes) {
        _controller?.forward();
      } else {
        _endGame();
      }
    });
  }

  void _endGame() {
    _controller?.stop();
    _spawnTimer?.cancel();
    _angelTimer?.cancel();
    setState(() {
      if (_objects.length > 5) {
        _objects.removeRange(5, _objects.length);
      }
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.white.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.5)),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _gameStatus = GameStatus.Welcome;
                _objects.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Game Over', style: TextStyle(fontFamily: 'Poppins', fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white,)),
                  const SizedBox(height: 16),
                  Text('Your score: $_score', style: const TextStyle(fontFamily: 'Poppins', fontSize: 22, color: Colors.white70,)),
                  const SizedBox(height: 24),
                  const Text('Tap to play again', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, color: Colors.white54,),),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _spawnTimer?.cancel();
    _angelTimer?.cancel();
    super.dispose();
  }

  Widget _buildWelcomeMenu() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.6),
            Colors.black.withOpacity(0.2),
            Colors.transparent
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Life & Death',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 60,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(blurRadius: 20.0, color: Colors.black, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Made with ❤️ by Timur Zhangulov',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      fontStyle: FontStyle.italic,
                      shadows: const [
                        Shadow(blurRadius: 10.0, color: Colors.black54, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Instructions:',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildInstructionRow(Icons.child_friendly, 'Tap on the babies to earn points.', Colors.green.shade300),
                            const SizedBox(height: 16),
                            _buildInstructionRow(Icons.warning_amber_rounded, 'Don\'t let the babies fall (3 misses and the game is over).', Colors.orange.shade300),
                            const SizedBox(height: 16),
                            _buildInstructionRow(Icons.elderly, 'Tapping on an old man is an instant loss.', Colors.red.shade300),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 10,
                      shadowColor: Colors.lightBlue.withOpacity(0.5),
                    ),
                    onPressed: startGame,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade400, Colors.purple.shade600],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        alignment: Alignment.center,
                        child: const Text(
                          'Start Game',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionRow(IconData icon, String text, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 30),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _gameStatus == GameStatus.Playing
          ? AppBar(
              title: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Score: $_score   |   Strikes: $_strikes/$_maxStrikes',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            )
          : null,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/backround_image.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            if (_gameStatus == GameStatus.Playing)
              GestureDetector(
                onTapDown: (details) {
                  if (_isStrikeAnimationActive) return;
                  for (var obj in _objects.reversed) {
                    if (obj.contains(details.localPosition)) {
                      _handleTap(obj);
                      break;
                    }
                  }
                },
                child: CustomPaint(
                  painter: GamePainter(_objects, _angel),
                  size: Size.infinite,
                ),
              ),
            if (_isStrikeAnimationActive)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Icon(Icons.close, color: Colors.red.withOpacity(0.8), size: 250),
                ),
              ),
            if (_gameStatus == GameStatus.Welcome) _buildWelcomeMenu(),
          ],
        ),
      ),
    );
  }
}

class FallingObject {
  double x, y;
  final int value;
  final IconData icon;
  final Color color, backgroundColor;
  final double radius, horizontalSpeed;
  double verticalSpeed;
  int direction, verticalDirection;

  FallingObject({
    required this.x, required this.y, required this.value, required this.icon,
    required this.color, required this.backgroundColor, required this.radius,
    this.horizontalSpeed = 0, this.direction = 1,
    this.verticalSpeed = 0, this.verticalDirection = 1,
  });

  bool contains(Offset offset) => (Offset(x, y) - offset).distance <= radius;
}

class Angel {
  double x, y;
  double speed = 5.0;
  FallingObject? target;

  Angel({required this.x, required this.y});

  void findTarget(List<FallingObject> objects) {
    FallingObject? closestBaby;
    double minDistance = double.infinity;
    for (final obj in objects) {
      if (obj.value == lifeValue) {
        final d = (Offset(x, y) - Offset(obj.x, obj.y)).distance;
        if (d < minDistance) {
          minDistance = d;
          closestBaby = obj;
        }
      }
    }
    target = closestBaby;
  }

  void move() {
    if (target == null) return;
    final dirX = target!.x - x;
    final dirY = target!.y - y;
    final dist = sqrt(dirX * dirX + dirY * dirY);
    if (dist > 1) {
      x += (dirX / dist) * speed;
      y += (dirY / dist) * speed;
    }
  }

  IconData get icon => Icons.volunteer_activism;
  Color get color => Colors.amber.shade700;
  Color get backgroundColor => Colors.white;
  double get radius => 30.0;
}

class GamePainter extends CustomPainter {
  final List<FallingObject> objects;
  final Angel? angel;

  GamePainter(this.objects, this.angel);

  @override
  void paint(Canvas canvas, Size size) {
    for (var obj in objects) {
      _drawObject(canvas, obj.backgroundColor, obj.x, obj.y, obj.radius, obj.icon, obj.color);
    }
    if (angel != null) {
      _drawObject(canvas, angel!.backgroundColor, angel!.x, angel!.y, angel!.radius, angel!.icon, angel!.color);
    }
  }

  void _drawObject(Canvas canvas, Color bgColor, double x, double y, double radius, IconData icon, Color iconColor) {
    final paint = Paint()..color = bgColor;
    final shadowPaint = Paint()..color = Colors.black.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    final iconSize = radius * 1.5;

    canvas.drawCircle(Offset(x + 2, y + 2), radius, shadowPaint);
    canvas.drawCircle(Offset(x, y), radius, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: iconSize, fontFamily: icon.fontFamily, color: iconColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
