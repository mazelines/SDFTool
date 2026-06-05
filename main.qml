import QtQuick
import QtQuick.Window
import QtQuick.Controls

Window {
    id: root
    width: 680
    height: 430
    visible: true
    title: uiText("windowTitle")

    property string currentLanguage: "zh-CN"
    property string sdfPath: uiText("sdfPlaceholder")
    property string atlasPath: uiText("atlasPlaceholder")
    property string previousSdfPlaceholder: uiText("sdfPlaceholder")
    property string previousAtlasPlaceholder: uiText("atlasPlaceholder")
    property int translationRevision: 0

    property var sourceText: ({
        "windowTitle": "SDF\u5de5\u5177",
        "language": "\u8bed\u8a00:",
        "sdfPlaceholder": "\u5728\u8fd9\u91cc\u8f93\u5165SDF\u8def\u5f84",
        "atlasPlaceholder": "\u5728\u8fd9\u91cc\u8f93\u5165\u56fe\u96c6\u8def\u5f84",
        "sdfPath": "SDF\u8def\u5f84:",
        "atlasPath": "\u56fe\u96c6\u8def\u5f84:",
        "selectPath": "\u9009\u62e9\u8def\u5f84",
        "generateSdf": "\u751f\u6210SDF",
        "generateAtlas": "\u751f\u6210\u56fe\u96c6",
        "topBottomSingle": "\u9996\u884c\u548c\u672b\u884c\u53ea\u6709\u4e00\u5f20\u56fe\u7247",
        "rowsCols": "\u884c\u6570x\u5217\u6570:",
        "atlasResolution": "\u56fe\u96c6\u6700\u7ec8\u5206\u8fa8\u7387:"
    })

    function uiText(key) {
        translationRevision
        var source = sourceText[key]
        if (currentLanguage === "zh-CN") {
            return source
        }
        if (typeof pyFunc === "undefined" || pyFunc === null) {
            return source
        }
        return pyFunc.translateText(source, currentLanguage)
    }

    function refreshPlaceholders() {
        var nextSdfPlaceholder = uiText("sdfPlaceholder")
        var nextAtlasPlaceholder = uiText("atlasPlaceholder")

        if (sdfPath === previousSdfPlaceholder) {
            sdfPath = nextSdfPlaceholder
        }
        if (atlasPath === previousAtlasPlaceholder) {
            atlasPath = nextAtlasPlaceholder
        }

        previousSdfPlaceholder = nextSdfPlaceholder
        previousAtlasPlaceholder = nextAtlasPlaceholder
    }

    onCurrentLanguageChanged: {
        translationRevision += 1
        refreshPlaceholders()
    }

    Column {
        id: column
        anchors.fill: parent
        transformOrigin: Item.Center

        Item {
            id: rowLanguage
            height: 40
            anchors.left: parent.left
            anchors.right: parent.right

            Text {
                id: text_Language
                width: 70
                text: uiText("language")
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.leftMargin: 10
            }

            ComboBox {
                id: languageMode
                width: 130
                height: 30
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: text_Language.right
                anchors.leftMargin: 10
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: "\u4e2d\u6587", value: "zh-CN" },
                    { text: "\u97e9\u8bed", value: "ko" },
                    { text: "\u82f1\u8bed", value: "en" }
                ]
                onActivated: root.currentLanguage = currentValue
            }
        }

        Item {
            id: row
            height: 32
            anchors.left: parent.left
            anchors.right: parent.right

            Text {
                id: text_Path1
                width: 70
                text: uiText("sdfPath")
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.leftMargin: 10
            }

            Rectangle {
                id: rectangle
                width: 480
                color: "#ffffff"
                border.width: 1
                anchors.left: text_Path1.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10

                TextEdit {
                    id: text_SDF_Path
                    width: parent.width
                    height: 32
                    text: sdfPath
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 3
                    onTextChanged: sdfPath = text
                }
            }

            Button {
                id: button
                width: 80
                text: uiText("selectPath")
                anchors.left: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: -90
                autoExclusive: true
                highlighted: false
                onClicked: {
                    console.log("Botton Clicked")
                    sdfPath = pyFunc.selectPath()
                }
            }
        }

        Item {
            id: row1
            height: 32
            anchors.left: parent.horizontalCenter
            anchors.right: parent.horizontalCenter

            Button {
                id: button1
                width: 90
                height: 32
                text: uiText("generateSdf")
                anchors.left: parent.horizontalCenter
                anchors.top: parent.top
                anchors.leftMargin: -45
                onClicked: {
                    console.log("Botton Clicked")
                    pyFunc.generateSDF(sdfPath)
                }
            }
        }

        Item {
            id: row2
            width: column.width
            height: 32

            Text {
                id: text_Path2
                width: 70
                text: uiText("atlasPath")
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.leftMargin: 10
            }

            Rectangle {
                id: rectangle2
                width: 480
                color: "#ffffff"
                border.width: 1
                anchors.left: text_Path2.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: 10

                TextEdit {
                    id: txt_path2
                    width: parent.width
                    height: 32
                    text: atlasPath
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignLeft
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 3
                    onTextChanged: atlasPath = text
                }
            }

            Button {
                id: button2
                width: 80
                text: uiText("selectPath")
                anchors.left: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: -90
                autoExclusive: true
                highlighted: false
                onClicked: {
                    console.log("Botton Clicked")
                    atlasPath = pyFunc.selectPath()
                }
            }
        }

        Item {
            id: row3
            width: column.width
            height: 64

            CheckBox {
                id: isTopDownOneTexture
                width: 250
                height: 32
                text: uiText("topBottomSingle")
                anchors.left: parent.left
                checkState: Qt.Unchecked
                tristate: false
            }

            Item {
                id: item1
                width: 190
                height: 32
                anchors.left: parent.left
                anchors.leftMargin: 250

                Text {
                    id: text_RowAndCols
                    width: 90
                    text: uiText("rowsCols")
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                SpinBox {
                    id: int_row
                    width: 45
                    value: 9
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: text_RowAndCols.right
                }

                Text {
                    id: text_x
                    width: 20
                    text: "x"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: int_row.right
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                SpinBox {
                    id: int_col
                    width: 45
                    value: 9
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: text_x.right
                }
            }

            Item {
                id: item2
                width: 360
                height: 32
                anchors.left: parent.left
                anchors.top: isTopDownOneTexture.bottom

                Text {
                    id: text_Resolution
                    width: 120
                    text: uiText("atlasResolution")
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                SpinBox {
                    id: int_Resolution_X
                    width: 70
                    value: 4096
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: text_Resolution.right
                    stepSize: 512
                    to: 8192
                }

                Text {
                    id: text_x2
                    width: 20
                    text: "x"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: int_Resolution_X.right
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                SpinBox {
                    id: int_Resolution_Y
                    width: 70
                    value: 4096
                    height: parent.height - 10
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: text_x2.right
                    stepSize: 512
                    to: 8192
                }
            }
        }

        Item {
            id: row4
            height: 32
            anchors.left: parent.left
            anchors.right: parent.right

            Button {
                id: button3
                width: 120
                height: 32
                text: uiText("generateAtlas")
                anchors.left: parent.horizontalCenter
                anchors.leftMargin: -60
                onClicked: {
                    console.log("Botton Clicked")
                    pyFunc.generateAtlas(atlasPath, int_row.value, int_col.value, int_Resolution_X.value, int_Resolution_Y.value, isTopDownOneTexture.checked)
                }
            }
        }
    }
}
