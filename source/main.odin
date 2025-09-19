package main

import "core:math"
import "core:fmt"
import "core:path/filepath"
import sdl "vendor:sdl3"
import sdlttf "vendor:sdl3/ttf"

WIN_WIDTH :: 240
WIN_HEIGHT :: 160
WIN_SCALE :: 2

START_BIOS :: true
ROM_PATH :: "tests/brin_demo.gba"

@(private="file")
window: ^sdl.Window
debug_render: ^sdl.Renderer
quit: bool
@(private="file")
step: bool
pause := true
last_pause := true
redraw: bool
texture: ^sdl.Texture
timer0: Timer
timer1: Timer
timer2: Timer
timer3: Timer
dma0: Dma
dma1: Dma
dma2: Dma
dma3: Dma

main :: proc() {
    if(!sdl.Init(sdl.INIT_VIDEO | sdl.INIT_GAMEPAD | sdl.INIT_AUDIO)) {
        panic("Failed to init SDL3!")
    }
    defer sdl.Quit()

    if(!sdlttf.Init()) {
        panic("Failed to init sdl3 ttf!")
    }
    defer sdlttf.Quit()
    
    init_controller()

    window = sdl.CreateWindow("odin-gba", WIN_WIDTH * WIN_SCALE, WIN_HEIGHT * WIN_SCALE,
        sdl.WINDOW_OPENGL)
    assert(window != nil, "Failed to create main window")
    defer sdl.DestroyWindow(window)
    sdl.SetWindowPosition(window, 200, 200)
    render_init(window)
    defer render_delete()
    update_viewport(WIN_WIDTH * WIN_SCALE, WIN_HEIGHT * WIN_SCALE)

    debug_window: ^sdl.Window
    if(!sdl.CreateWindowAndRenderer("debug", 800, 600, sdl.WINDOW_OPENGL, &debug_window, &debug_render)) {
        panic("Failed to create debug window")
    }
    assert(debug_window != nil, "Failed to create debug window")
    defer sdl.DestroyWindow(debug_window)
    defer sdl.DestroyRenderer(debug_render)
    sdl.SetWindowPosition(debug_window, 700, 100)

    // Audio stuff
    desired: sdl.AudioSpec
    desired.freq = 48000
    desired.format = sdl.AudioFormat.F32
    desired.channels = 1
    //desired.samples = 64

    device := sdl.OpenAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, &desired, nil, nil)
    defer sdl.ClearAudioStream(device)

    assert(device != nil, "Failed to create audio device") // TODO: Handle error

    debug_init()
    defer debug_quit()

    bus_load_bios()
    cpu_init()
    tmr_init(&timer0, 0)
    tmr_init(&timer1, 1)
    tmr_init(&timer2, 2)
    tmr_init(&timer3, 3)
    dma_init(&dma0, 0)
    dma_init(&dma1, 1)
    dma_init(&dma2, 2)
    dma_init(&dma3, 3)

    when TEST_ENABLE {
        test_all()
        return
    }

    bus_load_rom(ROM_PATH)
    file_name := filepath.short_stem(ROM_PATH)
    when !START_BIOS {
        cpu_init_no_bios()
    }

    cycles_since_last_sample: u32
    cycles_per_sample :u32= 340
    accumulated_time := 0.0
    prev_time := sdl.GetTicks()
    frame_cnt := 0.0
    step_length := 1.0 / 60.0
    quadricycle_fragments: u32

    draw_debug()

    for !quit {
        time := sdl.GetTicks()
        accumulated_time += f64(time - prev_time) / 1000.0
        prev_time = time

        for (!pause || step) && !redraw && !buffer_is_full() {
            cycles := cpu_step()
            cycles_since_last_sample += cycles

            tmr_step(&timer0, cycles)
            tmr_step(&timer1, cycles)
            tmr_step(&timer2, cycles)
            tmr_step(&timer3, cycles)
            redraw = ppu_step(cycles)
            // APU uses one quarter the clock frequency
            quadricycle_fragments += cycles
            apu_advance(quadricycle_fragments / 4)
            quadricycle_fragments &= 3

            if (cycles_since_last_sample >= cycles_per_sample) {
                cycles_since_last_sample -= cycles_per_sample
                out := apu_output()
                buffer_push_back(out)
            }

            if step {
                draw_debug()
                step = false
            }
        }
        if pause != last_pause {
            draw_debug()
            last_pause = pause
        }

        handle_events()

        if (accumulated_time > step_length) {
            // Draw if its time and ppu is ready
            if redraw {
                draw_main(ppu_get_pixels(), texture)
            }
            redraw = false
            frame_cnt += accumulated_time

            if(frame_cnt > 0.25) { //Update frame counter 4 times/s
                frame_cnt = 0
                frames := math.round(1.0 / accumulated_time)
                line := fmt.caprintf("odin-gba - %s %.1ffps", file_name, frames)
                sdl.SetWindowTitle(window, line)
            }
            accumulated_time = 0
        }
    }
}

draw_main :: proc(screen_buffer: []u16, texture: ^sdl.Texture) {
    texture := texture_create(WIN_WIDTH, WIN_HEIGHT, &screen_buffer[0])
    render_screen(texture)
    texture_destroy(texture)
}

draw_debug :: proc() {
    sdl.RenderClear(debug_render)
    debug_draw()
    sdl.RenderPresent(debug_render)
}

handle_events :: proc() {
    event: sdl.Event

    for sdl.PollEvent(&event) {
        #partial switch(event.type) {
        case sdl.EventType.QUIT:
            quit = true
            bus_save_ram()
            break
        case sdl.EventType.WINDOW_CLOSE_REQUESTED:
            quit = true
            bus_save_ram()
            break
        case sdl.EventType.KEY_DOWN:
            handle_keys_down(event.key.key)
            break
        case sdl.EventType.GAMEPAD_BUTTON_DOWN:
            //handle_controller_down(event.cbutton.button)
            break
        case sdl.EventType.KEY_UP:
            handle_keys_up(event.key.key)
            break
        case sdl.EventType.GAMEPAD_BUTTON_UP:
            //handle_controller_up(event.cbutton.button)
            break
        }
    }
}

handle_keys_down :: proc(keycode: sdl.Keycode) {
    switch(keycode) {
    case sdl.K_SPACE:
        last_pause = pause
        pause = !pause
        break
    case sdl.K_S:
        step = true
        break
    case sdl.K_DOWN:
    //case sdl.GameControllerButton.DPAD_DOWN:
        input_set_key(Keys.DOWN)
        break
    case sdl.K_UP:
    //case sdl.GameControllerButton.DPAD_UP:
        input_set_key(Keys.UP)
        break
    case sdl.K_LEFT:
    //case sdl.GameControllerButton.DPAD_LEFT:
        input_set_key(Keys.LEFT)
        break
    case sdl.K_RIGHT:
    //case sdl.GameControllerButton.DPAD_RIGHT:
        input_set_key(Keys.RIGHT)
        break
    case sdl.K_Q:
    //case sdl.GameControllerButton.BACK:
        input_set_key(Keys.SELECT)
        break
    case sdl.K_W:
    //case sdl.GameControllerButton.START:
        input_set_key(Keys.START)
        break
    case sdl.K_Z:
    //case sdl.GameControllerButton.A:
        input_set_key(Keys.A)
        break
    case sdl.K_X:
    //case sdl.GameControllerButton.B:
        input_set_key(Keys.B)
        break
    case sdl.K_C:
    //case sdl.GameControllerButton.LEFTSHOULDER:
        input_set_key(Keys.L)
        break
    case sdl.K_V:
    //case sdl.GameControllerButton.RIGHTSHOULDER:
        input_set_key(Keys.R)
        break
    }
}

handle_keys_up :: proc(keycode: sdl.Keycode) {
    switch(keycode) {
    case sdl.K_DOWN:
    //case sdl.GameControllerButton.DPAD_DOWN:
        input_clear_key(Keys.DOWN)
        break
    case sdl.K_UP:
    //case sdl.GameControllerButton.DPAD_UP:
        input_clear_key(Keys.UP)
        break
    case sdl.K_LEFT:
    //case sdl.GameControllerButton.DPAD_LEFT:
        input_clear_key(Keys.LEFT)
        break
    case sdl.K_RIGHT:
    //case sdl.GameControllerButton.DPAD_RIGHT:
        input_clear_key(Keys.RIGHT)
        break
    case sdl.K_Q:
    //case sdl.GameControllerButton.BACK:
        input_clear_key(Keys.SELECT)
        break
    case sdl.K_W:
    //case sdl.GameControllerButton.START:
        input_clear_key(Keys.START)
        break
    case sdl.K_Z:
    //case sdl.GameControllerButton.A:
        input_clear_key(Keys.A)
        break
    case sdl.K_X:
    //case sdl.GameControllerButton.B:
        input_clear_key(Keys.B)
        break
    case sdl.K_C:
    //case sdl.GameControllerButton.LEFTSHOULDER:
        input_clear_key(Keys.L)
        break
    case sdl.K_V:
    //case sdl.GameControllerButton.RIGHTSHOULDER:
        input_clear_key(Keys.R)
        break
    }
}

/*audio_handler :: proc(userdata: rawptr, stream: [^]u8, len: c.int) {
    size_t nr_of_samples = len / 4;
    if (buffer_size() >= nr_of_samples) {
        auto chunk = buffer_take_front(nr_of_samples);
        for (size_t i = 0; i < nr_of_samples; ++i) {
            *((float*)stream + i) = chunk[i];
        }
    } else {
        std::fill(stream, stream + len, -1.0f);
    }
}*/

init_controller :: proc() {
    controller: ^sdl.Gamepad
    count: i32
    ids := sdl.GetGamepads(&count)
    for i in 0 ..< count {
        if (sdl.IsGamepad(ids[i])) {
            controller = sdl.OpenGamepad(ids[i])
            if (controller != nil) {
                break
            }
        }
    }
}