"""
A variant of the Conway's Game of Life,
which is a simple simulation of self-replicating systems.
Evolved (=vaguely cloned) by Jan Hercek at April 2026, 
from docs.modular.com/mojo/manual/get-started.

A cell alives on a 2D enclosed grid (=planet) and can be either alive (1) or dead (0).
If a cell is alive and has 2 or 3 alive neighbors, it stays alive in the next generation.
If a cell is dead and has exactly 3 alive neighbors, it becomes alive in the next generation.
Otherwise, the cell becomes or stays dead in the next generation.

Tested (and abandoned) variants for raw speed (small 80x80 surface):
flat surface: List[UInt8] -> slower by 20%
numpy for avoid looping in life_gui() -> slower by 30%

The SIMD, MIMD (parallel CPUs) and GPU features are wonderful,
but code genereated by current AI was slower and less understandable.
Optimization has sense only for bigger surfaces.

For raw speed, we need to avoid Python interop and use 'C' FFI code.

Core Game of Life logic adapted from Modular Inc. documentation is
originally licensed under the Apache License v2.0 with LLVM Exceptions.

This file is Licensed under the GNU Affero General Public License v3.0.
Free to use, modify, and share. Any derivative work or
network-based use must remain Open Source under the AGPL.
See <https://www.gnu.org/licenses/agpl-3.0.html> for details.
"""
comptime VERSION = "1.3.1"

from std import random
from std import time
from std.sys import argv


@fieldwise_init
struct Planet(Copyable):
    var rows: Int
    var cols: Int
    var surface: List[List[UInt8]]  # one big list is slower

    def __getitem__(self, row: Int, col: Int) -> UInt8:
        return self.surface[row][col]

    def __setitem__(mut self, row: Int, col: Int, value: UInt8) -> None:
        self.surface[row][col] = value

    @staticmethod
    def random(rows: Int, cols: Int) -> Self:
        random.seed()
        var surface = List[List[UInt8]](capacity=rows)
        for _ in range(rows):
            var one_row = List[UInt8](capacity=cols)
            for _ in range(cols):
                one_row.append(UInt8(random.random_si64(0, 1)))
            surface.append(one_row^)
        return Self(rows, cols, surface^)

    def evolve(mut self) -> None:
        next_generation = List[List[UInt8]](capacity=self.rows)
        for row in range(self.rows):
            one_row = List[UInt8](capacity=self.cols)
            var row_above = (row - 1) if row > 0 else self.rows - 1  # modulo % is slow
            var row_below = (row + 1) if row < self.rows - 1 else 0
            for col in range(self.cols):
                var col_left = (col - 1) if col > 0 else self.cols - 1
                var col_right = (col + 1) if col < self.cols - 1 else 0
                num_neighbors = (
                    self[row_above, col_left]
                    + self[row_above, col]
                    + self[row_above, col_right]
                    + self[row, col_left]
                    + self[row, col_right]
                    + self[row_below, col_left]
                    + self[row_below, col]
                    + self[row_below, col_right] )
                new_state: UInt8 = 0  # for new generation, default to dead
                if self[row, col] == 1 and num_neighbors == 2:
                    new_state = 1
                elif num_neighbors == 3:
                    new_state = 1
                one_row.append(new_state)
            next_generation.append(one_row^)
        self.surface = next_generation^  # update in place, to save memory


def life_cli(var planet: Planet) raises -> None:
    """Cli version of the Game of Life."""
    while True:
        for row in range(planet.rows):
            for col in range(planet.cols):
                print('·' if planet[row,col]==0 else 'o')  # 0
            print()
        if input("'q' to quit, <enter> to continue: ") == "q":
            break
        planet.evolve()


def life_tui(var planet: Planet) raises -> None:
    """Tui version of the Game of Life."""
    # curses = Python.import_module("curses")
    # stdscr = curses.initscr()
    # -OR-
    # https://github.com/thatstoasty/mist
    # todo
    pass


def life_gui(var planet: Planet) raises -> None:
    """Gui version of the Game of Life."""
    window_height: Int = 600
    window_width: Int = 600
    background_color: String = "black"
    cell_color: String = "green"
    #
    from std.python import Python
    pygame = Python.import_module("pygame")
    pygame.init()
    pygame.display.set_caption("Conway's Game of Life")
    window = pygame.display.set_mode(Python.tuple(window_width, window_height))
    #
    cell_fill_color = pygame.Color(cell_color)
    background_fill_color = pygame.Color(background_color)
    border_size: Float32 = 1
    cell_height: Float32 = Float32(window_height) / Float32(planet.rows)
    cell_width: Float32 = Float32(window_width) / Float32(planet.cols)
    width: Float32 = cell_width - border_size
    height: Float32 = cell_height - border_size
    #
    while True:
    # for _ in range(1000):  # benchmark run for 1000 generations
        for event in pygame.event.get():  # fetch all available events
            if event.type in [pygame.QUIT, pygame.KEYDOWN]:  # event.key K_ESCAPE, K_q
                pygame.quit()
                return
        window.fill(background_fill_color)
        # draw each live cell in the grid
        for row in range(planet.rows):
            for col in range(planet.cols):
                if planet[row, col]:
                    x = Float32(col) * cell_width + border_size
                    y = Float32(row) * cell_height + border_size
                    pygame.draw.rect(window, cell_fill_color, Python.tuple(x, y, width, height))
        pygame.display.flip()  # update the display
        time.sleep(0.1)  # comment out for benchmarking
        planet.evolve()


def life_sdl(var planet: Planet) raises -> None:
    """SDL3 Gui version of the Game of Life."""
    # Fixed window dimensions
    comptime window_width: Int32 = 600
    comptime window_height: Int32 = 600
    comptime gap: Float32 = 1.0  # 1 pixel gap
    # Calculate box size to fit the window
    # Formula: (Total Width - (Total Gaps)) / Number of Boxes
    var box_w = (Float32(window_width) - (gap * (Float32(planet.cols) + 1))) / Float32(planet.cols)
    var box_h = (Float32(window_height) - (gap * (Float32(planet.rows) + 1))) / Float32(planet.rows)
    # Initialize SDL, setup window and renderer
    import libSDL as sdl
    var window = UnsafePointer[sdl.SDL_Window, MutAnyOrigin].unsafe_dangling() 
    var renderer = UnsafePointer[sdl.SDL_Renderer, MutAnyOrigin].unsafe_dangling() 
    var event = sdl.SDL_Event()
    var ptr = sdl.Pointers()  # load state variables, and .so into memory
    _ = ptr.SDL_Init(sdl.SDL_INIT_VIDEO + sdl.SDL_INIT_EVENTS)
    _ = ptr.SDL_CreateWindowAndRenderer(
        "80x80 Mojo Grid".unsafe_ptr(),
        window_width, 
        window_height, 
        0,
        UnsafePointer(to=window),
        UnsafePointer(to=renderer) )
    while True:
    # for _ in range(1000):  # benchmark run for 1000 generations
        while ptr.SDL_PollEvent(UnsafePointer(to=event)):
            if event.type == sdl.SDL_EVENT_QUIT:
                _ = ptr.SDL_DestroyWindow(window)
                return
        _ = ptr.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255)
        _ = ptr.SDL_RenderClear(renderer)
        _ = ptr.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255)
        for r in range(planet.rows):
            for c in range(planet.cols):
                if planet[r, c]:
                    var x = gap + (Float32(c) * (box_w + gap))
                    var y = gap + (Float32(r) * (box_h + gap))
                    var rect = sdl.SDL_FRect(x, y, box_w, box_h)
                    _ = ptr.SDL_RenderFillRect(renderer, UnsafePointer(to=rect))
        _ = ptr.SDL_RenderPresent(renderer)
        time.sleep(0.1)  # comment out for benchmarking
        planet.evolve()


def life_evolve(var planet: Planet) raises -> None:
    """Evolve the Game of Life without visualization."""
    for _ in range(1000):  # benchmark run for 1000 generations
        planet.evolve()


def main() raises -> None:
    # planet = Planet(8,8,[
    #     [0, 1, 0, 0, 0, 0, 0, 0],
    #     [0, 0, 1, 0, 0, 0, 0, 0],
    #     [1, 1, 1, 0, 0, 0, 0, 0],
    #     [0, 0, 0, 0, 0, 0, 0, 0],
    #     [0, 0, 0, 0, 0, 0, 0, 0],
    #     [0, 0, 0, 0, 0, 0, 0, 0],
    #     [0, 0, 0, 0, 0, 0, 0, 0],
    #     [0, 0, 0, 0, 0, 0, 0, 0],
    # ])  # a simple glider pattern, which moves diagonally across the grid

    # life_sdl(Planet.random(80, 80))  # create a random planet and run the SDL version

    if len(argv()) < 4 or String(argv()[1]) not in ("cli", "tui", "gui", "sdl", "evolve"):
        print("Usage: mojo life.mojo cli|tui|gui|sdl|evolve rows cols")
        return
    var planet = Planet.random(Int(argv()[2]), Int(argv()[3]))
    if   argv()[1] == "cli":    life_cli(planet^)
    elif argv()[1] == "tui":    life_tui(planet^)
    elif argv()[1] == "gui":    life_gui(planet^)
    elif argv()[1] == "sdl":    life_sdl(planet^)
    elif argv()[1] == "evolve": life_evolve(planet^)

