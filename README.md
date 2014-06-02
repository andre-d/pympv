pympv
=====
A python wrapper for libmpv.

To use

    import mpv
    m = mpv.Context()
    m.initialize()
    while True:
        event = m.wait_event(.01)
        if event.id == mpv.Events.none:
            continue
        elif event.id == mpv.Events.end_file:
            break
        elif event.id == mpv.Events.shutdown:
            break

libmpv is a client library for the media player mpv

For more info see: https://github.com/mpv-player/mpv/blob/master/libmpv/client.h
