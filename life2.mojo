"""
A variant of the Conway's Game of Life,
which is a simple simulation of self-replicating systems.

Evolved (=vaguely cloned) by Jan Hercek at April 2026, 
from docs.modular.com/mojo/manual/get-started.

Updated with AI agent at November 2026 - the life_sdl() do not need a c-mojo-bridge
library anymore.

A cell alives on a 2D enclosed grid (=planet) and can be either alive (1) or dead (0).
If a cell is alive and has 2 or 3 alive neighbors, it stays alive in the next generation.
If a cell is dead and has exactly 3 alive neighbors, it becomes alive in the next generation.
Otherwise, the cell becomes or stays dead in the next generation.

Core Game of Life logic adapted from Modular Inc. documentation is
originally licensed under the Apache License v2.0 with LLVM Exceptions.

This file is Licensed under the GNU Affero General Public License v3.0.
Free to use, modify, and share. Any derivative work or
network-based use must remain Open Source under the AGPL.
See <https://www.gnu.org/licenses/agpl-3.0.html> for details.
"""
comptime VERSION = "1.4.0"

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
        var next_generation = List[List[UInt8]](capacity=self.rows)
        for row in range(self.rows):
            var one_row = List[UInt8](capacity=self.cols)
            var row_above = (row - 1) if row > 0 else self.rows - 1  # modulo % is slow
            var row_below = (row + 1) if row < self.rows - 1 else 0
            for col in range(self.cols):
                var col_left = (col - 1) if col > 0 else self.cols - 1
                var col_right = (col + 1) if col < self.cols - 1 else 0
                var num_neighbors = (
                    self[row_above, col_left]
                    + self[row_above, col]
                    + self[row_above, col_right]
                    + self[row, col_left]
                    + self[row, col_right]
                    + self[row_below, col_left]
                    + self[row_below, col]
                    + self[row_below, col_right] )
                var new_state: UInt8 = 0  # for new generation, default to dead
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
    var window_height: Int = 600
    var window_width: Int = 600
    var background_color: String = "black"
    var cell_color: String = "green"
    #
    from std.python import Python
    var pygame = Python.import_module("pygame")
    pygame.init()
    pygame.display.set_caption("Conway's Game of Life")
    var window = pygame.display.set_mode(Python.tuple(window_width, window_height))
    #
    var cell_fill_color = pygame.Color(cell_color)
    var background_fill_color = pygame.Color(background_color)
    var border_size: Float32 = 1
    var cell_height: Float32 = Float32(window_height) / Float32(planet.rows)
    var cell_width: Float32 = Float32(window_width) / Float32(planet.cols)
    var width: Float32 = cell_width - border_size
    var height: Float32 = cell_height - border_size
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
                    var x = Float32(col) * cell_width + border_size
                    var y = Float32(row) * cell_height + border_size
                    pygame.draw.rect(window, cell_fill_color, Python.tuple(x, y, width, height))
        pygame.display.flip()  # update the display
        time.sleep(0.1)  # comment out for benchmarking
        planet.evolve()


# C layouts from /usr/include/SDL3 (3.4.2).  SDL_Event is a union: only its first
# Uint32 is read, and the padding only has to be at least the C sizeof.
@fieldwise_init
struct SDL_FRect:
    var x: Float32
    var y: Float32
    var w: Float32
    var h: Float32


struct SDL_Event:
    var type: UInt32                   # the tag every member of the C union starts with
    var _pad: UInt32
    var rest: SIMD[DType.uint64, 16]   # sizeof(SDL_Event) is 128
    #
    def __init__(out self):
        self.type = 0
        self._pad = 0
        self.rest = 0


def life_sdl(var planet: Planet, frames: Int = 0) raises -> None:
    """SDL3 Gui version of the Game of Life.

    `frames` bounds the run (0 = forever) so it can be driven headless.
    """
    from std.ffi import OwnedDLHandle
    from std.sys.info import platform_map
    # The ABI name: the unversioned libSDL3.so is a dev symlink, dlopen may refuse it.
    var libname = platform_map["libSDL3", linux="libSDL3.so.0", macos="libSDL3.dylib"]()
    var lib = OwnedDLHandle(libname)
    # SDL3 returns C bool; std.ffi has no alias for it and UInt8 is the same class.
    var sdl_init = lib.get_function[UInt8]("SDL_Init")
    var sdl_create_window_and_renderer = lib.get_function[UInt8]("SDL_CreateWindowAndRenderer")
    var sdl_poll_event = lib.get_function[UInt8]("SDL_PollEvent")
    var sdl_set_render_draw_color = lib.get_function[UInt8]("SDL_SetRenderDrawColor")
    var sdl_render_clear = lib.get_function[UInt8]("SDL_RenderClear")
    var sdl_render_fill_rect = lib.get_function[UInt8]("SDL_RenderFillRect")
    var sdl_render_present = lib.get_function[UInt8]("SDL_RenderPresent")
    var sdl_destroy_renderer = lib.get_function[UInt32]("SDL_DestroyRenderer")
    var sdl_destroy_window = lib.get_function[UInt32]("SDL_DestroyWindow")
    var sdl_quit = lib.get_function[UInt32]("SDL_Quit")
    var window_width: Int32 = 600
    var window_height: Int32 = 600
    var gap: Float32 = 1.0  # 1 pixel gap
    var box_w = (Float32(window_width) - gap * (Float32(planet.cols) + 1)) / Float32(planet.cols)
    var box_h = (Float32(window_height) - gap * (Float32(planet.rows) + 1)) / Float32(planet.rows)
    # SDL_INIT_VIDEO implies SDL_INIT_EVENTS
    if sdl_init(UInt32(0x20 | 0x4000)) == 0:
        raise Error("SDL_Init failed: no display? (xvfb-run, or SDL_VIDEODRIVER=dummy)")
    var window: UInt64 = 0  # SDL_Window*, out
    var renderer: UInt64 = 0  # SDL_Renderer*, out
    var title = String(planet.rows) + "x" + String(planet.cols) + " Mojo Life"
    if sdl_create_window_and_renderer(
        title.as_c_string_span(),
        window_width,
        window_height,
        UInt64(0),  # SDL_WindowFlags
        Pointer(to=window),
        Pointer(to=renderer),
    ) == 0:
        _ = sdl_quit()
        raise Error("SDL_CreateWindowAndRenderer failed")
    var event = SDL_Event()
    var generation: Int = 0
    var quit_now = False
    while True:
        while sdl_poll_event(Pointer(to=event)) != 0:
            if event.type == 0x300 or event.type == 0x100:  # KEY_DOWN, QUIT
                quit_now = True
                break
        if quit_now:
            break  # told to stop: do not draw another frame
        _ = sdl_set_render_draw_color(renderer, UInt8(0), UInt8(0), UInt8(0), UInt8(255))
        _ = sdl_render_clear(renderer)
        _ = sdl_set_render_draw_color(renderer, UInt8(0), UInt8(255), UInt8(0), UInt8(255))
        for r in range(planet.rows):
            for c in range(planet.cols):
                if planet[r, c]:
                    var rect = SDL_FRect(
                        gap + Float32(c) * (box_w + gap),
                        gap + Float32(r) * (box_h + gap),
                        box_w,
                        box_h,
                    )
                    _ = sdl_render_fill_rect(renderer, Pointer(to=rect))
        _ = sdl_render_present(renderer)
        generation += 1
        if frames > 0 and generation >= frames:
            break
        time.sleep(0.1)  # comment out for benchmarking
        planet.evolve()
    _ = sdl_destroy_renderer(renderer)
    _ = sdl_destroy_window(window)
    _ = sdl_quit()


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
    #
    if len(argv()) < 4 or String(argv()[1]) not in ("cli", "tui", "gui", "sdl", "evolve"):
        print("Usage: mojo life.mojo cli|tui|gui|sdl|evolve rows cols [frames for sdl]")
        return
    var planet = Planet.random(Int(argv()[2]), Int(argv()[3]))
    var frames = Int(argv()[4]) if len(argv()) > 4 else 0
    if   argv()[1] == "cli":    life_cli(planet^)
    elif argv()[1] == "tui":    life_tui(planet^)
    elif argv()[1] == "gui":    life_gui(planet^)
    elif argv()[1] == "sdl":    life_sdl(planet^, frames)
    elif argv()[1] == "evolve": life_evolve(planet^)

