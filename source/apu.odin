package main

import "core:fmt"

direct_sound_a_counter: u16
direct_sound_b_counter: u16
direct_sound_a_out: u8
direct_sound_b_out: u8

/*
constexpr int duty_cycles[4][8] = {
    {0, 0, 0, 0, 0, 0, 0, 1},
    {1, 0, 0, 0, 0, 0, 0, 1},
    {1, 0, 0, 0, 0, 1, 1, 1},
    {0, 1, 1, 1, 1, 1, 1, 0}
};

constexpr int wave_shifts[] = {
    4, 0, 1, 2
};

constexpr int base_divisors[] = {
    8, 16, 32, 48, 64, 80, 96, 112
};

constexpr int cycles_per_clock = 4'190'000 / 512;
*/

apu_load_length_counter_square1 :: proc(len: u8) {
    //square1.length_counter = len
}

apu_load_length_counter_square2 :: proc(len: u8) {
    //square2.length_counter = len
}

// void load_length_counter_wave(int len)
// {
//     wave.length_counter = len;
// }

apu_load_length_counter_noise :: proc(len: u8) {
    //noise.length_counter = len
}

/*
void update_length_counter(Square &channel)
{
    bool length_enabled = *channel.reg4 & 0b01000000;
    if (length_enabled && channel.length_counter > 0) {
        --channel.length_counter;
        if (channel.length_counter == 0) {
            channel.disable();
        }
    }
}

void update_volume_envelope(Square &channel)
{
    const int mode = *channel.reg2 & 0b1000 ? 1 : -1;
    const int period = *channel.reg2 & 0b0111;
    if (period > 0) {
        --channel.vol_envelope_timer;
        // TODO: Can it be less than 0?
        if (channel.vol_envelope_timer == 0) {
            channel.vol_envelope_timer = period;
            int vol = channel.volume + mode;
            if (0 <= vol && vol <= 15) {
                channel.volume = vol;
                // TODO: Need some flag for disabled by volume?
                // "otherwise it is left unchanged and no further
                // automatic increments/decrements are made to the
                // volume until the channel is triggered again."
            }
        }
    }
}

void update_timer(Square &channel, int cycles)
{
    channel.timer_val -= cycles;
    if (channel.timer_val <= 0) {
        const int freq = ((*channel.reg4 & 0b111) << 8) | *channel.reg3;
        if (channel.type == ChannelType::wave) {
            channel.timer_period = 2 * (2048 - freq);
        } else if (channel.type == ChannelType::noise) {
            const int divisor = base_divisors[*channel.reg3 & 0x07];
            channel.timer_period =
                    divisor << ((*channel.reg3 & 0xf0) >> 4);
        } else {
            channel.timer_period = 4 * (2048 - freq);
        }
        channel.timer_val = channel.timer_period + channel.timer_val;
        if (channel.type == ChannelType::wave) {
            channel.position = (channel.position + 1) % 32;
            channel.sample_buffer = channel.read_wave_sample();
        } else if (channel.type == ChannelType::noise) {
            // NR43 FF22 SSSS WDDD Clock shift, Width mode of LFSR, Divisor code
            // the low two bits (0 and 1) are XORed,
            const int xor_result = (channel.lfsr & 0x01) ^ ((channel.lfsr & 0x02) >> 1);
            // all bits are shifted right by one,
            uint16_t shifted = channel.lfsr >> 1;
            // and the result of the XOR is put into the now-empty high bit.
            shifted |= xor_result << 14;
            // If width mode is 1 (NR43),
            if (*channel.reg3 & 0x08) {
                // the XOR result is ALSO put into bit 6 AFTER the shift, resulting in a 7-bit LFSR.
                shifted &= ~(1 << 6);
                shifted |= xor_result << 6;
            }
            channel.lfsr = shifted;
        } else {
            channel.duty_index = (channel.duty_index + 1) % 8;
        }
    }
}

unsigned int frequency_calculation(const Square &channel)
{
    int shift = *channel.reg0 & 0x07;
    bool negate = *channel.reg0 & 0x08;

    unsigned int shifted = channel.frequency_shadow >> shift;
    if (negate) {
        return channel.frequency_shadow - shifted;
    } else {
        return channel.frequency_shadow + shifted;
    }
}

void overflow_check(Square &channel, unsigned int freq)
{
    if (freq > 2047) {
        // Disable channel, TODO: Only when add not sub? See GB CPU manual:
        // "When overflow occurs at the addition mode while sweep is
        // operating at sound 1."
        channel.disable();
    }
}

void trigger(Square &channel)
{
    channel.enable();
    // Reset length counter if zero
    if (channel.length_counter == 0) {
        channel.length_counter = channel.type == ChannelType::wave ? 256 : 64;
    }
    // Reload frequency timer with period
    const int freq = ((*channel.reg4 & 0b111) << 8) | *channel.reg3;
    if (channel.type == ChannelType::wave) {
        channel.timer_period = 2 * (2048 - freq);
    } else if (channel.type == ChannelType::noise) {
        const int divisor = base_divisors[*channel.reg3 & 0x07];
        channel.timer_period =
                divisor << ((*channel.reg3 & 0xf0) >> 4);
    } else {
        channel.timer_period = 4 * (2048 - freq);
    }
    channel.timer_val = channel.timer_period;

    if (channel.type != ChannelType::wave) {
        // Reload volume envelope timer with period
        channel.vol_envelope_timer = *channel.reg2 & 0b00000111;
        // Reload starting volume
        channel.volume = (*channel.reg2 & 0b11110000) >> 4;
    }

    if (channel.type == ChannelType::noise) {
        channel.lfsr = 0x7f;
    }

    if (channel.type == ChannelType::wave) {
        channel.position = 0;
    }

    if (channel.type == ChannelType::square1) {
        // Sweep
        // Copy square 1's freq to the shadow register
        channel.frequency_shadow = freq;
        // Reload sweep timer (from period?) or 8
        int period = (*channel.reg0 & 0b01110000) >> 4;
        if (period != 0) {
            channel.sweep_timer = period;
        } else {
            channel.sweep_timer = 8;
        }
        int shift = *channel.reg0 & 0x07;
        // If sweep period isnt 0 or shift isnt 0: set internal enabled flag
        if (period != 0 || shift != 0) {
            channel.sweep_enabled = true;
        // else clear internal enabled flag
        } else {
            channel.sweep_enabled = false;
        }
        // If shift isnt 0, do freq calc and overflow check now
        if (shift != 0) {
            unsigned int new_freq = frequency_calculation(channel);
            overflow_check(channel, new_freq);
            // TODO: Should we write back?
        }
    }
}

void update_sweep(Square &channel)
{
    if (channel.sweep_timer > 0) {
        --channel.sweep_timer;
        if (channel.sweep_timer == 0) {
            int period = (*channel.reg0 & 0b01110000) >> 4;
            if (period != 0) {
                channel.sweep_timer = period;
            } else {
                channel.sweep_timer = 8;
            }
            if (channel.sweep_enabled && period != 0) {
                // Do sweep
                int shift = *channel.reg0 & 0b00000111;
                unsigned int new_freq = frequency_calculation(channel);
                overflow_check(channel, new_freq);
                if (new_freq < 2048 && shift != 0) {
                    // LSB
                    *channel.reg3 = new_freq & 0xff;
                    // MSB
                    *channel.reg4 = (*channel.reg4 & 0xf8) | ((new_freq & 0x700) >> 8);
                    channel.frequency_shadow = new_freq;
                    unsigned int new_new_freq = frequency_calculation(channel);
                    overflow_check(channel, new_new_freq);
                }
            }
        }
    }
}
*/
apu_advance :: proc(cycles: u32) {
    /*frame_sequencer += cycles;
    if (frame_sequencer >= cycles_per_clock) {
        frame_sequencer -= cycles_per_clock;
        frame_sequencer_step = (frame_sequencer_step + 1) % 8;

        // Length counter
        if (frame_sequencer_step % 2 == 0) {
            update_length_counter(square1);
            update_length_counter(square2);
            // update_length_counter(wave);
            update_length_counter(noise);
        }

        // Volume envelope
        if (frame_sequencer_step == 7) {
            update_volume_envelope(square1);
            update_volume_envelope(square2);
            update_volume_envelope(noise);
        }

        // Sweep
        if (frame_sequencer_step == 2 || frame_sequencer_step == 6) {
            update_sweep(square1);
        }
    }

    update_timer(square1, cycles);
    update_timer(square2, cycles);
    // update_timer(wave, cycles);
    update_timer(noise, cycles);*/
}

apu_trigger_square1 :: proc() {
    //trigger(square1)
}

apu_trigger_square2 :: proc() {
    //trigger(square2)
}

apu_trigger_noise :: proc() {
    //trigger(noise)
}

/*
void APU::trigger_noise()
{
    trigger(noise);
}

int APU::ds_a_timer()
{
    return !!(registers[SOUNDCNT_H + 1] & 0x04);
}

int APU::ds_b_timer()
{
    return !!(registers[SOUNDCNT_H + 1] & 0x40);
}

void APU::step_ds_a()
{
    direct_sound_a_out = direct_sound_a_buffer[direct_sound_a_counter];
    direct_sound_a_counter = (direct_sound_a_counter + 1) & 0b1111;
    if (direct_sound_a_counter == 0) {
        dma1->request_fifo_data();
    }
}

void APU::step_ds_b()
{
    direct_sound_b_out = direct_sound_b_buffer[direct_sound_b_counter];
    direct_sound_b_counter = (direct_sound_b_counter + 1) & 0b1111;
    if (direct_sound_b_counter == 0) {
        dma2->request_fifo_data();
    }
}
*/

apu_reset_fifo_a :: proc() {
    direct_sound_a_counter = 0
}

apu_reset_fifo_b :: proc() {
    direct_sound_b_counter = 0
}

apu_load_fifo_a :: proc(data: u8) {
    /*direct_sound_a_buffer[direct_sound_a_counter += 1] = data
    if (direct_sound_a_counter > 15)
        direct_sound_a_counter = 0*/
}

apu_load_fifo_b :: proc(data: u8) {
    /*direct_sound_b_buffer[direct_sound_b_counter++] = data
    if (direct_sound_b_counter > 15)
        direct_sound_b_counter = 0*/
}


apu_output :: proc() -> f32 {
    /*int duty1 = (registers[NR11] & 0b11000000) >> 6;
    int dac1_in = duty_cycles[duty1][square1.duty_index] * square1.volume;
    float dac1_out = dac1_in / 7.5;

    int duty2 = (registers[NR21] & 0b11000000) >> 6;
    int dac2_in = duty_cycles[duty2][square2.duty_index] * square2.volume;
    float dac2_out = dac2_in / 7.5;

    // int dac3_in = wave.sample_buffer >> wave_shifts[(registers[NR32] & 0b01100000) >> 5];
    // float dac3_out = dac3_in / 7.5 - 1.0;

    int dac4_in = (~noise.lfsr & 0x01) * noise.volume;
    float dac4_out = dac4_in / 7.5;

    float out = 0.0f;

    // Mix
    if (registers[NR52] & 0b00000001) {
        out += dac1_out;
    }
    if (registers[NR52] & 0b00000010) {
        out += dac2_out;
    }
    // if (registers[NR52] & 0b00000100) {
    //     out += dac3_out;
    // }
    if (registers[NR52] & 0b00001000) {
        out += dac4_out;
    }
    if (registers[SOUNDCNT_H + 1] & 0x03) {
        out += (direct_sound_a_out + 128) / 128.0f;
    }
    if (registers[SOUNDCNT_H + 1] & 0x30) {
        out += (direct_sound_b_out + 128) / 128.0f;
    }

    return out / 5.0 - 1.0;*/
    return 0
}
