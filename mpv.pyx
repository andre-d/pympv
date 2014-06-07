# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""pympv - Python wrapper for libmpv

libmpv is a client library for the media player mpv

For more info see: https://github.com/mpv-player/mpv/blob/master/libmpv/client.h
"""

import sys
from libc.stdlib cimport malloc, free
from client cimport *

__version__ = 0.1
__author__ = "Andre D"

_MPV_C_CLIENT_API_VERSION = 0

if mpv_client_api_version() >> 16 != _MPV_C_CLIENT_API_VERSION:
    raise ImportError('libmpv version is incorrect')

_is_py3 = sys.version_info >= (3,)
_strdec_err = 'surrogateescape' if _is_py3 else 'strict'
def _strdec(s):
    try:
        return s.decode('utf-8', _strdec_err)
    except UnicodeDecodeError:
        return bytes(s)


class Errors:
    """Set of known error codes from MpvError and Event responses.

    Mostly wraps the enum mpv_error.
    Values might not always be integers in the future.
    You should handle the possibility that error codes may not be any of these values.
    """
    success = MPV_ERROR_SUCCESS
    queue_full = MPV_ERROR_EVENT_QUEUE_FULL
    nomem = MPV_ERROR_NOMEM
    uninitialized = MPV_ERROR_UNINITIALIZED
    invalid_parameter = MPV_ERROR_INVALID_PARAMETER
    not_found = MPV_ERROR_OPTION_NOT_FOUND
    option_format = MPV_ERROR_OPTION_FORMAT
    option_error = MPV_ERROR_OPTION_ERROR
    not_found = MPV_ERROR_PROPERTY_NOT_FOUND
    property_format = MPV_ERROR_PROPERTY_FORMAT
    property_unavailable = MPV_ERROR_PROPERTY_UNAVAILABLE
    property_error = MPV_ERROR_PROPERTY_ERROR
    command_error = MPV_ERROR_COMMAND


class Events:
    """Set of known values for Event ids.

    Mostly wraps the enum mpv_event_id.
    Values might not always be integers in the future.
    You should handle the possibility that event ids may not be any of these values.
    """
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
    chapter_change = MPV_EVENT_CHAPTER_CHANGE


class EOFReasons:
    """Known possible values for EndOfFileReached reason.

    You should handle the possibility that the reason may not be any of these values.
    """
    eof = 0
    restarted = 1
    aborted = 2
    quit = 3


cdef class EndOfFileReached(object):
    """Data field for MPV_EVENT_END_FILE events

    Wraps: mpv_event_end_file
    """
    cdef public object reason

    cdef _init(self, mpv_event_end_file* eof):
        self.reason = eof.reason
        return self


cdef class InputDispatch(object):
    """Data field for MPV_EVENT_SCRIPT_INPUT_DISPATCH events.

    Wraps: mpv_event_script_input_dispatch
    """
    cdef public object arg0, type

    cdef _init(self, mpv_event_script_input_dispatch* input):
        self.arg0 = input.arg0
        self.type = _strdec(input.type)
        return self


cdef class LogMessage(object):
    """Data field for MPV_EVENT_LOG_MESSAGE events.
    
    Wraps: mpv_event_log_message
    """
    cdef public object prefix, level, text

    cdef _init(self, mpv_event_log_message* msg):
        self.level = _strdec(msg.level)
        self.prefix = _strdec(msg.prefix)
        self.text = _strdec(msg.text)
        return self


cdef _convert_node_value(mpv_node node):
    if node.format == MPV_FORMAT_STRING:
        return _strdec(node.u.string)
    elif node.format == MPV_FORMAT_FLAG:
        return not not int(node.u.flag)
    elif node.format == MPV_FORMAT_INT64:
        return int(node.u.int64)
    elif node.format == MPV_FORMAT_DOUBLE:
        return float(node.u.double_)
    elif node.format == MPV_FORMAT_NODE_MAP:
        return _convert_value(node.u.list, node.format)
    elif node.format == MPV_FORMAT_NODE_ARRAY:
        return _convert_value(node.u.list, node.format)
    return None


cdef _convert_value(void* data, mpv_format format):
    cdef mpv_node node
    cdef mpv_node_list nodelist
    if format == MPV_FORMAT_NODE:
        node = (<mpv_node*>data)[0]
        return _convert_node_value(node)
    elif format == MPV_FORMAT_NODE_ARRAY:
        nodelist = (<mpv_node_list*>data)[0]
        values = []
        for i in range(nodelist.num):
            values.append(_convert_node_value(nodelist.values[i]))
        return values
    elif format == MPV_FORMAT_NODE_MAP:
        nodelist = (<mpv_node_list*>data)[0]
        values = {}
        for i in range(nodelist.num):
            value = _convert_node_value(nodelist.values[i])
            values[_strdec(nodelist.keys[i])] = value
        return values
    elif format == MPV_FORMAT_STRING:
        return _strdec(((<char**>data)[0]))
    elif format == MPV_FORMAT_FLAG:
        return not not (<uint64_t*>data)[0]
    elif format == MPV_FORMAT_INT64:
        return int((<uint64_t*>data)[0])
    elif format == MPV_FORMAT_DOUBLE:
        return float((<double*>data)[0])
    return None


cdef class Property(object):
    """Data field for MPV_EVENT_PROPERTY_CHANGE and MPV_EVENT_GET_PROPERTY_REPLY.

    Wraps: mpv_event_property
    """
    cdef public object name, data

    cdef _init(self, mpv_event_property* prop):
        self.name = _strdec(prop.name)
        self.data = _convert_value(prop.data, prop.format)
        return self


cdef class Event(object):
    """Wraps: mpv_event"""
    cdef public object id, data, reply_userdata, observed_property, error

    @property
    def error_str(self):
        """mpv_error_string of the error proeprty"""
        return _strdec(mpv_error_string(self.error))

    cdef _data(self, mpv_event* event):
        cdef void* data = event.data
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
            for i in range(num_args):
                arg = <char*>climsg.args[i]
                arg = _strdec(arg)
                args.append(arg)
            return args
        elif self.id == MPV_EVENT_END_FILE:
            return EndOfFileReached()._init(<mpv_event_end_file*>data)
        return None

    @property
    def name(self):
        """mpv_event_name of the event id"""
        return _strdec(mpv_event_name(self.id))

    cdef _init(self, mpv_event* event, ctx):
        self.id = event.event_id
        self.data = self._data(event)
        if self.id == MPV_EVENT_PROPERTY_CHANGE:
            userdata = _async_data[id(ctx)].get(event.reply_userdata, None)
            self.observed_property = userdata
        else:
            userdata = _async_data[id(ctx)].pop(event.reply_userdata, None)
        self.reply_userdata = userdata.value() if userdata else None
        self.error = event.error
        return self


def _errors(fn):
    def wrapped(*k, **kw):
        v = fn(*k, **kw)
        if v < 0:
            raise MPVError(v)
    return wrapped


class MPVError(Exception):
    code = None
    
    def __init__(self, e):
        self.code = e
        if not isinstance(e, str):
            e = _strdec(mpv_error_string(e))
        Exception.__init__(self, e)


_callbacks = {}


_async_data = {}
class _AsyncData:
    def __init__(self, ctx, data):
        self._group = id(ctx)
        self._data = data
        _async_data[self._group][id(self)] = self

    def _remove(self):
        _async_data[self._group].pop(id(self))

    def value(self):
        return self._data


class ObservedProperty(_AsyncData):
    pass 


cdef class Context(object):
    """Base class wrapping a context to interact with mpv.

    Assume all calls can raise MPVError.

    Wraps: mpv_create, mpv_destroy and all mpv_handle related calls
    """

    cdef mpv_handle *_ctx

    @property
    def name(self):
        """Unique name for every context created.

        Wraps: mpv_client_name
        """
        return _strdec(mpv_client_name(self._ctx))

    @property
    def time(self):
        """Internal mpv client time.

        Has an arbitrary start offset, but will never wrap or go backwards.

        Wraps: mpv_get_time_us
        """
        return mpv_get_time_us(self._ctx)

    def suspend(self):
        """Wraps: mpv_suspend"""
        mpv_suspend(self._ctx)

    def resume(self):
        """Wraps: mpv_resume"""
        mpv_resume(self._ctx)

    @_errors
    def request_event(self, event, enable):
        """Enable or disable a given event.

        Arguments:
        event - See Events
        enable - True to enable, False to disable

        Wraps: mpv_request_event
        """
        enable = 1 if enable else 0
        return mpv_request_event(self._ctx, event, enable)

    @_errors
    def set_log_level(self, loglevel):
        """Wraps: mpv_request_log_messages"""
        loglevel = loglevel.encode('utf-8')
        return mpv_request_log_messages(self._ctx, <const char*>loglevel)

    @_errors
    def load_config(self, filename):
        """Wraps: mpv_load_config_file"""
        filename = filename.encode('utf-8')
        cdef const char* _filename = filename
        return mpv_load_config_file(self._ctx, _filename)

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

    cdef mpv_node _prep_native_value(self, value, format):
        cdef mpv_node node
        node.format = format
        if format == MPV_FORMAT_STRING:
            value = value.encode('utf-8')
            node.u.string = value
        elif format == MPV_FORMAT_FLAG:
            node.u.flag = 1 if value else 0
        elif format == MPV_FORMAT_INT64:
            node.u.int64 = value
        elif format == MPV_FORMAT_DOUBLE:
            node.u.double_ = value
        else:
            node.format = MPV_FORMAT_NONE
        return node

    @_errors
    def command(self, *cmdlist, async=False, data=None):
        """Send a command to mpv.

        Arguments:
        Accepts parameters as args, not a single string.

        Keyword Arguments:
        async: True will return right away, status comes in as MPV_EVENT_COMMAND_REPLY
        data: Only valid if async, gets sent back as reply_userdata in the Event

        Wraps: mpv_command and mpv_command_async
        """
        lsize = (len(cmdlist) + 1) * sizeof(void*)
        cdef const char** cmds = <const char**>malloc(lsize)
        if not cmds:
            raise MemoryError
        cmdlist = [cmd.encode('utf-8') for cmd in cmdlist]
        for i, cmd in enumerate(cmdlist):
            cmds[i] = <char*>cmd
        cmds[i + 1] = NULL
        if not async:
            rv = mpv_command(self._ctx, cmds)
        else:
            data = _AsyncData(self, data) if data is not None else None
            rv = mpv_command_async(self._ctx, id(data), cmds)
        free(cmds)
        return rv

    @_errors
    def get_property_async(self, prop, data=None):
        """Gets the value of a property asynchronously.

        Arguments:
        prop: Property to get the value of.
        
        Keyword arguments:
        data: Value to be passed into the reply_userdata of the response event.
        Wraps: mpv_get_property_async"""
        prop = prop.encode('utf-8')
        data = _AsyncData(self, data) if data is not None else None
        v = mpv_get_property_async(
            self._ctx,
            id(data),
            <const char*>prop,
            MPV_FORMAT_NODE,
        )
        if v < 0 and data:
            data._remove()
        return v

    def get_property(self, prop):
        """Wraps: mpv_get_property"""
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
        v = _convert_node_value(result)
        mpv_free_node_contents(&result)
        return v

    @_errors
    def set_property(self, prop, value=True, async=False, data=None):
        """Wraps: mpv_set_property and mpv_set_property_async"""
        prop = prop.encode('utf-8')
        cdef mpv_format format = self._format_for(value)
        cdef mpv_node v = self._prep_native_value(value, format)
        if not async:
            return mpv_set_property(
                self._ctx,
                <const char*>prop,
                MPV_FORMAT_NODE,
                &v
            )
        data = _AsyncData(self, data) if data is not None else None
        err = mpv_set_property_async(
            self._ctx,
            id(data),
            <const char*>prop,
            MPV_FORMAT_NODE,
            &v
        )
        if err < 0 and data:
            data._remove()
        return err

    @_errors
    def set_option(self, prop, value=True):
        """Wraps: mpv_set_option"""
        prop = prop.encode('utf-8')
        cdef mpv_format format = self._format_for(value)
        cdef mpv_node v = self._prep_native_value(value, format)
        return mpv_set_option(
            self._ctx,
            <const char*>prop,
            MPV_FORMAT_NODE,
            &v
        )

    @_errors
    def initialize(self):
        """Wraps: mpv_initialize"""
        return mpv_initialize(self._ctx)

    def wait_event(self, timeout=None):
        """Wraps: mpv_wait_event"""
        timeout = timeout if timeout is not None else -1
        return Event()._init(mpv_wait_event(self._ctx, timeout), self)

    def wakeup(self):
        """Wraps: mpv_wakeup"""
        mpv_wakeup(self._ctx)

    def set_wakeup_callback(self, callback, data):
        """Wraps: mpv_set_wakeup_callback"""
        cdef int64_t name = id(self)
        _callbacks[id(self)] = (callback, data)
        mpv_set_wakeup_callback(self._ctx, _c_callback, <void*>name)

    def get_wakeup_pipe(self):
        """Wraps: mpv_get_wakeup_pipe"""
        return mpv_get_wakeup_pipe(self._ctx)

    def __cinit__(self):
        self._ctx = mpv_create()
        if not self._ctx:
            raise MPVError('Context creation error')
        _callbacks[id(self)] = (None, None)
        _async_data[id(self)] = {}

    def observe_property(self, prop, data=None):
        """Wraps: mpv_observe_property"""
        new = False
        if data is not None and not isinstance(data, ObservedProperty):
            new = True
            data = ObservedProperty(self, data)
        prop = prop.encode('utf-8')
        v = mpv_observe_property(
            self._ctx,
            id(data),
            prop,
            MPV_FORMAT_NODE,
        )
        if v < 0:
            data._remove() if new else None
            raise MPVError(v)
        return data

    @_errors
    def unobserve_property(self, data):
        """Wraps: mpv_unobserve_property"""
        data._remove() if data else None
        return mpv_unobserve_property(
            self._ctx,
            id(data),
        )

    def __dealloc__(self):
        del _callbacks[id(self)]
        del _async_data[id(self)]
        mpv_destroy(self._ctx)


cdef void _c_callback(void* d):
    name = <int64_t>d
    cb, data = _callbacks[name]
    cb(data) if cb else None
