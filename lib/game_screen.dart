import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:example_lesson1/game_over_screen.dart';
import 'package:example_lesson1/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum GameStatus { Welcome, Playing }
enum EntityType { baby, oldMan, heart }

class ExplosionEffect {
  final Offset position;
  final Color color;
  final DateTime creationTime;
  double get progress =>
      min(1.0, DateTime.now().difference(creationTime).inMilliseconds / 500.0);

  ExplosionEffect(
      {required this.position,
      required this.color,
      required this.creationTime});
}

class Angel {
  double x, y;
  double speed = 3.0;
  FallingEntity? target;
  final bool isPermanent;
  final DateTime createdAt;

  Angel({required this.x, required this.y, this.isPermanent = false})
      : createdAt = DateTime.now();

  void findTarget(List<FallingEntity> objects, Size screenSize) {
    FallingEntity? closestBaby;
    double minDistance = double.infinity;
    for (final obj in objects) {
      if (obj.type == EntityType.baby) {
        final d = (Offset(x, y) - obj.getScreenPosition(screenSize)).distance;
        if (d < minDistance) {
          minDistance = d;
          closestBaby = obj;
        }
      }
    }
    target = closestBaby;
  }

  void move(Size screenSize) {
    if (target == null) return;
    final targetPos = target!.getScreenPosition(screenSize);
    final dirX = targetPos.dx - x;
    final dirY = targetPos.dy - y;
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

class FallingEntity {
  final int id;
  final EntityType type;
  Offset position;
  Offset velocity;
  final double radius = 35.0;

  FallingEntity(
      {required this.id,
      required this.type,
      required this.position,
      required this.velocity});

  Offset getScreenPosition(Size screenSize) {
    return Offset(position.dx / 100 * screenSize.width,
        position.dy / 100 * screenSize.height);
  }

  bool contains(Offset tapPosition, Size screenSize) {
    return (getScreenPosition(screenSize) - tapPosition).distance <= radius;
  }
}

class HugeBaby {
  int id;
  Offset position;
  int health = 15;
  final double radius = 70.0;

  HugeBaby({required this.id, required this.position});

  Offset getScreenPosition(Size screenSize) {
    return Offset(position.dx / 100 * screenSize.width,
        position.dy / 100 * screenSize.height);
  }

  bool contains(Offset tapPosition, Size screenSize) {
    return (getScreenPosition(screenSize) - tapPosition).distance <= radius;
  }
}


class FloatingScore {
  final int id;
  final Offset position;
  final int value;
  final DateTime creationTime;
  double get progress =>
      min(1.0, DateTime.now().difference(creationTime).inMilliseconds / 1000.0);

  FloatingScore(
      {required this.id,
      required this.position,
      required this.value,
      required this.creationTime});
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  GameStatus _gameStatus = GameStatus.Welcome;
  int _score = 0;
  int _lives = 3;
  Difficulty _difficulty = Difficulty.medium;
  final List<FallingEntity> _entities = [];
  final List<FloatingScore> _floatingScores = [];
  HugeBaby? _hugeBaby;
  bool _isBossModeActive = false;
  Timer? _spawnTimer;
  AnimationController? _gameLoopController;
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  final List<Angel> _angels = [];
  final List<ExplosionEffect> _explosions = [];
  double get _currentSpeed => 0.1 + (_score / 10) * 0.005;

  bool _flashRed = false;
  bool _flashWhite = false;
  int _entityIdCounter = 0;
  int _scoreIdCounter = 0;

  final TextEditingController _secretCodeController = TextEditingController();

  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;

  @override
  void initState() {
    super.initState();
    _gameLoopController = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..addListener(_gameLoop);
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController!, curve: Curves.elasticIn),
    );

    _orb1Controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat(reverse: true);
    _orb2Controller = AnimationController(
        vsync: this, duration: const Duration(seconds: 15))
      ..repeat(reverse: true);
  }

  void _resetGame() {
    setState(() {
      _score = 0;
      _lives = 3;
      _entities.clear();
      _floatingScores.clear();
      _angels.clear();
      _explosions.clear();
      _flashRed = false;
      _flashWhite = false;
      _isBossModeActive = false;
      _hugeBaby = null;
    });
    _spawnTimer?.cancel();
    _gameLoopController?.stop();
  }

  void startGame(Difficulty difficulty) {
    _resetGame();
    _difficulty = difficulty;
    setState(() => _gameStatus = GameStatus.Playing);

    _startSpawning();

    final code = _secretCodeController.text.trim().toLowerCase();
    if (code == 'mark_mmvh' || code == 'game_jam_2026') {
      final size = MediaQuery.of(context).size;
      setState(() {
        _angels.add(Angel(x: size.width / 2, y: 100, isPermanent: true));
      });
    }

    _gameLoopController?.repeat();
  }

  void _startSpawning() {
    double spawnRate;
    switch (_difficulty) {
      case Difficulty.easy:
        spawnRate = 1800;
        break;
      case Difficulty.medium:
        spawnRate = 1200;
        break;
      case Difficulty.hard:
        spawnRate = 800;
        break;
    }
    _spawnTimer = Timer.periodic(
        Duration(milliseconds: spawnRate.toInt()), (_) => _spawnEntity());
  }


  void _spawnEntity() {
    if (!mounted || _gameStatus != GameStatus.Playing) return;
    final random = Random();

    double oldManChance;
    switch (_difficulty) {
      case Difficulty.easy:
        oldManChance = 0.15;
        break;
      case Difficulty.medium:
        oldManChance = 0.25;
        break;
      case Difficulty.hard:
        oldManChance = 0.40;
        break;
    }
    final isOldMan = random.nextDouble() < oldManChance;

    final entity = FallingEntity(
      id: _entityIdCounter++,
      type: isOldMan ? EntityType.oldMan : EntityType.baby,
      position: Offset(random.nextDouble() * 80 + 10, -10),
      velocity: isOldMan
          ? Offset(
              (random.nextDouble() * 0.2 - 0.1),
              (random.nextDouble() * 0.2 - 0.1))
          : Offset(0, (random.nextDouble() * 0.05)),
    );
    setState(() => _entities.add(entity));
  }

  void _gameLoop() {
    if (!mounted || _gameStatus != GameStatus.Playing) return;

    final size = MediaQuery.of(context).size;
    setState(() {
      _explosions.removeWhere((e) => e.progress >= 1.0);
      
      for (var e in _entities) {
        if (e.type == EntityType.oldMan) {
          e.position += e.velocity;
        } else {
          e.position += Offset(e.velocity.dx, e.velocity.dy + _currentSpeed);
        }

        if (e.type == EntityType.oldMan) {
          if (e.position.dx <= 0 || e.position.dx >= 100) {
            e.velocity = Offset(-e.velocity.dx, e.velocity.dy);
          }
          if (e.position.dy <= 0 || e.position.dy >= 100) {
            e.velocity = Offset(e.velocity.dx, -e.velocity.dy);
          }
          e.position = Offset(
              e.position.dx.clamp(0, 100), e.position.dy.clamp(0, 100));
        }
      }

      final missedBabies = _entities
          .where((e) => e.type == EntityType.baby && e.position.dy > 110)
          .toList();
      if (missedBabies.isNotEmpty) {
        _entities.removeWhere((e) => missedBabies.contains(e));
        _loseLives(missedBabies.length);
      }

      _floatingScores.removeWhere((s) => s.progress >= 1.0);

      final List<FallingEntity> collectedByAngels = [];
      _angels.removeWhere((angel) =>
          !angel.isPermanent &&
          DateTime.now().difference(angel.createdAt).inSeconds > 7);

      for (var angel in _angels) {
        if (angel.target == null || !_entities.contains(angel.target)) {
          angel.findTarget(_entities, size);
        }
        angel.move(size);
        if (angel.target != null) {
          final targetPos = angel.target!.getScreenPosition(size);
          final distanceToTarget =
              (Offset(angel.x, angel.y) - targetPos).distance;
          if (distanceToTarget < angel.radius + 35) {
            _score++;
            _showFloatingScore(angel.target!.position, 1);
            collectedByAngels.add(angel.target!);
            angel.target = null;
          }
        }
      }
      if (collectedByAngels.isNotEmpty) {
        _entities.removeWhere((e) => collectedByAngels.contains(e));
      }
    });
  }

  void _loseLives(int amount) {
    setState(() {
      _lives -= amount;
      _flashRed = true;
    });
    Timer(const Duration(milliseconds: 200),
        () => setState(() => _flashRed = false));
    if (_lives <= 0) {
      _endGame();
    }
  }

  void _handleTapDown(TapDownDetails details) {
    final size = MediaQuery.of(context).size;

    if(_isBossModeActive) {
      if(_hugeBaby != null && _hugeBaby!.contains(details.localPosition, size)){
        _handleHugeBabyTap();
      }
      // If in boss mode, don't interact with other entities
      return;
    }

    for (var entity in _entities.reversed) {
      if (entity.contains(details.localPosition, size)) {
        _handleEntityTap(entity);
        return;
      }
    }
  }

  void _handleHugeBabyTap() {
    setState(() {
      _hugeBaby!.health--;
    });

    if (_hugeBaby!.health <= 0) {
      _endBossMode();
    }
  }

  void _endBossMode() {
    final bossPosition = _hugeBaby?.position;
    if(bossPosition != null) {
      _triggerBossDefeatEffect(bossPosition);
    }
    setState(() {
      _isBossModeActive = false;
      _hugeBaby = null;
      _score += 50;
    });
  }

  void _triggerBossDefeatEffect(Offset position) {
    setState(() {
      _flashWhite = true;
      _explosions.add(ExplosionEffect(
          position: position,
          color: Colors.yellow,
          creationTime: DateTime.now()));
    });
    Timer(const Duration(milliseconds: 200),
        () => setState(() => _flashWhite = false));
    _showFloatingScore(position, 50);
  }

  void _handleEntityTap(FallingEntity entity) {
    if (entity.type == EntityType.heart) {
      if (_lives < 3) {
        setState(() => _lives++);
      }
      setState(() => _entities.removeWhere((e) => e.id == entity.id));
      return;
    }
    if (entity.type == EntityType.oldMan) {
      _shakeController?.forward(from: 0);
      _loseLives(3);
      return;
    }

    const points = 1;
    _showFloatingScore(entity.position, points);

    final newScore = _score + points;

    setState(() {
      _score = newScore;
      _entities.removeWhere((e) => e.id == entity.id);
    });

    if (newScore > 0 && newScore % 150 == 0) {
      _startBossMode();
    } else if (newScore > 0) {
      if (newScore % 100 == 0) {
        _spawnHealingObject();
      }
      if (newScore % 50 == 0) {
        _clearOldMen();
      }
      if (newScore % 25 == 0) {
        _spawnAngel();
      }
    }
  }
  
  void _startBossMode() {
    setState(() {
      _isBossModeActive = true;
      _hugeBaby = HugeBaby(
          id: _entityIdCounter++,
          position: const Offset(50, 50));
    });
  }

  void _spawnAngel() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      _angels.add(Angel(x: size.width / 2, y: 100));
    });
  }

  void _spawnHealingObject() {
    if (!mounted) return;
    final random = Random();
    final entity = FallingEntity(
      id: _entityIdCounter++,
      type: EntityType.heart,
      position: Offset(random.nextDouble() * 80 + 10, -10),
      velocity: Offset(0, random.nextDouble() * 0.05),
    );
    setState(() => _entities.add(entity));
  }

  void _clearOldMen() {
    if (!mounted) return;
    setState(() {
      _entities.removeWhere((e) => e.type == EntityType.oldMan);
    });
  }

  void _showFloatingScore(Offset position, int points) {
    final score = FloatingScore(
        id: _scoreIdCounter++,
        position: position,
        value: points,
        creationTime: DateTime.now());
    setState(() => _floatingScores.add(score));
  }

  void _endGame() async {
    if (_gameStatus != GameStatus.Playing) return;

    _gameStatus = GameStatus.Welcome;
    _gameLoopController?.stop();
    _spawnTimer?.cancel();

    final playAgain = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameOverScreen(score: _score, strikes: 3 - _lives),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );

    _resetGame();
    if (playAgain == true) {
      startGame(_difficulty);
    }
  }

  @override
  void dispose() {
    _gameLoopController?.dispose();
    _shakeController?.dispose();
    _spawnTimer?.cancel();
    _secretCodeController.dispose();
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation!,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation!.value, 0),
          child: child,
        );
      },
      child: Scaffold(
        body: _gameStatus == GameStatus.Welcome
            ? WelcomeScreen(
                onStartGame: startGame,
                secretCodeController: _secretCodeController)
            : _buildGameContent(),
      ),
    );
  }

  Widget _buildGameContent() {
    return Stack(
      children: [
        _buildAnimatedBackground(),
        GestureDetector(
          onTapDown: _handleTapDown,
          child: CustomPaint(
            painter: GamePainter(
                entities: _entities,
                angels: _angels,
                floatingScores: _floatingScores,
                difficulty: _difficulty,
                hugeBaby: _hugeBaby,
                explosions: _explosions),
            size: Size.infinite,
          ),
        ),
        _buildHud(),
        if (_flashRed)
          Container(
            color: Colors.red.withOpacity(0.3),
          ),
        if (_flashWhite)
          Container(
            color: Colors.white.withOpacity(0.7),
          ),
      ],
    );
  }

  Widget _buildAnimatedBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900,
            Colors.indigo.shade900,
            Colors.grey.shade900,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1.0, end: 1.2).animate(
              CurvedAnimation(parent: _orb1Controller, curve: Curves.easeInOut),
            ),
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withOpacity(0.2),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 50,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                CurvedAnimation(
                    parent: _orb2Controller, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.indigo.withOpacity(0.2),
                ),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
            child: Container(color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildHud() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.3))),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: List.generate(3, (index) {
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 300),
                        scale: index < _lives ? 1.0 : 0.5,
                        child: Icon(
                          Icons.favorite,
                          color: index < _lives
                              ? Colors.red.shade500
                              : Colors.grey.shade400,
                          size: 40,
                        ),
                      );
                    }),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(scale: animation, child: child);
                    },
                    child: Text(
                      '$_score',
                      key: ValueKey<int>(_score),
                      style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GamePainter extends CustomPainter {
  final List<FallingEntity> entities;
  final List<Angel> angels;
  final List<FloatingScore> floatingScores;
  final Difficulty difficulty;
  final HugeBaby? hugeBaby;
  final List<ExplosionEffect> explosions;

  GamePainter(
      {required this.entities,
      required this.angels,
      required this.floatingScores,
      required this.difficulty,
      this.hugeBaby,
      required this.explosions});

  @override
  void paint(Canvas canvas, Size size) {
    for (var explosion in explosions) {
      _drawExplosion(canvas, explosion, size);
    }
    
    for (var entity in entities) {
      _drawEntity(canvas, entity, size);
    }
    for (var angel in angels) {
      _drawAngel(canvas, angel);
    }
    for (var score in floatingScores) {
      _drawFloatingScore(canvas, score, size);
    }
     if (hugeBaby != null) {
      _drawHugeBaby(canvas, hugeBaby!, size);
    }
  }
  
  void _drawExplosion(Canvas canvas, ExplosionEffect explosion, Size size) {
    final screenPos = Offset(explosion.position.dx / 100 * size.width,
        explosion.position.dy / 100 * size.height);
    final progress = explosion.progress;
    final radius = progress * 200;
    final opacity = 1.0 - progress;

    final paint = Paint()
      ..color = explosion.color.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 - (progress * 10.0);

    canvas.drawCircle(screenPos, radius, paint);
  }

  void _drawHugeBaby(Canvas canvas, HugeBaby baby, Size size) {
    const emoji = '👶';
    final gradientColors = [Colors.green.shade300, Colors.green.shade500];
    final borderColor = Colors.green.shade200;
    final shadowColor = Colors.green.shade400.withOpacity(0.5);

    final screenPos = baby.getScreenPosition(size);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: gradientColors,
      ).createShader(Rect.fromCircle(center: screenPos, radius: baby.radius));
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);

    canvas.drawCircle(screenPos, baby.radius, shadowPaint);
    canvas.drawCircle(screenPos, baby.radius, paint);
    canvas.drawCircle(screenPos, baby.radius, borderPaint);

    final emojiPainter = TextPainter(
      text: const TextSpan(
        text: emoji,
        style: TextStyle(fontSize: 72),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    emojiPainter.paint(canvas,
        screenPos - Offset(emojiPainter.width / 2, emojiPainter.height / 2));
    
    final healthPainter = TextPainter(
      text: TextSpan(
        text: '${baby.health}',
        style: GoogleFonts.poppins(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    healthPainter.paint(canvas,
        screenPos - Offset(healthPainter.width / 2, healthPainter.height / 2));
  }

  void _drawEntity(Canvas canvas, FallingEntity entity, Size size) {
    String emoji;
    List<Color> gradientColors;
    Color borderColor;
    Color shadowColor;

    switch (entity.type) {
      case EntityType.baby:
        emoji = '👶';
        gradientColors = [Colors.green.shade300, Colors.green.shade500];
        borderColor = Colors.green.shade200;
        shadowColor = Colors.green.shade400.withOpacity(0.5);
        break;
      case EntityType.oldMan:
        emoji = '👴';
        gradientColors = [Colors.grey.shade400, Colors.grey.shade600];
        borderColor = Colors.grey.shade300;
        shadowColor = Colors.red.shade400.withOpacity(0.5);
        break;
      case EntityType.heart:
        emoji = '💖';
        gradientColors = [Colors.pink.shade300, Colors.red.shade400];
        borderColor = Colors.pink.shade200;
        shadowColor = Colors.red.shade400.withOpacity(0.7);
        break;
    }

    if (difficulty == Difficulty.hard &&
        (entity.type == EntityType.baby || entity.type == EntityType.oldMan)) {
      gradientColors = [Colors.orange.shade300, Colors.orange.shade500];
      borderColor = Colors.orange.shade200;
      shadowColor = Colors.orange.shade400.withOpacity(0.5);
    }

    final screenPos = entity.getScreenPosition(size);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: gradientColors,
      ).createShader(Rect.fromCircle(center: screenPos, radius: entity.radius));
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);

    canvas.drawCircle(screenPos, entity.radius, shadowPaint);
    canvas.drawCircle(screenPos, entity.radius, paint);
    canvas.drawCircle(screenPos, entity.radius, borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: 36),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas,
        screenPos - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawAngel(Canvas canvas, Angel angel) {
    final center = Offset(angel.x, angel.y);
    final paint = Paint()..color = angel.backgroundColor;
    final shadowPaint = Paint()
      ..color = angel.color.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15.0);

    canvas.drawCircle(center, angel.radius, shadowPaint);
    canvas.drawCircle(center, angel.radius, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(angel.icon.codePoint),
        style: TextStyle(
          fontSize: angel.radius,
          fontFamily: angel.icon.fontFamily,
          color: angel.color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
        canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  void _drawFloatingScore(Canvas canvas, FloatingScore score, Size size) {
    final screenPos = Offset(score.position.dx / 100 * size.width,
        score.position.dy / 100 * size.height);
    final progress = score.progress;
    final yOffset = -progress * 50;
    final opacity = 1.0 - progress;

    final textStyle = GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: Colors.white.withOpacity(opacity),
      shadows: [
        Shadow(blurRadius: 10, color: Colors.black54.withOpacity(opacity)),
      ],
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '+${score.value}',
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, screenPos.translate(0, yOffset));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
