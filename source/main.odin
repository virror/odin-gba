package main

import "core:math"
import "core:fmt"
import sdl "vendor:sdl2"
import sdlttf "vendor:sdl2/ttf"

WIN_WIDTH :: 240
WIN_HEIGHT :: 160

START_BIOS :: true
ROM_PATH :: "tests/armwrestler.gba"

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
    sdl.Init(sdl.INIT_VIDEO | sdl.INIT_GAMECONTROLLER | sdl.INIT_AUDIO)
    defer sdl.Quit()

    sdlttf.Init()
    defer sdlttf.Quit()
    
    init_controller()

    window = sdl.CreateWindow("odin-gba", 100, 100, WIN_WIDTH, WIN_HEIGHT,
        sdl.WINDOW_OPENGL)
    assert(window != nil, "Failed to create main window")
    defer sdl.DestroyWindow(window)
    render_init(window)
    defer render_delete()

    debug_window := sdl.CreateWindow("debug", 800, 100, 600, 600,
        sdl.WINDOW_OPENGL | sdl.WINDOW_RESIZABLE)
    assert(debug_window != nil, "Failed to create debug window")
    defer sdl.DestroyWindow(debug_window)
    debug_render = sdl.CreateRenderer(debug_window, -1, sdl.RENDERER_ACCELERATED)
    defer sdl.DestroyRenderer(debug_render)

    // Audio stuff
    desired: sdl.AudioSpec
    obtained: sdl.AudioSpec

    desired.freq = 48000
    desired.format = sdl.AUDIO_F32
    desired.channels = 1
    desired.samples = 64
    desired.callback = nil//audio_handler

    device := sdl.OpenAudioDevice(
        nil,
        false,
        &desired,
        &obtained,
        false,
    )
    defer sdl.CloseAudioDevice(device)

    assert(device != 0, "Failed to create audio device") // TODO: Handle error

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

    when !START_BIOS {
        cpu_init_no_bios()
    }

    bus_load_rom(ROM_PATH)

    cycles_since_last_sample: u32
    accumulated_time := 0.0
    prev_time := sdl.GetTicks()
    frame_cnt := 0.0
    step_length := 1.0 / 60.0

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
            /*quadricycle_fragments += cycles;
            apu.advance(quadricycle_fragments / 4);
            quadricycle_fragments &= 3;

            if (cycles_since_last_sample >= cycles_per_sample) {
                cycles_since_last_sample -= cycles_per_sample;
                float out = apu.output();
                buffer_push_back(out);
            }*/

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
                line := fmt.caprintf("%.1ffps", frames)  //(title + " - " + frames + "fps"))
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
        case sdl.EventType.WINDOWEVENT:
            if(event.window.event == sdl.WindowEventID.CLOSE) {
                quit = true
                bus_save_ram()
            }
            break
        case sdl.EventType.KEYDOWN:
            handle_keys_down(event.key.keysym.sym)
            break
        case sdl.EventType.CONTROLLERBUTTONDOWN:
            //handle_controller_down(event.cbutton.button)
            break
        case sdl.EventType.KEYUP:
            handle_keys_up(event.key.keysym.sym)
            break
        case sdl.EventType.CONTROLLERBUTTONUP:
            //handle_controller_up(event.cbutton.button)
            break
        }
    }
}

handle_keys_down :: proc(keycode: sdl.Keycode) {
    #partial switch(keycode) {
    case sdl.Keycode.SPACE:
        last_pause = pause
        pause = !pause
        break
    case sdl.Keycode.s:
        step = true
        break
    case sdl.Keycode.p:
        //dump_mem()
        break
    case sdl.Keycode.DOWN:
    //case sdl.GameControllerButton.DPAD_DOWN:
        input_set_key(Keys.DOWN)
        break
    case sdl.Keycode.UP:
    //case sdl.GameControllerButton.DPAD_UP:
        input_set_key(Keys.UP)
        break
    case sdl.Keycode.LEFT:
    //case sdl.GameControllerButton.DPAD_LEFT:
        input_set_key(Keys.LEFT)
        break
    case sdl.Keycode.RIGHT:
    //case sdl.GameControllerButton.DPAD_RIGHT:
        input_set_key(Keys.RIGHT)
        break
    case sdl.Keycode.q:
    //case sdl.GameControllerButton.BACK:
        input_set_key(Keys.SELECT)
        break
    case sdl.Keycode.w:
    //case sdl.GameControllerButton.START:
        input_set_key(Keys.START)
        break
    case sdl.Keycode.z:
    //case sdl.GameControllerButton.A:
        input_set_key(Keys.A)
        break
    case sdl.Keycode.x:
    //case sdl.GameControllerButton.B:
        input_set_key(Keys.B)
        break
    case sdl.Keycode.c:
    //case sdl.GameControllerButton.LEFTSHOULDER:
        input_set_key(Keys.L)
        break
    case sdl.Keycode.v:
    //case sdl.GameControllerButton.RIGHTSHOULDER:
        input_set_key(Keys.R)
        break
    }
}

handle_keys_up :: proc(keycode: sdl.Keycode) {
    #partial switch(keycode) {
    case sdl.Keycode.DOWN:
    //case sdl.GameControllerButton.DPAD_DOWN:
        input_clear_key(Keys.DOWN)
        break
    case sdl.Keycode.UP:
    //case sdl.GameControllerButton.DPAD_UP:
        input_clear_key(Keys.UP)
        break
    case sdl.Keycode.LEFT:
    //case sdl.GameControllerButton.DPAD_LEFT:
        input_clear_key(Keys.LEFT)
        break
    case sdl.Keycode.RIGHT:
    //case sdl.GameControllerButton.DPAD_RIGHT:
        input_clear_key(Keys.RIGHT)
        break
    case sdl.Keycode.q:
    //case sdl.GameControllerButton.BACK:
        input_clear_key(Keys.SELECT)
        break
    case sdl.Keycode.w:
    //case sdl.GameControllerButton.START:
        input_clear_key(Keys.START)
        break
    case sdl.Keycode.z:
    //case sdl.GameControllerButton.A:
        input_clear_key(Keys.A)
        break
    case sdl.Keycode.x:
    //case sdl.GameControllerButton.B:
        input_clear_key(Keys.B)
        break
    case sdl.Keycode.c:
    //case sdl.GameControllerButton.LEFTSHOULDER:
        input_clear_key(Keys.L)
        break
    case sdl.Keycode.v:
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
    controller: ^sdl.GameController
    for i :i32= 0; i < sdl.NumJoysticks(); i += 1 {
        if (sdl.IsGameController(i)) {
            controller = sdl.GameControllerOpen(i)
            if (controller != nil) {
                break
            }
        }
    }
}