# Game Compatability

Game Name      | Compatible           | Findings
---------------|----------------------|----------------------------------------------------------
Asteroids      | Loads                | Seems to be sped up and enters blocking loop on game-load
Alleyway       | Loads                | On game-load enters infinite loop and displays pause with no way to unpause
Boxxle II      | Loads To Boot Screen | Sits on boot screen and does not accept any more input
Brainbender    | Runs                 | Seems to be sped up, scx and scy seem to be offset from their actual position
Bubble Ghost   | Does not Run         | After Boot ROM, stays within infinite loop and never continues execution
Castelian      | Runs                 | Seems to be sped up in the Menu, as well as during gameplay (less so)
Catrap         | Runs                 | Seems sped up in main menu and music during Gameplay, otherwise fine
Centipede      | Loads                | Loads into Menu (with music being absolutely sped up and scrambled), on game-load plays one sound, loads a few tiles and then stops further meaningful execution
Cool Ball      | Runs                 | Music is sped up
Crystal Quest  | Runs                 | Music is sped up
Daedalian Opus | Runs                 | Sound contains high pitched "screeching" noise and is sped up
Dr. Mario      | Runs                 | Loads but does not output any Audio after Boot Rom and animations are sped up
Flipull        | Loads                | Loads up to game, after first input does not accept any direction buttons and does not play music
Serpent        | Loads                | Crashes after loading, reports unknown instruction E3
Tetris         | Compatible           | Runs fine