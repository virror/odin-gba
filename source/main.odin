package main

import "core:math"
import "core:fmt"
import "base:runtime"
import sdl "vendor:sdl3"
import sdlttf "vendor:sdl3/ttf"
import "../../odin-libs/emu"

WIN_WIDTH :: 240
WIN_HEIGHT :: 160
WIN_SCALE :: 2

DEBUG :: false
START_BIOS :: false

@(private="file")
window: ^sdl.Window
debug_render: ^sdl.Renderer
quit: bool
@(private="file")
step: bool
@(private="file")
pause := true
texture: ^sdl.Texture
timer0: Timer
timer1: Timer
timer2: Timer
timer3: Timer
dma0: Dma
dma1: Dma
dma2: Dma
dma3: Dma
audio_stream: ^sdl.AudioStream
file_name: string
@(private="file")
pause_btn: ^emu.Ui_element
@(private="file")
load_btn: ^emu.Ui_element
@(private="file")
resume_btn: ^emu.Ui_element
@(private="file")
filter: sdl.DialogFileFilter = {name = "GBA rom", pattern = "gba"}
@(private="file")
resolution: emu.Vector2f

main :: proc() {
    if(!sdl.Init(sdl.INIT_VIDEO | sdl.INIT_GAMEPAD | sdl.INIT_AUDIO)) {
        panic("Failed to init SDL3!")
    }
    defer sdl.Quit()
    
    init_controller()

    resolution = {WIN_WIDTH * WIN_SCALE, WIN_HEIGHT * WIN_SCALE}
    window = sdl.CreateWindow("odin-gba", i32(resolution.x), i32(resolution.y),
        sdl.WINDOW_VULKAN)
    assert(window != nil, "Failed to create main window")
    defer sdl.DestroyWindow(window)
    sdl.SetWindowPosition(window, 200, 200)
    emu.render_init(window)
    defer emu.render_deinit()
    emu.render_update_viewport(i32(resolution.x), i32(resolution.y))

    when(DEBUG) {
        if(!sdlttf.Init()) {
            panic("Failed to init sdl3 ttf!")
        }
        defer sdlttf.Quit()

        debug_window: ^sdl.Window
        if(!sdl.CreateWindowAndRenderer("debug", 800, 600, sdl.WINDOW_VULKAN, &debug_window, &debug_render)) {
            panic("Failed to create debug window")
        }
        assert(debug_window != nil, "Failed to create debug window")
        defer sdl.DestroyWindow(debug_window)
        defer sdl.DestroyRenderer(debug_render)
        sdl.SetWindowPosition(debug_window, 700, 100)

        debug_init()
        defer debug_quit()
    }
    // Audio stuff
    desired: sdl.AudioSpec
    desired.freq = 48000
    desired.format = sdl.AudioFormat.F32
    desired.channels = 1

    audio_stream = sdl.OpenAudioDeviceStream(sdl.AUDIO_DEVICE_DEFAULT_PLAYBACK, &desired, audio_handler, nil)
    defer sdl.ClearAudioStream(audio_stream)

    assert(audio_stream != nil, "Failed to create audio device") // TODO: Handle error

    bus_load_bios()
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

    emu.ui_sprite_create_all()
    create_ui()

    cycles_since_last_sample: u32
    cycles_per_sample :u32= 340
    accumulated_time := 0.0
    prev_time := sdl.GetTicks()
    frame_cnt := 0.0
    step_length := 1.0 / 60.0
    quadricycle_fragments: u32
    redraw: bool

    draw_debug()

    for !quit {
        time := sdl.GetTicks()
        accumulated_time += f64(time - prev_time) / 1000.0
        prev_time = time

        if((!pause || step) && !redraw && !buffer_is_full()) {
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

            if(cycles_since_last_sample >= cycles_per_sample) {
                cycles_since_last_sample -= cycles_per_sample
                /*out := apu_output()
                buffer_push_back(out)*/
            }

            if(step) {
                draw_debug()
                step = false
            }
        }

        if(accumulated_time > step_length) {
            // Draw if its time and ppu is ready
            handle_events()
            emu.ui_process()
            emu.render_pre()
            emu.render_set_shader()
            if(redraw || pause) {
                n := emu.texture_create(WIN_WIDTH, WIN_HEIGHT, &ppu_get_pixels()[0], 2)
                emu.render_quad({
                    texture = n,
                    position = {-resolution.x / 2, -resolution.y / 2},
                    size = {resolution.x, resolution.y},
                    scale = 1,
                    offset = {0, 0},
                    flip = {0, 0},
                    color = {1, 1, 1, 1},
                })
                emu.texture_destroy(n)
                redraw = false
            }
            emu.ui_render()
            emu.render_post()

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

draw_debug :: proc() {
    sdl.RenderClear(debug_render)
    debug_draw()
    sdl.RenderPresent(debug_render)
}

pause_emu :: proc(do_pause: bool) {
    pause = do_pause
    if(!pause) {
        //sdl.ResumeAudioStreamDevice(audio_stream)
    } else {
        //sdl.PauseAudioStreamDevice(audio_stream)
        draw_debug()
    }
}

handle_events :: proc() {
    emu.input_reset()
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
            handle_dbg_keys(&event)
            break
        case sdl.EventType.WINDOW_MOUSE_ENTER:
            if(!pause) {
                pause_btn.disabled = false
            }
        case sdl.EventType.WINDOW_MOUSE_LEAVE:
            pause_btn.disabled = true
            break
        }
        input_process(&event)
    }
}

@(private="file")
handle_dbg_keys :: proc(event: ^sdl.Event) {
    switch event.key.key {
    case sdl.K_S:
        step = true
    case sdl.K_ESCAPE:
        quit = true
    }
}

audio_handler :: proc "c" (userdata: rawptr, stream: ^sdl.AudioStream, additional_amount, total_amount: i32) {
    context = runtime.default_context()
    nr_of_samples := u32(total_amount / size_of(f32))
    if(buffer_size() >= nr_of_samples) {
        chunk := buffer_take_front(nr_of_samples)
        size := i32(len(chunk) * size_of(f32))
        sdl.PutAudioStreamData(stream, &chunk, size)
    } else {
        //sdl.PutAudioStreamData(stream, &def, total_amount)
    }
}

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

@(private="file")
reset_all :: proc() {
    ppu_reset()
    apu_reset()
    cpu_reset()
    bus_reset()
    input_init()
}

@(private="file")
create_ui :: proc() {
    pause_btn = emu.ui_button({0, 0}, {245, 245}, pause_game, .middle_center)
    pause_btn.disabled = true
    pause_btn.sprite = emu.ui_sprites[2]
    pause_btn.color = {1, 1, 1, 0.4}

    load_btn = emu.ui_button({0, 0}, {150, 40}, load_game, .middle_center)
    emu.ui_text({0, 0}, 16, "Load game", .middle_center, load_btn)

    resume_btn = emu.ui_button({0, 50}, {150, 40}, resume_game, .middle_center)
    resume_btn.disabled = true
    emu.ui_text({0, 0}, 16, "Resume", .middle_center, resume_btn)
}

@(private="file")
pause_game :: proc(button: ^emu.Ui_element) {
    pause_emu(true)
    pause_btn.disabled = true
    load_btn.disabled = false
    resume_btn.disabled = false
}

@(private="file")
resume_game :: proc(button: ^emu.Ui_element) {
    pause_emu(false)
    pause_btn.disabled = false
    load_btn.disabled = true
    resume_btn.disabled = true
}

@(private="file")
load_game :: proc(button: ^emu.Ui_element) {
    sdl.ShowOpenFileDialog(load_callback, nil, window, &filter, 1, nil, false)
}

load_callback :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: i32) {
    context = runtime.default_context()
    game_path := string(filelist[0])
    if(game_path != "") {
        reset_all()
        bus_load_rom(game_path)
        sdl.SetWindowTitle(window, fmt.caprintf("odin-gb - %s", file_name))
        pause_emu(false)
        load_btn.disabled = true
        resume_btn.disabled = true
        when !START_BIOS {
            cpu_init_no_bios()
        }
    }
}