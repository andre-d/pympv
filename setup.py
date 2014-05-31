import os
from subprocess import call
from distutils.core import setup
from distutils.extension import Extension
from distutils.command.clean import clean
from Cython.Distutils import build_ext

def tryremove(filename):
    if not os.path.isfile(filename):
        return
    try:
        os.remove(filename)
    except OSError as e:
        print(e)

class Clean(clean):
    side_effects = [
        "mpv.c",
    ]

    def run(self):
        for f in self.side_effects:
            tryremove(f)
        clean.run(self)

class ExtBuilder(build_ext):
    def run(self):
        if not os.path.isfile("client.pxd"):
            call(["cwrap", "mpv/client.h", "client.pxd"])
        build_ext.run(self)

setup(
    cmdclass = {
        "build_ext": ExtBuilder,
        "clean": Clean,
    },
    ext_modules = [Extension("mpv", ["mpv.pyx"], libraries=['mpv'])]
)
