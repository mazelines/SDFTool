from setuptools import setup, Extension
import pybind11

ext = Extension(
    "sdf_core",
    ["sdf_core.cpp"],
    include_dirs=[pybind11.get_include()],
    language="c++",
    extra_compile_args=["/std:c++17", "/EHsc"],
)

setup(name="sdf_core", version="0.1.0", ext_modules=[ext])
