import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: ThisIsFineGame()));
}

// --- STEP 2: THE MAIN GAME LOGIC ---
class ThisIsFineGame extends StatefulWidget {
  const ThisIsFineGame({super.key});

  @override
  State<ThisIsFineGame> createState() => _ThisIsFineGameState();
}

class _ThisIsFineGameState extends State<ThisIsFineGame> {
  final GlobalKey dogKey = GlobalKey();
  
  bool hasGameStarted = false;
  bool isGameOver = false; // NEW: Track game state
  
  double panicLevel = 0.0;
  List<Offset> firePositions = [];
  Timer? gameTimer;

  List<Offset> coffeePositions = [];
  bool isCaffeinated = false; // Tracks if the bar is currently paused
  Timer? coffeeEffectTimer;   // Timer to handle the 3-second pause
  bool isCoffeeOnScreen = false;
  bool isCoffeeCooldown = false;
    
  @override
  void initState() {
    super.initState();
    //startGame();
  }

  void startGame() {
    setState(() {
      panicLevel = 0.0;
      firePositions.clear();
      coffeePositions.clear();
      isGameOver = false;
    });

    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        // ONLY increase panic if NOT caffeinated
        if (!isCaffeinated) {
          panicLevel += 0.05;
        }

        // Check for Game Over
        if (panicLevel >= 1.0) {
          timer.cancel();
          isGameOver = true;
        }

        double screenWidth = MediaQuery.of(context).size.width;
        double screenHeight = MediaQuery.of(context).size.height;

        // Define vertical constraints
        double topSafetyMargin = 60.0; // 50px + a little extra for comfort
        double bottomPanicBarHeight = 80.0; // Adjust this to match your bar's height/padding
        double playableHeight = screenHeight - topSafetyMargin - bottomPanicBarHeight;

        bool isInDogZone(Offset position) {
          final RenderBox? renderBox = dogKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox == null) return false;

          // Get the absolute position of the dog on the screen
          Offset dogPosition = renderBox.localToGlobal(Offset.zero);
          Size dogSize = renderBox.size;

          // Define the boundary (with a little extra padding)
          double padding = 20.0;
          return (position.dx > dogPosition.dx - padding &&
                  position.dx < dogPosition.dx + dogSize.width + padding &&
                  position.dy > dogPosition.dy - padding &&
                  position.dy < dogPosition.dy + dogSize.height + padding);
        }
  
        // --- FIRE SPAWNING LOGIC ---
        if (Random().nextBool()) {
          Offset newPos;
          do {
            newPos = Offset(
              Random().nextDouble() * (screenWidth - 40), // 40 is fire width padding
              topSafetyMargin + (Random().nextDouble() * playableHeight),
            );
          } while (isInDogZone(newPos));

          firePositions.add(newPos);
        }

        // --- COFFEE SPAWNING LOGIC (Merged & Safe) ---
        // Rules: 10% chance AND no coffee on screen AND no cooldown AND not currently active
        if (Random().nextInt(10) == 1 && !isCoffeeOnScreen && !isCoffeeCooldown && !isCaffeinated) {
          Offset newPos;
          do {
            newPos = Offset(
              Random().nextDouble() * (screenWidth - 40),
              topSafetyMargin + (Random().nextDouble() * playableHeight),
            );
          } while (isInDogZone(newPos));

          coffeePositions.add(newPos);
          isCoffeeOnScreen = true;
        }

      });
    });
  }

  void extinguishFire(int index) {
    if (isGameOver) return; // Don't allow clicking after death
    setState(() {
      firePositions.removeAt(index);
      panicLevel = max(0, panicLevel - 0.1);
    });
  }

  void drinkCoffee(int index) {
    setState(() {
      coffeePositions.clear(); // Remove the coffee from screen
      isCoffeeOnScreen = false;
      isCaffeinated = true;
      panicLevel = max(0, panicLevel - 0.1);
    });

    // 1. Duration of the "Rush" (3 seconds)
    Timer(const Duration(seconds: 3), () {
      setState(() {
        isCaffeinated = false;
        isCoffeeCooldown = true; // Start the 5s cooldown now
      });

      // 2. Duration of the Cooldown (5 seconds)
      Timer(const Duration(seconds: 5), () {
        setState(() {
          isCoffeeCooldown = false; // Now coffee can spawn again
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // If the game hasn't started, show the Menu Screen
    if (!hasGameStarted) {
      return Scaffold(
        backgroundColor: Colors.orange[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "THIS IS FINE:\nTHE GAME",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 40),
              const Text("🐶", style: TextStyle(fontSize: 80)),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    hasGameStarted = true;
                    startGame(); // Start the timer only when they click Play
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
                ),
                child: const Text(
                  "START ADULTING",
                  style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Tap the fires to stay 'fine'.\nLet dog drink coffee to 'chill' temporarily.",
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ELSE: Show the existing game code
    return Scaffold(
      backgroundColor: Color.lerp(Colors.orange[100], Colors.red[900], panicLevel),
      body: Stack(
        children: [
          // 1. FIRES (Now at the very back)
          if (!isGameOver)
            ...firePositions.asMap().entries.map((entry) {
              return Positioned(
                left: entry.value.dx,
                top: entry.value.dy,
                child: FireWidget(onExtinguish: () => extinguishFire(entry.key)),
              );
            }),
            //1.2. coffee powerups (also behind the dog/text)
            ...coffeePositions.asMap().entries.map((entry) {
              return Positioned(
                left: entry.value.dx,
                top: entry.value.dy,
                child: Draggable<String>(
                  data: 'coffee',
                  // What you see while dragging
                  feedback: const Text("☕", style: TextStyle(fontSize: 50, decoration: TextDecoration.none)),
                  // What stays on the ground while dragging (we make it invisible)
                  childWhenDragging: Container(),
                  // The normal coffee cup
                  child: const Text("☕", style: TextStyle(fontSize: 40)),
                ),
              );
            }),

          // 2. THE MAIN DOG/TEXT LAYER
          // Wrap the Center widget in an IgnorePointer
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 1. Title Text
                const IgnorePointer(
                  child: Text(
                    "This is fine.",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),

                // 2. The DragTarget (The Brain)
                DragTarget<String>(
                  onWillAcceptWithDetails: (details) => details.data == 'coffee',
                  onAcceptWithDetails: (details) => drinkCoffee(0),
                  builder: (context, candidateData, rejectedData) {
                    // DEFINE isHovering HERE
                    final bool isHovering = candidateData.isNotEmpty;

                    // RETURN the Stack so the Dog can see the variable
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // THE TARGET (Invisible hit area)
                        Container(
                          key: dogKey,
                          width: 120,
                          height: 120,
                          color: Colors.transparent,
                        ),

                        // THE DOG VISUAL (Now isHovering is defined!)
                        IgnorePointer(
                          child: Text(
                            isGameOver ? "💀" : "🐶",
                            style: TextStyle(
                              fontSize: 100,
                              shadows: isHovering
                                  ? [
                                      const Shadow(
                                          color: Colors.cyan,
                                          blurRadius: 30,
                                          offset: Offset(0, 0)),
                                      const Shadow(
                                          color: Colors.white, 
                                          blurRadius: 10),
                                    ]
                                  : [],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // 3. THE GAME OVER OVERLAY
          if (isGameOver)
            Container(
              color: Colors.black.withOpacity(0.8),
              width: double.infinity,
              height: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, // Centers the whole column
                children: [
                  const Text(
                    "YOU CRISPED.",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 50, 
                      fontWeight: FontWeight.w900
                    ),
                  ),
                  // This adds extra space so you can see the 💀 behind the UI
                  const SizedBox(height: 200), 
                  ElevatedButton(
                    onPressed: startGame,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    ),
                    child: const Text(
                      "TRY AGAIN", 
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        hasGameStarted = false; // Go back to menu
                        isGameOver = false;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    ),
                    child: const Text(
                      "BACK TO MENU",
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ),

          // 4. PANIC BAR (Stays at the very front)
          Positioned(
            bottom: 50,
            left: 50,
            right: 50,
            child: LinearProgressIndicator(
              value: panicLevel,
              backgroundColor: Colors.white24,
              // If caffeinated, change color to Cyan (looks like a 'buff'), otherwise Orange
              color: isCaffeinated ? Colors.cyan : Colors.orange,
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    coffeeEffectTimer?.cancel(); // NEW
    super.dispose();
  }

}

// --- STEP 1: THE FIRE WIDGET (Lifting State Up) ---
class FireWidget extends StatelessWidget {
  final VoidCallback onExtinguish;

  const FireWidget({super.key, required this.onExtinguish});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onExtinguish,
      child: const Text("🔥", style: TextStyle(fontSize: 40)),
    );
  }
}