#
# 1. Create libSDL.mojo in current directory

# variant a: whole SDL linked to final program:
# python c_mojo_bridge.py -l libSDL3.so -o libSDL.mojo -m SDL3/SDL.h \
#  -e SDL3/SDL_stdinc.h SDL3/SDL_oldnames.h

# variant b: only required symbols will be fetched:
echo 'Making library libSDL.mojo ...'
python c_mojo_bridge.py -l libSDL3.so -o libSDL.mojo -m SDL3/SDL.h \
 -e SDL3/SDL_stdinc.h SDL3/SDL_oldnames.h \
 -r SDL_Window SDL_Renderer SDL_Event SDL_Init SDL_CreateWindowAndRenderer SDL_PollEvent \
    SDL_DestroyWindow SDL_SetRenderDrawColor SDL_RenderClear SDL_FRect SDL_RenderFillRect \
    SDL_RenderPresent SDL_EventType SDL_INIT_VIDEO SDL_INIT_EVENTS
#
# 2. Create & Run life.mojo (which imports freshly created libSDL.mojo)
echo 'Compiling: mojo build life.mojo ...'
mojo build life.mojo
echo 'Running: ./life sdl 80 80 ...'
./life sdl 80 80

