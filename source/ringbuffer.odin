package main

import "core:fmt"

N :: 8192
buffer: [N]f32
begin: u32
end: u32

buffer_size :: proc() -> u32 {
    if (begin <= end) {
        return end - begin
    } else {
        return end + N - begin
    }
}

buffer_is_full :: proc() -> bool {
    return buffer_size() == N - 1
}

buffer_push_back :: proc(x: f32) {
    assert(!buffer_is_full())
    buffer[end] = x
    end += 1
    end &= N - 1
}

buffer_take_front :: proc(n: u32) -> []f32 {
    assert(n <= buffer_size())

    /*std::vector<float> data
    it := back_inserter(data)
    if(begin <= end) {
        std::copy(&buffer[begin], &buffer[end], it)
    } else {
        std::copy(&buffer[begin], std::end(buffer), it)
        std::copy(std::begin(buffer), &buffer[end], it)
    }*/
    slice: []f32
    if(begin <= end) {
        slice = buffer[begin:begin + n]
    } else {
        slice = {0,0}
    }

    begin += n
    begin &= N - 1

    return slice
}