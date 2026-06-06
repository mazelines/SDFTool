# -*- mode: python ; coding: utf-8 -*-

from PyInstaller.utils.hooks import collect_dynamic_libs, collect_data_files, collect_submodules

_wgpu_bins = collect_dynamic_libs('wgpu')
_wgpu_datas = collect_data_files('wgpu')
_wgpu_hidden = collect_submodules('wgpu')

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=[
        ('Cpp_Core\\x64\\Release\\SDF_Cpp.pyd', '.'),
        ('dll\\opencv_world480.dll', 'dll'),
        ('Cpp_Core\\sdf_core.cp310-win_amd64.pyd', '.'),
    ] + _wgpu_bins,
    datas=[
        ('main.qml', '.'),
        ('localization_cache.json', '.'),
        ('design_handoff_sdftool\\assets', 'design_handoff_sdftool\\assets'),
        ('sdf_gpu\\shaders\\*.wgsl', 'sdf_gpu\\shaders'),
    ] + _wgpu_datas,
    hiddenimports=_wgpu_hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='SDFTool',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='SDFTool',
)
