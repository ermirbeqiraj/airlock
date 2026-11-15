# Runs only if the package gets built. Harmless: leaves a marker file.
from setuptools import setup

open("@MARKER@", "w").write("x")
setup()
