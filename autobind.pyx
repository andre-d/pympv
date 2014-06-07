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

import weakref
from collections import defaultdict


class ObservedSet(object):
    _watchers = defaultdict(weakref.WeakSet)

    @classmethod
    def _pump(cls, mp, prop):
        for watcher in cls._watchers[id(mp)]:
            if not hasattr(watcher, prop.name):
                continue
            object.__setattr__(watcher, prop.name, prop.data)

    @classmethod
    def _detatch(cls, mp):
        cls._watchers.pop(id(mp), None)

    def observe(self, prop, value=None):
        if value is not None:
            self._mp.set_property(prop, value)
        group = self._group if self._group is not None else id(self)
        self._group = self._mp.observe_property(prop, data=group)

    def __init__(self, mp):
        self._mp = mp
        self._group = None
        self._watchers[id(mp)].add(self)
        for prop in dir(self):
            value = getattr(self, prop)
            if prop.startswith('_') or callable(value):
                continue
            self.observe(prop, value)

    def __setattr__(self, attr, value):
        if attr.startswith('_') or callable(getattr(self, attr)):
            object.__setattr__(self, attr, value)
        elif not hasattr(self, value):
            self.observe(attr, value)
        else:
            self._mp.set_property(attr, value)
