import QtQuick
import QtQuick.Window
import QtQuick.Controls.Basic
import QtQuick.Layouts

Window {
    id: root
    width: 1180
    height: 760
    visible: true
    color: "#0f1115"
    title: uiText("windowTitle")

    property string mode: "sdf"
    property string currentLanguage: "ko"
    property string sdfPath: uiText("sdfPlaceholder")
    property string atlasPath: uiText("atlasPlaceholder")
    property string previousSdfPlaceholder: uiText("sdfPlaceholder")
    property string previousAtlasPlaceholder: uiText("atlasPlaceholder")
    property int translationRevision: 0
    property int selectedFrame: 5
    property int rows: 9
    property int cols: 9
    property int finalX: 4096
    property int finalY: 4096
    property int threshold: 50
    property real comparePosition: 0.5
    property int spread: 16
    property bool interpolation: true
    property bool exportInterpolated: true
    property bool singleTopBottom: false
    property bool busy: false
    property string busyMode: ""
    property int tileSize: 512
    property var sdfImages: []
    property var atlasImages: []
    property var atlasMissingCells: []
    property int atlasOutputRevision: 0
    property int sdfOutputRevision: 0
    property int sdfPreviewRevision: 0
    property int detectedCount: currentImages().length
    property int sourceWidth: currentImages().length > 0 ? currentImages()[0].width : 512
    property int sourceHeight: currentImages().length > 0 ? currentImages()[0].height : 512
    property string sdfOutputUrl: ""
    property string sdfPreviewUrl: ""
    property string atlasOutputUrl: ""
    property string sdfOutputFolder: ""
    property string atlasOutputFile: ""
    property string statusText: uiText("ready")
    property string assetRoot: "design_handoff_sdftool/assets/"

    readonly property color bg: "#0f1115"
    readonly property color win: "#1b1e24"
    readonly property color panel: "#20242b"
    readonly property color panelAlt: "#262b33"
    readonly property color elevated: "#2d333d"
    readonly property color inset: "#15181d"
    readonly property color border: "#363c46"
    readonly property color borderSoft: "#2a2f38"
    readonly property color text: "#d8dce3"
    readonly property color dim: "#9aa1ad"
    readonly property color faint: "#7f8794"
    readonly property color accent: "#f0883e"
    readonly property color accentPress: "#d9772f"
    readonly property color blue: "#4a86d6"
    readonly property color good: "#5cc081"

    property var sourceText: ({
        "windowTitle": "SDF\u5de5\u5177",
        "language": "\u8bed\u8a00",
        "file": "\u6587\u4ef6",
        "edit": "\u7f16\u8f91",
        "view": "\u89c6\u56fe",
        "tools": "\u5de5\u5177",
        "help": "\u5e2e\u52a9",
        "sdfMode": "SDF\u751f\u6210",
        "atlasMode": "\u56fe\u96c6\u6784\u5efa",
        "atlasShort": "\u56fe\u96c6",
        "sdfPlaceholder": "\u5728\u8fd9\u91cc\u8f93\u5165SDF\u8def\u5f84",
        "atlasPlaceholder": "\u5728\u8fd9\u91cc\u8f93\u5165\u56fe\u96c6\u8def\u5f84",
        "browse": "\u6d4f\u89c8",
        "compare": "\u5bf9\u6bd4",
        "fit": "\u9002\u5e94",
        "sourceMask": "\u6e90\u56fe / \u8499\u7248",
        "sdfOutput": "SDF\u8f93\u51fa",
        "input": "\u8f93\u5165",
        "sdfSettings": "SDF\u8bbe\u7f6e",
        "atlasLayout": "\u5e03\u5c40",
        "output": "\u8f93\u51fa",
        "sourceFolder": "\u6e90\u6587\u4ef6\u5939",
        "imagesDetected": "\u68c0\u6d4b\u52309\u5f20\u56fe\u7247",
        "texturesDetected": "\u68c0\u6d4b\u52309\u5f20\u8d34\u56fe",
        "png512": "PNG / 512\u00b2",
        "algorithm": "\u7b97\u6cd5",
        "cppCore": "C++\u6838\u5fc3",
        "distanceSpread": "\u8ddd\u79bb\u6269\u6563",
        "interpolation": "\u63d2\u503c",
        "smoothThreshold": "\u5e73\u6ed1\u9608\u503c\u6e10\u53d8",
        "cartoonPreview": "\u5361\u901a\u9608\u503c\u9884\u89c8",
        "lit": "\u53d7\u5149",
        "shadow": "\u9634\u5f71",
        "outputFolder": "\u8f93\u51fa\u6587\u4ef6\u5939",
        "autoCreate": "\u81ea\u52a8\u521b\u5efa",
        "exportInterpolated": "\u5bfc\u51fa\u63d2\u503c\u56fe",
        "format": "\u683c\u5f0f",
        "namingRule": "\u547d\u540d\u89c4\u5219: image_R_C, \u5fc5\u987b\u4ee5 _\u6570\u5b57_\u6570\u5b57 \u7ed3\u5c3e",
        "rowsCols": "\u884c \u00d7 \u5217",
        "singleImage": "\u9996\u884c\u548c\u672b\u884c\u53ea\u6709\u4e00\u5f20\u56fe\u7247",
        "expandOneImage": "\u5c06\u4e00\u5f20\u56fe\u6269\u5c55\u5230\u6574\u884c",
        "tileResolution": "\u5355\u5143\u5206\u8fa8\u7387",
        "autoDetected": "\u81ea\u52a8\u68c0\u6d4b",
        "finalAtlasResolution": "\u56fe\u96c6\u6700\u7ec8\u5206\u8fa8\u7387",
        "outputFile": "\u8f93\u51fa\u6587\u4ef6",
        "generateSdf": "\u751f\u6210SDF",
        "generateAtlas": "\u751f\u6210\u56fe\u96c6",
        "generating": "\u751f\u6210\u4e2d",
        "generationFailed": "\u751f\u6210\u5931\u8d25",
        "missingCells": "\u7f3a\u5931\u5355\u5143",
        "estimatedTime": "\u9884\u8ba1\u65f6\u95f4",
        "ready": "\u5c31\u7eea",
        "engine": "\u5f15\u64ce",
        "statusOutput": "\u8f93\u51fa",
        "settings": "\u8bbe\u7f6e",
        "countImages": "\u5f20\u56fe\u7247",
        "countTextures": "\u5f20\u8d34\u56fe",
        "countTiles": "\u4e2a\u5355\u5143",
        "composited": "\u5408\u6210",
        "downsampleTo": "\u964d\u91c7\u6837\u5230"
    })

    function uiText(key) {
        translationRevision
        var source = sourceText[key]
        if (currentLanguage === "zh-CN" || source === undefined) {
            return source === undefined ? key : source
        }
        if (typeof pyFunc === "undefined" || pyFunc === null) {
            return source
        }
        return pyFunc.translateText(source, currentLanguage)
    }

    function refreshPlaceholders() {
        var nextSdfPlaceholder = uiText("sdfPlaceholder")
        var nextAtlasPlaceholder = uiText("atlasPlaceholder")
        if (sdfPath === previousSdfPlaceholder) sdfPath = nextSdfPlaceholder
        if (atlasPath === previousAtlasPlaceholder) atlasPath = nextAtlasPlaceholder
        previousSdfPlaceholder = nextSdfPlaceholder
        previousAtlasPlaceholder = nextAtlasPlaceholder
    }

    function shortPath(pathValue) {
        if (!pathValue || pathValue === previousSdfPlaceholder || pathValue === previousAtlasPlaceholder) {
            return "\u00b7\u00b7/ToonRender/Texture/5"
        }
        return pathValue
    }

    function countLabel(count, key) {
        return count + " " + uiText(key)
    }

    function currentImages() {
        return mode === "sdf" ? sdfImages : atlasImages
    }

    function selectedImage() {
        var images = currentImages()
        if (images.length === 0) {
            return null
        }
        return images[Math.max(0, Math.min(selectedFrame - 1, images.length - 1))]
    }

    function selectedImageUrl() {
        var image = selectedImage()
        return image ? image.url : ""
    }

    function selectedImageName() {
        var image = selectedImage()
        return image ? image.name : "BronyaSDF_5_" + selectedFrame + ".png"
    }

    function selectedImagePath() {
        var image = selectedImage()
        return image ? image.path : ""
    }

    function sdfResultPreviewUrl() {
        return root.sdfOutputUrl !== "" ? root.sdfOutputUrl : root.sdfPreviewUrl
    }

    function isPlaceholderPath(pathValue) {
        return !pathValue || pathValue === previousSdfPlaceholder || pathValue === previousAtlasPlaceholder
    }

    function parseJsonResult(payload) {
        try {
            return JSON.parse(payload)
        } catch (error) {
            return { "ok": false, "error": String(error) }
        }
    }

    function translatedStatus(source) {
        if (!source) {
            return ""
        }
        if (currentLanguage === "zh-CN" || typeof pyFunc === "undefined" || pyFunc === null) {
            return source
        }
        return pyFunc.translateText(source, currentLanguage)
    }

    function atlasCellKey(index) {
        return (Math.floor(index / root.cols) + 1) + "_" + (index % root.cols + 1)
    }

    function atlasCellMissing(index) {
        var key = atlasCellKey(index)
        for (var i = 0; i < atlasMissingCells.length; i++) {
            if (atlasMissingCells[i].key === key) {
                return true
            }
        }
        return false
    }

    function atlasImageForCell(index) {
        var rowValue = Math.floor(index / root.cols) + 1
        var colValue = index % root.cols + 1
        for (var i = 0; i < root.atlasImages.length; i++) {
            if (root.atlasImages[i].row === rowValue && root.atlasImages[i].col === colValue) {
                return root.atlasImages[i].url
            }
        }
        if (root.singleTopBottom && (rowValue === 1 || rowValue === root.rows) && colValue > 1) {
            for (var j = 0; j < root.atlasImages.length; j++) {
                if (root.atlasImages[j].row === rowValue && root.atlasImages[j].col === 1) {
                    return root.atlasImages[j].url
                }
            }
        }
        return ""
    }

    function canGenerate() {
        var pathValue = root.mode === "sdf" ? root.sdfPath : root.atlasPath
        if (root.busy || isPlaceholderPath(pathValue) || root.detectedCount <= 0) {
            return false
        }
        return root.mode !== "atlas" || root.atlasMissingCells.length === 0
    }

    function inspectFolder(pathValue, targetMode, autoLayout) {
        if (!pathValue || typeof pyFunc === "undefined" || pyFunc === null) {
            return
        }
        var info = targetMode === "atlas"
            ? parseJsonResult(pyFunc.inspectAtlasFolder(pathValue, root.rows, root.cols, root.singleTopBottom))
            : parseJsonResult(pyFunc.inspectFolder(pathValue))
        if (targetMode === "sdf") {
            sdfImages = info.images
            sdfOutputFolder = info.outputFolder
            sdfOutputUrl = ""
            sdfPreviewUrl = ""
            selectedFrame = Math.min(Math.max(1, selectedFrame), Math.max(1, sdfImages.length))
            scheduleSdfPreview()
        } else {
            atlasImages = info.images
            atlasOutputFile = info.atlasOutput
            atlasMissingCells = info.missingCells || []
            if (autoLayout && info.maxRow > 0 && info.maxCol > 0) {
                rows = Math.max(1, Math.min(12, info.maxRow))
                cols = Math.max(1, Math.min(12, info.maxCol))
            }
            if (info.width > 0) {
                tileSize = info.width
            }
        }
        statusText = uiText("ready")
    }

    function refreshAtlasInspection() {
        if (root.mode === "atlas" && !isPlaceholderPath(root.atlasPath)) {
            inspectFolder(root.atlasPath, "atlas", false)
        }
    }

    function scheduleSdfPreview() {
        if (root.mode !== "sdf" || selectedImagePath() === "" || typeof pyFunc === "undefined" || pyFunc === null) {
            return
        }
        sdfPreviewTimer.restart()
    }

    function refreshSdfPreview() {
        var pathValue = selectedImagePath()
        if (pathValue === "" || typeof pyFunc === "undefined" || pyFunc === null) {
            root.sdfPreviewUrl = ""
            return
        }
        var result = parseJsonResult(pyFunc.previewSDF(pathValue, root.threshold, root.spread))
        if (result.ok && result.outputUrl) {
            root.sdfPreviewRevision += 1
            root.sdfPreviewUrl = result.outputUrl + "?v=" + root.sdfPreviewRevision
        }
    }

    function handleGenerateSdf() {
        if (!canGenerate()) return
        pyFunc.generateSDFAsync(root.sdfPath, root.threshold, root.spread)
    }

    function handleGenerateAtlas() {
        if (!canGenerate()) return
        pyFunc.generateAtlasAsync(root.atlasPath, root.rows, root.cols, root.finalX, root.finalY, root.singleTopBottom)
    }

    onCurrentLanguageChanged: {
        translationRevision += 1
        refreshPlaceholders()
    }
    onRowsChanged: Qt.callLater(refreshAtlasInspection)
    onColsChanged: Qt.callLater(refreshAtlasInspection)
    onSingleTopBottomChanged: Qt.callLater(refreshAtlasInspection)
    onSelectedFrameChanged: scheduleSdfPreview()
    onModeChanged: scheduleSdfPreview()
    onThresholdChanged: scheduleSdfPreview()
    onSpreadChanged: scheduleSdfPreview()

    Timer {
        id: sdfPreviewTimer
        interval: 120
        repeat: false
        onTriggered: root.refreshSdfPreview()
    }

    Connections {
        target: typeof pyFunc === "undefined" ? null : pyFunc
        function onTranslationReady(source, language, translated) {
            if (language === root.currentLanguage) {
                root.translationRevision += 1
                root.refreshPlaceholders()
            }
        }
        function onGenerationStarted(mode) {
            root.busy = true
            root.busyMode = mode
            root.statusText = uiText("generating")
        }
        function onGenerationFinished(mode, payload) {
            var result = parseJsonResult(payload)
            root.busy = false
            root.busyMode = ""
            if (mode === "sdf") {
                if (result.ok) {
                    root.sdfOutputFolder = result.outputFolder
                    root.sdfOutputRevision += 1
                    root.sdfOutputUrl = result.sdfOutputUrl ? result.sdfOutputUrl + "?v=" + root.sdfOutputRevision : ""
                    root.statusText = uiText("sdfOutput")
                } else {
                    root.statusText = uiText("generationFailed") + ": " + translatedStatus(result.error)
                }
            } else {
                if (result.ok) {
                    root.atlasOutputFile = result.outputFile
                    root.atlasOutputRevision += 1
                    root.atlasOutputUrl = result.outputUrl ? result.outputUrl + "?v=" + root.atlasOutputRevision : ""
                    root.statusText = uiText("outputFile")
                } else {
                    root.atlasMissingCells = result.missingCells || root.atlasMissingCells
                    root.statusText = uiText("generationFailed") + ": " + translatedStatus(result.error)
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: win
        border.color: "#000000"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#22262e" }
                    GradientStop { position: 1.0; color: "#1d2127" }
                }
                border.color: borderSoft
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 5
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#10233f" }
                            GradientStop { position: 0.55; color: "#7a808c" }
                            GradientStop { position: 1.0; color: accent }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "SDF"
                            color: "#0c0f14"
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }

                    Text {
                        text: "SDFTool"
                        color: "#cfd4dc"
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Repeater {
                        model: ["file", "edit", "view", "tools", "help"]
                        delegate: Text {
                            text: uiText(modelData)
                            color: dim
                            font.pixelSize: 12
                            leftPadding: 8
                            rightPadding: 8
                            verticalAlignment: Text.AlignVCenter
                            Layout.preferredHeight: 38
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 126
                        Layout.preferredHeight: 26
                        radius: 7
                        color: "#171a20"
                        border.color: borderSoft
                        Row {
                            anchors.fill: parent
                            anchors.margins: 2
                            spacing: 2
                            Repeater {
                                model: [
                                    { label: "\u4e2d", value: "zh-CN" },
                                    { label: "\u97e9", value: "ko" },
                                    { label: "EN", value: "en" }
                                ]
                                delegate: Rectangle {
                                    width: 39
                                    height: 22
                                    radius: 5
                                    color: root.currentLanguage === modelData.value ? "#24f0883e" : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: root.currentLanguage === modelData.value ? accent : faint
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.currentLanguage = modelData.value
                                    }
                                }
                            }
                        }
                    }

                    Repeater {
                        model: ["-", "\u25a1", "\u00d7"]
                        delegate: Rectangle {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 38
                            color: "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: "#aeb4bd"
                                font.pixelSize: modelData === "\u00d7" ? 15 : 12
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.fillHeight: true
                    color: "#181b21"
                    border.color: borderSoft

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: 10
                        anchors.bottomMargin: 10
                        spacing: 6

                        RailButton {
                            active: root.mode === "sdf"
                            label: "SDF"
                            iconText: "S"
                            onClicked: root.mode = "sdf"
                        }
                        RailButton {
                            active: root.mode === "atlas"
                            label: uiText("atlasShort")
                            iconText: "\u25a6"
                            onClicked: root.mode = "atlas"
                        }
                        Item { Layout.fillHeight: true }
                        RailButton {
                            active: false
                            label: ""
                            iconText: "\u2699"
                            onClicked: {}
                        }
                        RailButton {
                            active: false
                            label: ""
                            iconText: "?"
                            onClicked: {}
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: inset

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: "#1a1d23"
                            border.color: borderSoft

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    text: "\u25e7"
                                    color: accent
                                    font.pixelSize: 13
                                }
                                Text {
                                    text: "ToonRender / Texture / 5"
                                    color: dim
                                    font.family: "IBM Plex Mono"
                                    font.pixelSize: 11
                                }
                                Item { Layout.fillWidth: true }
                                ToolPill { label: uiText("compare"); active: true }
                                ToolPill { label: root.mode === "sdf" ? "SDF" : "GRID"; active: true }
                                ToolPill { label: uiText("fit"); active: previewArea.zoom <= 1.001; interactive: true; onClicked: previewArea.setZoom(1) }
                                ToolPill { label: previewArea.zoomPercent + "%"; active: Math.abs(previewArea.zoomPercent - 100) < 1; mono: true; interactive: true; onClicked: previewArea.setZoom(previewArea.actualZoom) }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: inset

                            // Main preview canvas: always kept 1:1 (square), centered,
                            // sized to the smaller of the available width/height so it
                            // stays square no matter how the overall UI is resized.
                            Rectangle {
                            id: previewCanvas
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height)
                            height: width
                            color: "#191c22"
                            clip: true

                            Grid {
                                anchors.fill: parent
                                rows: Math.ceil(parent.height / 24)
                                columns: Math.ceil(parent.width / 24)
                                Repeater {
                                    model: Math.ceil(parent.width / 24) * Math.ceil(parent.height / 24)
                                    delegate: Rectangle {
                                        width: 24
                                        height: 24
                                        color: (index + Math.floor(index / Math.ceil(parent.width / 24))) % 2 === 0 ? "#191c22" : "#15171c"
                                    }
                                }
                            }

                            Item {
                                id: previewArea
                                anchors.fill: parent
                                anchors.margins: 40
                                visible: root.mode === "sdf"

                                property real zoom: 1.0
                                property real panX: 0
                                property real panY: 0
                                // zoom value at which 1 source pixel == 1 screen pixel (100%)
                                property real actualZoom: sdfFrame.width > 1 ? root.sourceWidth / sdfFrame.width : 1
                                property int zoomPercent: Math.round(zoom / Math.max(0.0001, actualZoom) * 100)
                                property real maxZoom: Math.max(4, actualZoom * 4)

                                function clampPan() {
                                    var mx = sdfFrame.width * (zoom - 1) / 2
                                    var my = sdfFrame.height * (zoom - 1) / 2
                                    panX = Math.max(-mx, Math.min(mx, panX))
                                    panY = Math.max(-my, Math.min(my, panY))
                                }
                                function setZoom(z) {
                                    zoom = Math.max(1, Math.min(maxZoom, z))
                                    if (zoom <= 1.0001) { panX = 0; panY = 0 } else { clampPan() }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: previewArea.zoom > 1.0001
                                    cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                    property real lastX: 0
                                    property real lastY: 0
                                    onPressed: (mouse) => { lastX = mouse.x; lastY = mouse.y }
                                    onPositionChanged: (mouse) => {
                                        previewArea.panX += mouse.x - lastX
                                        previewArea.panY += mouse.y - lastY
                                        lastX = mouse.x
                                        lastY = mouse.y
                                        previewArea.clampPan()
                                    }
                                }

                                WheelHandler {
                                    target: null
                                    onWheel: (event) => {
                                        var factor = event.angleDelta.y > 0 ? 1.15 : (1 / 1.15)
                                        previewArea.setZoom(previewArea.zoom * factor)
                                    }
                                }

                                Item {
                                    id: sdfFrame
                                    anchors.centerIn: parent
                                    scale: previewArea.zoom
                                    transform: Translate { x: previewArea.panX; y: previewArea.panY }
                                    property real srcAspect: (root.sourceWidth > 0 && root.sourceHeight > 0) ? (root.sourceWidth / root.sourceHeight) : 1
                                    width: Math.max(1, Math.min(parent.width, parent.height * srcAspect))
                                    height: width / srcAspect

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "#07080a"
                                    }
                                    Image {
                                        anchors.fill: parent
                                        source: root.sdfResultPreviewUrl()
                                        cache: false
                                        fillMode: Image.PreserveAspectFit
                                        visible: root.sdfResultPreviewUrl() !== ""
                                    }
                                    Item {
                                        id: maskClip
                                        width: Math.max(8, Math.min(parent.width - 8, parent.width * root.comparePosition))
                                        height: parent.height
                                        clip: true
                                        Image {
                                            width: maskClip.parent.width
                                            height: maskClip.parent.height
                                            source: root.selectedImageUrl() !== "" ? root.selectedImageUrl() : assetRoot + "mask.png"
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }
                                    Rectangle {
                                        x: maskClip.width - 1
                                        width: 2
                                        height: sdfFrame.height
                                        color: accent
                                        Rectangle {
                                            x: (parent.width - width) / 2
                                            y: (sdfFrame.height - height) / 2
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: accent
                                            border.color: win
                                            border.width: 2
                                            scale: 1 / previewArea.zoom
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -14
                                            drag.target: parent
                                            drag.axis: Drag.XAxis
                                            drag.minimumX: 8
                                            drag.maximumX: maskClip.parent.width - 8
                                            onPositionChanged: root.comparePosition = parent.x / maskClip.parent.width
                                        }
                                    }
                                    ViewTag { textValue: uiText("sourceMask"); accentColor: blue; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10; scale: 1 / previewArea.zoom; transformOrigin: Item.TopLeft }
                                    ViewTag { textValue: uiText("sdfOutput"); accentColor: accent; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; scale: 1 / previewArea.zoom; transformOrigin: Item.TopRight }
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 10
                                        width: legendCol.width + 16
                                        height: legendCol.height + 12
                                        radius: 5
                                        color: "#cc0c0e12"
                                        scale: 1 / previewArea.zoom
                                        transformOrigin: Item.BottomRight
                                        Column {
                                            id: legendCol
                                            anchors.centerIn: parent
                                            spacing: 4
                                            Rectangle {
                                                width: 150
                                                height: 9
                                                radius: 3
                                                gradient: Gradient {
                                                    orientation: Gradient.Horizontal
                                                    GradientStop { position: 0.0; color: "#0a0c10" }
                                                    GradientStop { position: 0.5; color: "#7c8390" }
                                                    GradientStop { position: 1.0; color: "#f2f4f8" }
                                                }
                                            }
                                            Row {
                                                width: 150
                                                Text { width: 50; text: "-1.0"; color: text; font.pixelSize: 8; font.family: "IBM Plex Mono" }
                                                Text { width: 50; text: "0"; color: text; font.pixelSize: 8; font.family: "IBM Plex Mono"; horizontalAlignment: Text.AlignHCenter }
                                                Text { width: 50; text: "+1.0"; color: text; font.pixelSize: 8; font.family: "IBM Plex Mono"; horizontalAlignment: Text.AlignRight }
                                            }
                                        }
                                    }
                                }
                                MetaChip { text: root.selectedImageName() + "  \u2022  " + root.sourceWidth + "x" + root.sourceHeight + "  \u2022  8-bit  \u2022  8SSEDT"; anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 4 }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 480
                                height: 480
                                visible: root.mode === "atlas"

                                Image {
                                    anchors.fill: parent
                                    source: root.atlasOutputUrl !== "" ? root.atlasOutputUrl : assetRoot + "atlas.png"
                                    cache: false
                                    fillMode: Image.PreserveAspectCrop
                                }
                                Grid {
                                    anchors.fill: parent
                                    rows: root.rows
                                    columns: root.cols
                                    Repeater {
                                        model: root.rows * root.cols
                                        delegate: Rectangle {
                                            property bool missing: root.atlasCellMissing(index)
                                            width: 480 / root.cols
                                            height: 480 / root.rows
                                            color: missing ? "#33d84a3a" : "transparent"
                                            border.color: missing ? "#d84a3a" : "#59f0883e"
                                            border.width: missing ? 2 : 1
                                            Text {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.leftMargin: 4
                                                anchors.topMargin: 3
                                                text: root.atlasCellKey(index)
                                                color: missing ? "#ffd1ca" : "#d9f0883e"
                                                font.pixelSize: 9
                                                font.family: "IBM Plex Mono"
                                            }
                                        }
                                    }
                                }
                                ViewTag { textValue: root.atlasOutputFile !== "" ? root.atlasOutputFile.split(/[\\\\/]/).pop() : "SDF_Atlas.png"; accentColor: accent; anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10 }
                                MetaChip {
                                    text: root.atlasMissingCells.length > 0
                                        ? uiText("missingCells") + " " + root.atlasMissingCells.length
                                        : (root.cols * root.tileSize) + "x" + (root.rows * root.tileSize) + " -> " + root.finalX + "x" + root.finalY + "  \u2022  " + countLabel(root.rows * root.cols, "countTiles")
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 10
                                }
                            }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 344
                    Layout.fillHeight: true
                    color: panel
                    border.color: borderSoft

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40
                            color: panel
                            border.color: borderSoft
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 8
                                Text {
                                    text: root.mode === "sdf" ? "\u25a3" : "\u25a6"
                                    color: accent
                                    font.pixelSize: 18
                                }
                                Text {
                                    text: root.mode === "sdf" ? uiText("sdfMode") : uiText("atlasMode")
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Badge { label: "8SSEDT"; colorValue: accent }
                            }
                        }

                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth

                            Column {
                                width: 344

                                Section {
                                    titleText: uiText("input")
                                    iconText: "\u25e7"
                                    FieldLabel { textValue: uiText("sourceFolder") }
                                    RowLayout {
                                        width: parent.width - 28
                                        spacing: 8
                                        PathBox {
                                            Layout.fillWidth: true
                                            textValue: shortPath(root.mode === "sdf" ? sdfPath : atlasPath)
                                        }
                                        GhostButton {
                                            label: uiText("browse")
                                            onClicked: {
                                                var selected = pyFunc.selectPath()
                                                if (selected !== "") {
                                                    if (root.mode === "sdf") {
                                                        root.sdfPath = selected
                                                        root.inspectFolder(selected, "sdf", false)
                                                    } else {
                                                        root.atlasPath = selected
                                                        root.inspectFolder(selected, "atlas", true)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Row {
                                        spacing: 8
                                        property int topPadding: 10
                                        Chip { label: countLabel(root.detectedCount, root.mode === "sdf" ? "countImages" : "countTextures"); goodChip: root.detectedCount > 0 }
                                        Chip { label: root.sourceWidth > 0 ? "PNG / " + root.sourceWidth + "x" + root.sourceHeight : uiText("png512"); goodChip: false }
                                    }
                                    Flow {
                                        visible: root.mode === "sdf"
                                        width: parent.width - 28
                                        height: Math.ceil((root.sdfImages.length > 0 ? root.sdfImages.length : 9) / 6) * 48
                                        spacing: 6
                                        property int topPadding: 12
                                        Repeater {
                                            model: root.sdfImages.length > 0 ? root.sdfImages.length : 9
                                            delegate: Rectangle {
                                                property bool hasRealImage: root.sdfImages.length > 0
                                                width: 42
                                                height: 42
                                                radius: 4
                                                color: inset
                                                border.color: selectedFrame === index + 1 ? accent : border
                                                border.width: selectedFrame === index + 1 ? 2 : 1
                                                Image {
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    source: hasRealImage ? root.sdfImages[index].url : assetRoot + "frame" + (index + 1) + ".png"
                                                    fillMode: Image.PreserveAspectCrop
                                                }
                                                Rectangle {
                                                    anchors.right: parent.right
                                                    anchors.bottom: parent.bottom
                                                    color: "#99000000"
                                                    width: 12
                                                    height: 10
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: hasRealImage ? index + 1 : index + 1
                                                        color: "#cfd4dc"
                                                        font.pixelSize: 7
                                                    }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: selectedFrame = index + 1
                                                }
                                            }
                                        }
                                    }
                                    Rectangle {
                                        visible: root.mode === "atlas"
                                        width: parent.width - 28
                                        height: 46
                                        radius: 6
                                        color: inset
                                        border.color: border
                                        anchors.topMargin: 12
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: uiText("namingRule")
                                            color: faint
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: 10
                                            font.family: "IBM Plex Mono"
                                        }
                                    }
                                }

                                Section {
                                    visible: root.mode === "sdf"
                                    titleText: uiText("sdfSettings")
                                    iconText: "\u2699"
                                    FieldLabel { textValue: uiText("algorithm") }
                                    SelectRow { valueText: "JFA"; badgeText: "GPU"; badgeColor: blue }
                                    FieldLabel { textValue: uiText("distanceSpread"); valueText: root.spread + " px"; topPadding: 13 }
                                    Slider {
                                        width: parent.width - 28
                                        from: 2
                                        to: 256
                                        value: root.spread
                                        onMoved: root.spread = Math.round(value)
                                        background: SliderTrack { control: parent }
                                        handle: SliderHandle { control: parent }
                                    }
                                    ToggleRow {
                                        label: uiText("interpolation")
                                        subLabel: uiText("smoothThreshold")
                                        checked: root.interpolation
                                        onClicked: root.interpolation = !root.interpolation
                                    }
                                    FieldLabel { textValue: uiText("cartoonPreview"); valueText: (root.threshold / 100).toFixed(2); topPadding: 13 }
                                    Slider {
                                        width: parent.width - 28
                                        from: 0
                                        to: 100
                                        value: root.threshold
                                        onMoved: root.threshold = Math.round(value)
                                        background: SliderTrack { control: parent }
                                        handle: SliderHandle { control: parent }
                                    }
                                    Row {
                                        width: parent.width - 28
                                        Text { text: uiText("lit"); color: faint; font.pixelSize: 9; width: parent.width / 2 }
                                        Text { text: uiText("shadow"); color: faint; font.pixelSize: 9; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
                                    }
                                }

                                Section {
                                    visible: root.mode === "atlas"
                                    titleText: uiText("atlasLayout")
                                    iconText: "\u25a6"
                                    FieldLabel { textValue: uiText("rowsCols") }
                                    Row {
                                        spacing: 8
                                        Stepper { value: root.rows; onMinus: root.rows = Math.max(1, root.rows - 1); onPlus: root.rows = Math.min(12, root.rows + 1) }
                                        Text { text: "x"; color: dim; font.pixelSize: 14; height: 32; verticalAlignment: Text.AlignVCenter }
                                        Stepper { value: root.cols; onMinus: root.cols = Math.max(1, root.cols - 1); onPlus: root.cols = Math.min(12, root.cols + 1) }
                                    }
                                    ToggleRow {
                                        label: uiText("singleImage")
                                        subLabel: uiText("expandOneImage")
                                        checked: root.singleTopBottom
                                        onClicked: root.singleTopBottom = !root.singleTopBottom
                                    }
                                }

                                Section {
                                    titleText: uiText("output")
                                    iconText: "\u21e9"
                                    FieldLabel { textValue: root.mode === "sdf" ? uiText("outputFolder") : uiText("tileResolution") }
                                    SelectRow {
                                        valueText: root.mode === "sdf" ? (root.sdfOutputFolder !== "" ? root.sdfOutputFolder : "./output") : (root.tileSize > 0 ? root.tileSize + " px" : uiText("autoDetected"))
                                        badgeText: root.mode === "sdf" ? uiText("autoCreate") : "512"
                                        badgeColor: good
                                    }
                                    ToggleRow {
                                        visible: root.mode === "sdf"
                                        label: uiText("exportInterpolated")
                                        subLabel: root.sdfOutputFolder !== "" ? root.sdfOutputFolder + "/SDF/" : "./output/SDF/"
                                        checked: root.exportInterpolated
                                        onClicked: root.exportInterpolated = !root.exportInterpolated
                                    }
                                    FieldLabel { visible: root.mode === "atlas"; textValue: uiText("finalAtlasResolution"); topPadding: 13 }
                                    Row {
                                        visible: root.mode === "atlas"
                                        spacing: 8
                                        Stepper { value: root.finalX; step: 512; minimum: 512; maximum: 8192; onMinus: root.finalX = Math.max(512, root.finalX - 512); onPlus: root.finalX = Math.min(8192, root.finalX + 512) }
                                        Text { text: "x"; color: dim; font.pixelSize: 14; height: 32; verticalAlignment: Text.AlignVCenter }
                                        Stepper { value: root.finalY; step: 512; minimum: 512; maximum: 8192; onMinus: root.finalY = Math.max(512, root.finalY - 512); onPlus: root.finalY = Math.min(8192, root.finalY + 512) }
                                    }
                                    Rectangle {
                                        visible: root.mode === "atlas"
                                        width: parent.width - 28
                                        height: 38
                                        radius: 6
                                        color: inset
                                        border.color: border
                                        Text {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            text: uiText("composited") + " " + (root.cols * root.tileSize) + "x" + (root.rows * root.tileSize) + "  " + uiText("downsampleTo") + " " + root.finalX + "x" + root.finalY
                                            color: faint
                                            elide: Text.ElideRight
                                            font.pixelSize: 10
                                            font.family: "IBM Plex Mono"
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                    SelectRow {
                                        visible: root.mode === "sdf"
                                        valueText: "PNG / 8-bit"
                                        badgeText: uiText("format")
                                        badgeColor: blue
                                    }
                                    SelectRow {
                                        visible: root.mode === "atlas"
                                        valueText: root.atlasOutputFile !== "" ? root.atlasOutputFile : "SDF_Atlas.png"
                                        badgeText: "PNG"
                                        badgeColor: good
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 78
                            color: panel
                            border.color: borderSoft
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 7
                                Rectangle {
                                    id: generateButton
                                    property bool enabledState: root.canGenerate()
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    radius: 7
                                    opacity: enabledState ? 1.0 : 0.55
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: generateButton.enabledState ? accent : "#59616d" }
                                        GradientStop { position: 1.0; color: generateButton.enabledState ? accentPress : "#454c56" }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u26a1  " + (root.busy ? uiText("generating") : (root.mode === "sdf" ? uiText("generateSdf") : uiText("generateAtlas")))
                                        color: "#1a1206"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: parent.enabledState
                                        onClicked: {
                                            if (root.mode === "sdf") root.handleGenerateSdf()
                                            else root.handleGenerateAtlas()
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: uiText("estimatedTime")
                                        color: faint
                                        font.pixelSize: 10
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.busy
                                            ? uiText("generating")
                                            : (root.mode === "sdf" ? root.detectedCount + " / " + root.detectedCount : countLabel(root.rows * root.cols, "countTiles"))
                                        color: dim
                                        font.pixelSize: 10
                                        font.family: "IBM Plex Mono"
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                color: "#13161b"
                border.color: borderSoft
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    Rectangle { Layout.preferredWidth: 7; Layout.preferredHeight: 7; radius: 4; color: good }
                    Text { text: root.statusText; color: dim; font.pixelSize: 10; font.family: "IBM Plex Mono" }
                    Text { text: "\u25e7  " + shortPath(root.mode === "sdf" ? sdfPath : atlasPath); color: dim; font.pixelSize: 10; font.family: "IBM Plex Mono" }
                    Text { text: countLabel(detectedCount, root.mode === "sdf" ? "countImages" : "countTextures"); color: dim; font.pixelSize: 10; font.family: "IBM Plex Mono" }
                    Item { Layout.fillWidth: true }
                    Text { text: "8SSEDT " + uiText("engine"); color: accent; font.pixelSize: 10; font.family: "IBM Plex Mono" }
                    Text { text: uiText("statusOutput") + " " + finalX + "x" + finalY; color: dim; font.pixelSize: 10; font.family: "IBM Plex Mono" }
                    Rectangle {
                        Layout.preferredWidth: 90
                        Layout.preferredHeight: 4
                        radius: 2
                        color: "#2a2f38"
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: root.busy ? parent.width * 0.45 : parent.width
                            radius: 2
                            color: accent
                        }
                    }
                }
            }
        }
    }

    component RailButton: Rectangle {
        signal clicked()
        property bool active: false
        property string label: ""
        property string iconText: ""
        Layout.preferredWidth: 44
        Layout.preferredHeight: 46
        Layout.alignment: Qt.AlignHCenter
        radius: 8
        color: active ? "#24f0883e" : "transparent"
        border.color: active ? "#40f0883e" : "transparent"
        Rectangle {
            visible: active
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 26
            radius: 2
            color: accent
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: iconText; color: active ? accent : dim; font.pixelSize: 18 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: label; color: active ? accent : text; font.pixelSize: 9; font.weight: Font.DemiBold; elide: Text.ElideRight; width: 42; horizontalAlignment: Text.AlignHCenter }
        }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component ToolPill: Rectangle {
        signal clicked()
        property bool interactive: false
        property string label: ""
        property bool active: false
        property bool mono: false
        Layout.preferredHeight: 26
        Layout.preferredWidth: Math.max(54, label.length * 8 + 20)
        radius: 7
        color: active ? "#24f0883e" : "#13161b"
        border.color: borderSoft
        Text {
            anchors.centerIn: parent
            text: label
            color: active ? accent : dim
            font.pixelSize: 11
            font.family: mono ? "IBM Plex Mono" : "IBM Plex Sans"
        }
        MouseArea {
            anchors.fill: parent
            enabled: parent.interactive
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component ViewTag: Rectangle {
        property string textValue: ""
        property color accentColor: accent
        width: tagText.implicitWidth + 18
        height: 24
        radius: 5
        color: "#c80c0e12"
        border.color: accentColor
        Text {
            id: tagText
            anchors.centerIn: parent
            text: textValue
            color: "#f3f5f8"
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.family: "IBM Plex Mono"
        }
    }

    component MetaChip: Rectangle {
        property alias text: metaText.text
        width: metaText.implicitWidth + 18
        height: 27
        radius: 5
        color: "#b00c0e12"
        Text {
            id: metaText
            anchors.centerIn: parent
            color: dim
            font.pixelSize: 10
            font.family: "IBM Plex Mono"
        }
    }

    component Section: Column {
        property string titleText: ""
        property string iconText: ""
        width: 344
        padding: 14
        spacing: 7
        Rectangle {
            width: parent.width
            height: 1
            color: borderSoft
            anchors.left: parent.left
            anchors.leftMargin: -14
        }
        Row {
            spacing: 7
            property int bottomPadding: 6
            Text { text: iconText; color: dim; font.pixelSize: 12 }
            Text { text: titleText.toUpperCase(); color: faint; font.pixelSize: 10; font.weight: Font.DemiBold; font.family: "IBM Plex Mono"; font.letterSpacing: 1.4 }
        }
    }

    component FieldLabel: Text {
        property string textValue: ""
        property string valueText: ""
        property int topPadding: 0
        width: 316
        height: implicitHeight + topPadding
        text: valueText === "" ? textValue : textValue + "    " + valueText
        color: dim
        font.pixelSize: 11
        verticalAlignment: Text.AlignBottom
    }

    component SliderTrack: Rectangle {
        required property Slider control
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 316
        implicitHeight: 4
        width: control.availableWidth
        height: implicitHeight
        radius: 2
        color: inset
        Rectangle {
            width: control.visualPosition * parent.width
            height: parent.height
            radius: 2
            color: accent
        }
    }

    component SliderHandle: Rectangle {
        required property Slider control
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 15
        implicitHeight: 15
        radius: 8
        color: accent
        border.color: win
        border.width: 2
    }

    component PathBox: Rectangle {
        property string textValue: ""
        height: 32
        radius: 6
        color: inset
        border.color: border
        Text {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            text: textValue
            color: root.text
            font.pixelSize: 11
            font.family: "IBM Plex Mono"
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideMiddle
        }
    }

    component GhostButton: Rectangle {
        signal clicked()
        property string label: ""
        Layout.preferredWidth: 74
        Layout.preferredHeight: 32
        radius: 6
        color: elevated
        border.color: border
        Text {
            anchors.centerIn: parent
            text: "\u25e7  " + label
            color: root.text
            font.pixelSize: 11
        }
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component Chip: Rectangle {
        property string label: ""
        property bool goodChip: true
        width: chipText.implicitWidth + 24
        height: 24
        radius: 12
        color: goodChip ? "#1f5cc081" : inset
        border.color: goodChip ? "#405cc081" : border
        Row {
            anchors.centerIn: parent
            spacing: 6
            Rectangle { width: 6; height: 6; radius: 3; color: goodChip ? good : faint; anchors.verticalCenter: parent.verticalCenter }
            Text { id: chipText; text: label; color: goodChip ? good : dim; font.pixelSize: 10 }
        }
    }

    component Badge: Rectangle {
        property string label: ""
        property color colorValue: accent
        Layout.preferredWidth: badgeText.implicitWidth + 14
        Layout.preferredHeight: 21
        radius: 5
        color: "#24f0883e"
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: label
            color: colorValue
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.family: "IBM Plex Mono"
        }
    }

    component SelectRow: Rectangle {
        property string valueText: ""
        property string badgeText: ""
        property color badgeColor: blue
        width: 316
        height: 32
        radius: 6
        color: inset
        border.color: border
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            Text { text: valueText; color: root.text; font.pixelSize: 11; font.family: "IBM Plex Mono"; Layout.fillWidth: true; elide: Text.ElideRight }
            Rectangle {
                Layout.preferredWidth: badge.implicitWidth + 14
                Layout.preferredHeight: 20
                radius: 4
                color: badgeColor === good ? "#245cc081" : "#244a86d6"
                Text { id: badge; anchors.centerIn: parent; text: badgeText; color: badgeColor; font.pixelSize: 9; font.family: "IBM Plex Mono"; font.weight: Font.DemiBold }
            }
        }
    }

    component ToggleRow: RowLayout {
        signal clicked()
        property string label: ""
        property string subLabel: ""
        property bool checked: false
        property int topPadding: 10
        width: 316
        spacing: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Text { text: label; color: root.text; font.pixelSize: 11 }
            Text { text: subLabel; color: faint; font.pixelSize: 10; font.family: "IBM Plex Mono" }
        }
        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 20
            radius: 10
            color: checked ? "#24f0883e" : inset
            border.color: checked ? accent : border
            Rectangle {
                width: 14
                height: 14
                radius: 7
                y: 3
                x: checked ? 18 : 3
                color: checked ? accent : "#6b7280"
            }
            MouseArea { anchors.fill: parent; onClicked: parent.parent.clicked() }
        }
    }

    component Stepper: Rectangle {
        signal minus()
        signal plus()
        property int value: 0
        property int step: 1
        property int minimum: 1
        property int maximum: 12
        width: value >= 1000 ? 104 : 88
        height: 32
        radius: 6
        color: inset
        border.color: border
        Row {
            anchors.fill: parent
            Text {
                width: 28
                height: 32
                text: "-"
                color: dim
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
                MouseArea { anchors.fill: parent; onClicked: minus() }
            }
            Text {
                width: parent.width - 56
                height: 32
                text: value
                color: root.text
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.family: "IBM Plex Mono"
            }
            Text {
                width: 28
                height: 32
                text: "+"
                color: dim
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14
                MouseArea { anchors.fill: parent; onClicked: plus() }
            }
        }
    }
}
