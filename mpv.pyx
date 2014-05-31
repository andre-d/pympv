cimport cython
from libc.stdlib cimport malloc, free
from client cimport *

_MPV_C_CLIENT_API_VERSION = 0

if mpv_client_api_version() >> 16 != _MPV_C_CLIENT_API_VERSION:
    raise ImportError('libmpv version is incorrect') 

class Events:
    none = MPV_EVENT_NONE
    shutdown = MPV_EVENT_SHUTDOWN
    log_message = MPV_EVENT_LOG_MESSAGE
    get_property_reply = MPV_EVENT_GET_PROPERTY_REPLY
    set_property_reply = MPV_EVENT_SET_PROPERTY_REPLY
    command_reply = MPV_EVENT_COMMAND_REPLY
    start_file = MPV_EVENT_START_FILE
    end_file = MPV_EVENT_END_FILE
    file_loaded = MPV_EVENT_FILE_LOADED
    tracks_changed = MPV_EVENT_TRACKS_CHANGED
    tracks_switched = MPV_EVENT_TRACK_SWITCHED
    idle = MPV_EVENT_IDLE
    pause = MPV_EVENT_PAUSE
    unpause = MPV_EVENT_UNPAUSE
    tick = MPV_EVENT_TICK
    script_input_dispatch = MPV_EVENT_SCRIPT_INPUT_DISPATCH
    client_message = MPV_EVENT_CLIENT_MESSAGE
    video_reconfig = MPV_EVENT_VIDEO_RECONFIG
    audio_reconfig = MPV_EVENT_AUDIO_RECONFIG
    metadata_update = MPV_EVENT_METADATA_UPDATE
    seek = MPV_EVENT_SEEK
    playback_restart = MPV_EVENT_PLAYBACK_RESTART
    property_change = MPV_EVENT_PROPERTY_CHANGE

class EOFReasons:
    eof = 0
    restarted = 1
    aborted = 2
    quit = 3

cdef class EndOfFileReached(object):
    cdef mpv_event_end_file *_eof

    @property
    def reason(self):
        return self._eof.reason

    def __cinit__(self):
        self._eof = NULL

    cdef _init(self, mpv_event_end_file* eof):
        self._eof = eof
        return self

cdef class InputDispatch(object):
    cdef mpv_event_script_input_dispatch *_input

    @property
    def arg0(self):
        return self._input.arg0

    @property
    def type(self):
        return self._input.type.decode('utf-8')

    def __cinit__(self):
        self._input = NULL

    cdef _init(self, mpv_event_script_input_dispatch* input):
        self._input = input
        return self

cdef class LogMessage(object):
    cdef mpv_event_log_message *_msg

    @property
    def prefix(self):
        return self._msg.prefix.decode('utf-8')

    @property
    def level(self):
        return self._msg.level.decode('utf-8')

    @property
    def text(self):
        return self._msg.text.decode('utf-8')

    def __cinit__(self):
        self._msg = NULL

    cdef _init(self, mpv_event_log_message* msg):
        self._msg = msg
        return self

cdef _convert_value(void* data, mpv_format format):
    if format == MPV_FORMAT_STRING:
        return ((<char**>data)[0]).decode('utf-8')
    elif format == MPV_FORMAT_FLAG:
        return not not (<uint64_t*>data)[0]
    elif format == MPV_FORMAT_INT64:
        return int((<uint64_t*>data)[0])
    elif format == MPV_FORMAT_DOUBLE:
        return float((<double*>data)[0])
    return None

cdef class Property(object):
    cdef mpv_event_property* _property

    @property
    def name(self):
        return self._property.name.decode('utf-8')

    def data(self):
        return _convert_value(self._property.data, self._property.format)

    def __cinit_(self):
        self._property = NULL

    cdef _init(self, mpv_event_property* prop):
        self._property = prop
        return self

cdef class Event(object):
    cdef mpv_event *_event

    def __cinit__(self):
        self._event = NULL

    @property
    def error(self):
        return self._event.error

    @property
    def error_str(self):
        return mpv_error_string(self.error).decode('utf-8')

    @property
    def id(self):
        return self._event.event_id

    @property
    def reply_userdata(self):
        return self._event.reply_userdata

    @property
    def data(self):
        cdef void* data = self._event.data
        cdef mpv_event_client_message* climsg
        if self.id == MPV_EVENT_GET_PROPERTY_REPLY:
            return Property()._init(<mpv_event_property*>data)
        elif self.id == MPV_EVENT_PROPERTY_CHANGE:
            return Property()._init(<mpv_event_property*>data)
        elif self.id == MPV_EVENT_LOG_MESSAGE:
            return LogMessage()._init(<mpv_event_log_message*>data)
        elif self.id == MPV_EVENT_SCRIPT_INPUT_DISPATCH:
            return InputDispatch()._init(<mpv_event_script_input_dispatch*>data)
        elif self.id == MPV_EVENT_CLIENT_MESSAGE:
            climsg = <mpv_event_client_message*>data
            args = []
            num_args = climsg.num_args
            for i in range(0, num_args):
                arg = <char*>climsg.args[i]
                arg = arg.decode('utf-8')
                args.append(arg)
            return args
        elif self.id == MPV_EVENT_END_FILE:
            return EndOfFileReached()._init(<mpv_event_end_file*>data)
        return None

    @property
    def name(self):
        return mpv_event_name(self._event.event_id).decode('utf-8')

    cdef _init(self, mpv_event* event):
        self._event = event
        return self

def errors(infn):
    def fn(*k, **kw):
        v = infn(*k, **kw)
        if v < 0:
            raise MPVError(v)
    return fn

class MPVError(Exception):
    def __init__(self, e):
        if not isinstance(e, str):
            e = mpv_error_string(e).decode('utf-8')
        Exception.__init__(self, e)

cdef class Context(object):
    cdef mpv_handle *_ctx

    @property
    def name(self):
        return mpv_client_name(self._ctx).decode('utf-8')

    @property
    def time(self):
        return mpv_get_time_us(self._ctx)

    def suspend(self):
        mpv_suspend(self._ctx)

    def resume(self):
        mpv_resume(self._ctx)

    def _format_for(self, value):
        if isinstance(value, str):
            return MPV_FORMAT_STRING
        elif isinstance(value, bool):
            return MPV_FORMAT_FLAG
        elif isinstance(value, int):
            return MPV_FORMAT_INT64
        elif isinstance(value, float):
            return MPV_FORMAT_DOUBLE
        return MPV_FORMAT_NONE

    def _convert_value(self, value, format):
        if format == MPV_FORMAT_STRING:
            return value.encode('utf-8')
        if format == MPV_FORMAT_FLAG:
            value = 1 if value else 0
        return value

    @errors
    def command(self, *cmdlist):
        lsize = (len(cmdlist) + 1) * cython.sizeof(cython.p_int)
        cdef const char** cmds = <const char**>malloc(lsize)
        if not cmds:
            raise MemoryError
        for i, cmd in enumerate(cmdlist):
            cmd = cmd.encode('utf-8')
            cmds[i] = <char*>cmd
        cmds[i + 1] = NULL
        rv = mpv_command(self._ctx, cmds)
        free(cmds)
        return rv

    def get_property(self, prop):
        cdef mpv_node result
        prop = prop.encode('utf-8')
        v = mpv_get_property(
            self._ctx,
            <const char*>prop,
            MPV_FORMAT_NODE,
            &result,
        )
        if v < 0:
            raise MPVError(v)
        if result.format == MPV_FORMAT_STRING:
            v = result.u.string.decode('utf-8')
        elif result.format == MPV_FORMAT_FLAG:
            v = not not int(result.u.flag)
        elif result.format == MPV_FORMAT_INT64:
            v = int(result.u.int64)
        elif result.format == MPV_FORMAT_DOUBLE:
            v = float(result.u.double_)
        mpv_free_node_contents(&result)
        return None

    FLAG_SET = object()
    @errors
    def set_option(self, prop, value=Context.FLAG_SET):
        value = value if value is not Context.FLAG_SET else ''
        cdef mpv_format format = self._format_for(value)
        value = self._convert_value(value, format)
        prop = prop.encode('utf-8')
        cdef void* v
        cdef char* cv
        cdef uint64_t iv
        if format == MPV_FORMAT_STRING:
            cv = <char*>value
            v = &cv
        elif format == MPV_FORMAT_NONE:
            v = NULL
        else:
            iv = value
            v = &iv
        return mpv_set_option(
            self._ctx,
            <const char*>prop,
            format,
            v
        )

    @errors
    def initialize(self):
        return mpv_initialize(self._ctx)

    def wait_event(self, timeout=None):
        timeout = timeout or 0
        return Event()._init(mpv_wait_event(self._ctx, timeout))

    def __cinit__(self):
        self._ctx = mpv_create()
        if not self._ctx:
            raise MPVError('Context creation error')

    def __dealloc__(self):
        mpv_destroy(self._ctx)
