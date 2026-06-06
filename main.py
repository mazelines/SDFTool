# This Python file uses the following encoding: utf-8
import os
import sys
import json
import threading
import hashlib
import tempfile
import shutil
from pathlib import Path
import cv2

import numpy as np
from localization import Localization

for stream in (sys.stdout, sys.stderr):
    if stream and hasattr(stream, "reconfigure"):
        stream.reconfigure(encoding="utf-8", errors="backslashreplace")

os.environ.setdefault("QT_QUICK_BACKEND", "software")

from PySide6.QtCore import QObject, Signal, Slot
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QFileDialog, QApplication

_dll_dir_handles = []

if getattr(sys, "frozen", False):
    base_dir = Path(sys._MEIPASS)
else:
    base_dir = Path(__file__).resolve().parent

dll_dir = base_dir / "dll"
if dll_dir.exists():
    _dll_dir_handles.append(os.add_dll_directory(str(dll_dir)))

# import QtQuick
sys.path.append(str(base_dir))
sys.path.append(str(base_dir / "Cpp_Core" / "x64" / "Release"))
import SDF_Cpp
import sdf_backend



class SDFLib:
    def __init__(self, parent=None):
        super().__init__(parent)

    @staticmethod
    def SDF_Generate(folder_path, threshold_255, spread):
        output_folder = ""
        out_dir = os.path.join(folder_path, "output")
        for filename in os.listdir(folder_path):
            file_path = os.path.join(folder_path, filename)
            # 检查文件是否是图像文件
            if os.path.isfile(file_path) and filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                gray = cv2.imread(file_path, cv2.IMREAD_GRAYSCALE)
                if gray is None:
                    continue
                sdf = sdf_backend.generate_distance_field(gray, threshold_255, float(spread))
                os.makedirs(out_dir, exist_ok=True)
                cv2.imwrite(os.path.join(out_dir, filename), sdf)
                output_folder = out_dir + os.sep
        return output_folder

    @staticmethod
    def lerp_SDF(folder_path, threshold_255, spread):
        sdf_folder = SDFLib.SDF_Generate(folder_path, threshold_255, spread)
        if sdf_folder.strip() != "":
            print("SDF生成完成")
            SDF_Cpp.SDFLerp(sdf_folder)
            print("SDF插值完成")
        return sdf_folder

    @staticmethod
    def make_Atlas(folder_path, row, col, resolution_x, resolution_y, is_topdown_one_texture):
        images = np.empty((row, col), dtype=object)
        res_x = resolution_x / row
        for filename in os.listdir(folder_path):
            if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.gif', '.bmp')):
                parts = os.path.splitext(filename)[0].split('_')
                if len(parts) >= 2:
                    i = parts[-2]
                    j = parts[-1]
                    if i.isdigit() and j.isdigit():
                        filepath = os.path.join(folder_path, filename)
                        img = cv2.imread(filepath)
                        images[int(i)-1][int(j)-1] = img
                        # print(f'{i},{j}')

        if is_topdown_one_texture:
            for i in range(1, col):
                images[0][i] = images[0][0]
                images[row - 1][i] = images[row - 1][0]

        combine = None
        for i in range(row):
            row_images = images[i * col: (i + 1) * col]
            row_concatenated = cv2.hconcat(images[i])
            if combine is None:
                combine = row_concatenated
            else:
                combine = cv2.vconcat([combine, row_concatenated])

        print(combine.shape)
        result = cv2.resize(combine, (resolution_x, resolution_y))
        is_generated = cv2.imwrite(folder_path + "/SDF_Atlas.png", result)
        if is_generated:
            print(f"图集生成成功，路径：{folder_path}/SDF_Atlas.png")
        return folder_path + "/SDF_Atlas.png" if is_generated else ""


IMAGE_EXTENSIONS = ('.jpg', '.jpeg', '.png', '.gif', '.bmp')


def path_to_url(path):
    return Path(path).resolve().as_uri()


def list_image_files(folder_path):
    if not folder_path or not os.path.isdir(folder_path):
        return []
    return [
        os.path.join(folder_path, name)
        for name in sorted(os.listdir(folder_path))
        if os.path.isfile(os.path.join(folder_path, name))
        and name.lower().endswith(IMAGE_EXTENSIONS)
    ]


def atlas_coordinate(file_path):
    parts = Path(file_path).stem.split('_')
    if len(parts) < 2:
        return None
    row_text = parts[-2]
    col_text = parts[-1]
    if row_text.isdigit() and col_text.isdigit():
        return int(row_text), int(col_text)
    return None


def inspect_image_folder(folder_path, row=0, col=0, is_topdown_one_texture=False):
    images = []
    atlas_cells = {}
    max_row = 0
    max_col = 0
    duplicate_cells = []
    invalid_cells = []
    unreadable_images = []
    dimension_errors = []
    first_shape = None

    for file_path in list_image_files(folder_path):
        image = cv2.imread(file_path)
        if image is None:
            height = 0
            width = 0
            unreadable_images.append(os.path.basename(file_path))
        else:
            height = int(image.shape[0])
            width = int(image.shape[1])
            shape = (height, width, int(image.shape[2]) if len(image.shape) > 2 else 1)
            if first_shape is None:
                first_shape = shape
            elif shape != first_shape:
                dimension_errors.append(os.path.basename(file_path))
        coordinate = atlas_coordinate(file_path)
        image_info = {
            "path": file_path,
            "url": path_to_url(file_path),
            "name": os.path.basename(file_path),
            "width": width,
            "height": height,
            "row": 0,
            "col": 0,
        }
        if coordinate:
            atlas_row, atlas_col = coordinate
            image_info["row"] = atlas_row
            image_info["col"] = atlas_col
            if atlas_row < 1 or atlas_col < 1:
                invalid_cells.append({"name": image_info["name"], "row": atlas_row, "col": atlas_col})
            if row and (atlas_row > row or atlas_col > col):
                invalid_cells.append({"name": image_info["name"], "row": atlas_row, "col": atlas_col})
            cell_key = (atlas_row, atlas_col)
            if cell_key in atlas_cells:
                duplicate_cells.append({
                    "row": atlas_row,
                    "col": atlas_col,
                    "key": f"{atlas_row}_{atlas_col}",
                    "name": image_info["name"],
                })
            else:
                atlas_cells[cell_key] = image_info["name"]
            max_row = max(max_row, atlas_row)
            max_col = max(max_col, atlas_col)
        images.append(image_info)

    expected_row = int(row) if row else max_row
    expected_col = int(col) if col else max_col
    missing_cells = []
    if expected_row > 0 and expected_col > 0:
        for atlas_row in range(1, expected_row + 1):
            for atlas_col in range(1, expected_col + 1):
                present = (atlas_row, atlas_col) in atlas_cells
                top_or_bottom = atlas_row == 1 or atlas_row == expected_row
                covered_by_single_edge = (
                    is_topdown_one_texture
                    and top_or_bottom
                    and atlas_col > 1
                    and (atlas_row, 1) in atlas_cells
                )
                if not present and not covered_by_single_edge:
                    missing_cells.append({
                        "row": atlas_row,
                        "col": atlas_col,
                        "key": f"{atlas_row}_{atlas_col}",
                    })

    first = images[0] if images else {"width": 0, "height": 0}
    return {
        "path": folder_path,
        "count": len(images),
        "images": images,
        "width": first["width"],
        "height": first["height"],
        "maxRow": max_row,
        "maxCol": max_col,
        "hasAtlasCoordinates": max_row > 0 and max_col > 0,
        "missingCells": missing_cells,
        "duplicateCells": duplicate_cells,
        "invalidCells": invalid_cells,
        "unreadableImages": unreadable_images,
        "dimensionErrors": dimension_errors,
        "outputFolder": os.path.join(folder_path, "output") if folder_path else "",
        "atlasOutput": os.path.join(folder_path, "SDF_Atlas.png") if folder_path else "",
    }


def result_json(payload):
    return json.dumps(payload, ensure_ascii=False)


def preview_cache_dir():
    path = Path(tempfile.gettempdir()) / "SDFTool" / "previews"
    path.mkdir(parents=True, exist_ok=True)
    return path


def generate_sdf_preview_result(image_path, threshold, spread):
    if not image_path or not os.path.isfile(image_path):
        return {"ok": False, "error": "Invalid preview source", "outputFile": "", "outputUrl": ""}

    source_path = Path(image_path).resolve()
    key = hashlib.sha1(f"{source_path}:{os.path.getmtime(source_path)}".encode("utf-8")).hexdigest()[:16]
    work_dir = preview_cache_dir() / key
    work_dir.mkdir(parents=True, exist_ok=True)
    preview_source = work_dir / f"preview{source_path.suffix.lower()}"
    output_file = work_dir / "output" / f"{preview_source.stem}.png"

    if not output_file.exists():
        shutil.copy2(source_path, preview_source)
        gray = cv2.imread(str(preview_source), cv2.IMREAD_GRAYSCALE)
        if gray is None:
            return {"ok": False, "error": "프리뷰 이미지 읽기 실패", "outputFile": "", "outputUrl": ""}
        threshold_255 = round(threshold / 100 * 255)
        sdf = sdf_backend.generate_distance_field(gray, threshold_255, float(spread))
        out_dir = work_dir / "output"
        out_dir.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(out_dir / f"{preview_source.stem}.png"), sdf)
        sdf_folder = str(out_dir) + os.sep
        SDF_Cpp.SDFLerp(sdf_folder)
        candidate = out_dir / f"{preview_source.stem}.png"
        if candidate.exists() and candidate.resolve() != output_file.resolve():
            output_file.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(candidate, output_file)

    if not output_file.exists():
        return {"ok": False, "error": "SDF preview generation failed", "outputFile": "", "outputUrl": ""}

    return {
        "ok": True,
        "error": "",
        "outputFile": str(output_file),
        "outputUrl": path_to_url(output_file),
    }


def generate_sdf_result(path, threshold_255, spread):
    if not path or not os.path.isdir(path):
        return {
            "ok": False,
            "error": "无效的SDF源文件夹",
            "outputFolder": "",
            "sdfOutput": "",
            "sdfOutputUrl": "",
        }

    output_folder = SDFLib.lerp_SDF(path, threshold_255, spread)
    sdf_output = ""
    if output_folder:
        candidate = Path(output_folder) / "SDF" / "SDF.png"
        if candidate.exists():
            sdf_output = str(candidate)
    return {
        "ok": bool(output_folder),
        "outputFolder": output_folder,
        "sdfOutput": sdf_output,
        "sdfOutputUrl": path_to_url(sdf_output) if sdf_output else "",
    }


def generate_atlas_result(path, row, col, resolution_x, resolution_y, is_topdown_one_texture):
    if not path or not os.path.isdir(path):
        return {
            "ok": False,
            "error": "无效的图集源文件夹",
            "outputFile": "",
            "outputUrl": "",
            "missingCells": [],
        }

    inspection = inspect_image_folder(path, row, col, is_topdown_one_texture)
    validation_messages = []
    if inspection["missingCells"]:
        validation_messages.append("缺失单元: " + ", ".join(cell["key"] for cell in inspection["missingCells"]))
    if inspection["duplicateCells"]:
        validation_messages.append("重复单元: " + ", ".join(cell["key"] for cell in inspection["duplicateCells"]))
    if inspection["invalidCells"]:
        validation_messages.append("无效单元: " + ", ".join(f'{cell["row"]}_{cell["col"]}' for cell in inspection["invalidCells"]))
    if inspection["unreadableImages"]:
        validation_messages.append("无法读取图片: " + ", ".join(inspection["unreadableImages"]))
    if inspection["dimensionErrors"]:
        validation_messages.append("图片尺寸不一致: " + ", ".join(inspection["dimensionErrors"]))

    if validation_messages:
        return {
            "ok": False,
            "error": "; ".join(validation_messages),
            "outputFile": "",
            "outputUrl": "",
            "missingCells": inspection["missingCells"],
        }

    output_file = SDFLib.make_Atlas(path, row, col, resolution_x, resolution_y, is_topdown_one_texture)
    return {
        "ok": bool(output_file),
        "error": "" if output_file else "图集生成失败",
        "outputFile": output_file,
        "outputUrl": path_to_url(output_file) if output_file else "",
        "missingCells": [],
    }


class FuncForQml(QObject):
    translationReady = Signal(str, str, str)
    generationStarted = Signal(str)
    generationFinished = Signal(str, str)

    def __init__(self, localization, parent=None):
        super().__init__(parent)
        self.localization = localization

    @Slot(result=str)
    def selectPath(self):
        folder_path = QFileDialog.getExistingDirectory(None, 'Open Folder', "./")
        if folder_path:
            print(f'Selected folder path: {folder_path}')
        return folder_path

    @Slot(str, str, result=str)
    def translateText(self, text, target_language):
        return self.localization.translate_cached_or_source(
            text,
            target_language,
            self.translationReady.emit,
        )

    @Slot(str, result=str)
    def inspectFolder(self, path):
        return result_json(inspect_image_folder(path))

    @Slot(str, int, int, bool, result=str)
    def inspectAtlasFolder(self, path, row, col, is_topdown_one_texture):
        return result_json(inspect_image_folder(path, row, col, is_topdown_one_texture))

    @Slot(str, int, int, result=str)
    def previewSDF(self, image_path, threshold, spread):
        try:
            return result_json(generate_sdf_preview_result(image_path, threshold, spread))
        except Exception as exc:
            return result_json({"ok": False, "error": str(exc), "outputFile": "", "outputUrl": ""})

    @Slot(str, int, int, result=str)
    def generateSDF(self, path, threshold, spread):
        return result_json(generate_sdf_result(path, round(threshold / 100 * 255), float(spread)))

    @Slot(str, int, int, int, int, bool, result=str)
    def generateAtlas(self, path, row, col, resolution_x, resolution_y, is_topdown_one_texture):
        return result_json(generate_atlas_result(path, row, col, resolution_x, resolution_y, is_topdown_one_texture))

    @Slot(str, int, int)
    def generateSDFAsync(self, path, threshold, spread):
        self._run_generation("sdf", generate_sdf_result, path, round(threshold / 100 * 255), float(spread))

    @Slot(str, int, int, int, int, bool)
    def generateAtlasAsync(self, path, row, col, resolution_x, resolution_y, is_topdown_one_texture):
        self._run_generation(
            "atlas",
            generate_atlas_result,
            path,
            row,
            col,
            resolution_x,
            resolution_y,
            is_topdown_one_texture,
        )

    def _run_generation(self, mode, callback, *args):
        self.generationStarted.emit(mode)

        def worker():
            try:
                payload = callback(*args)
            except Exception as exc:
                payload = {"ok": False, "error": str(exc)}
            self.generationFinished.emit(mode, result_json(payload))

        threading.Thread(target=worker, daemon=True).start()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    localization = Localization(base_dir / "localization_cache.json")
    pyFunc = FuncForQml(localization)
    engine.rootContext().setContextProperty("pyFunc", pyFunc)

    qml_file = base_dir / "main.qml"
    engine.load(qml_file)

    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
