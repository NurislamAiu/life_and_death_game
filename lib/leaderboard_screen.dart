import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:example_lesson1/welcome_screen.dart'; // Added import for Difficulty enum

class ScoreEntry {
  final String name;
  final int score;
  final DateTime date;

  ScoreEntry({required this.name, required this.score, required this.date});

  Map<String, dynamic> toJson() => {
        'name': name,
        'score': score,
        'date': date.toIso8601String(),
      };

  factory ScoreEntry.fromJson(Map<String, dynamic> json) => ScoreEntry(
        name: json['name'] as String,
        score: json['score'] as int,
        date: DateTime.parse(json['date'] as String),
      );
}

class LeaderboardScreen extends StatefulWidget {
  final Difficulty difficulty;

  const LeaderboardScreen({super.key, required this.difficulty});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> with TickerProviderStateMixin {
  List<ScoreEntry> _highScores = [];
  bool _isLoading = true;

  late AnimationController _orb1Controller;
  late AnimationController _orb2Controller;

  @override
  void initState() {
    super.initState();
    _loadHighScores();

    _orb1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    _orb2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat(reverse: true);
  }

  Future<void> _loadHighScores() async {
    final prefs = await SharedPreferences.getInstance();
    // Use difficulty-specific key
    final scoresJson = prefs.getStringList('highScores_${widget.difficulty.name}') ?? [];
    setState(() {
      _highScores = scoresJson
          .map((jsonString) => ScoreEntry.fromJson(Map<String, dynamic>.from(json.decode(jsonString))))
          .toList();
      _highScores.sort((a, b) => b.score.compareTo(a.score)); // Sort descending
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _orb1Controller.dispose();
    _orb2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          _buildContent(context),
        ],
      ),
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
                CurvedAnimation(parent: _orb2Controller, curve: Curves.easeInOut),
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

  Widget _buildContent(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${widget.difficulty.name.toUpperCase()} Leaderboard', // Dynamic title
              style: GoogleFonts.cinzel(
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : _buildHighScoresList(),
            const SizedBox(height: 40),
            _buildBackButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHighScoresList() {
    if (_highScores.isEmpty) {
      return Text(
        'No scores yet! Play a game to set one.',
        style: GoogleFonts.poppins(
          fontSize: 18,
          color: Colors.white70,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: min(_highScores.length, 10), // Display top 10
            itemBuilder: (context, index) {
              final entry = _highScores[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                    Text(
                      entry.score.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.yellow.shade400,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        elevation: 12,
        shadowColor: Colors.blue.withOpacity(0.5),
      ),
      onPressed: () => Navigator.of(context).pop(),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF42A5F5), Color(0xFF1976D2)], // Blue gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          alignment: Alignment.center,
          child: Text(
            'Back to Menu',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
