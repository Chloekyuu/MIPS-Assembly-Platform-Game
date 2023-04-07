# MIPS-Assembly-Platform-Game
Use your skills and strategy to navigate the Tyrannosaurus rex to the flg. Be careful with the enemies and obstacles, and shoot back! Use the moving platforms to reach higher ground or avoid danger.

Welcome to my final project for CSCB58!

### Introduction

---

The objective of the game is to control a Tyrannosaurus rex and reach the flag at the bottom right of the screen, while avoiding enemies and obstacles along the way.

To move the character, players can press the keys '`a`' to move left, '`d`' to move right, '`w`' to jump, '`s`' to squat down, and '`space`' to shoot enemies.

If you want to restart the game, press '`p`' at any point.

Players must try to maintain their lives throughout the game, as they start with three lives and will lose them if they come into contact with enemies or obstacles. The game includes various enemies such as cacti and mushrooms, which players must defeat by shooting at them while avoiding their attacks. Be careful not fall out of the screen!

The game includes moving platforms as well, such that players can use to reach higher ground or avoid danger.

With these elements combined, players must use their skills and strategy to navigate the game and reach the finish line. We hope you enjoy playing our platform game!

---

### Game Demo Vedio

link to youTube: [https://youtu.be/eU8JyDfJh8c](https://youtu.be/eU8JyDfJh8c)

### Instruction of Running the Game (in MARS)

---

1. Set up *Bitmap*:
    1. Find **Tools** on top menu → Click **Bitmap Display**
    2. Set both *Unit Width* and *Unit Height* to `4`
    3. Set *Display Width* to `512`
    4. Set *Display Height* to `256`
    5. Set *Base address for display* to `0x10008000 ($gp)`
    6. Click **Connect to MIPS.**
        
2. Set up *Keyboard*:
    1. Find **Tools** on top menu → Click **Keyboard and Display MMIO Simulator**
    2. Click **Connect to MIPS**.
        
3. Run the program
    1. Find **Run** on top menu → Click **Assemble**
    2. Either click **Go** under the **Run** menu or the Green Botton on the tool bar.
    3. Now you can play the game with typing input in Keyboard Simulator.

---
