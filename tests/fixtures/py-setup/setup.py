# Test fixture: a source package whose build code leaves a marker file. Harmless.
from setuptools import setup

open("@MARKER@", "w").write("x")
setup(name="evil-setup", version="1.0")
