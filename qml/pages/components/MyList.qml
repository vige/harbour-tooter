import QtQuick 2.2
import Sailfish.Silica 1.0
import "../../lib/API.js" as Logic
import "."


SilicaListView {
    id: myList

    property bool debug: true
    property string type
    property string title
    property string description
    property ListModel mdl: []
    property variant params: []
    property var locale: Qt.locale()
    property bool autoLoadMore: true
    property bool loadStarted: false
    property int scrollOffset
    property string action: ""
    property variant vars
    property variant conf
    property bool notifier: false
    property bool deduping: false
    property variant uniqueIds: []

    model:  mdl

    signal notify (string what, int num)
    onNotify: {
        if(debug) console.log(what + " - " + num)
    }
    signal openDrawer (bool setDrawer)
    onOpenDrawer: {
        //console.log("Open drawer: " + setDrawer)
    }
    signal send (string notice)
    onSend: {
        if (debug) console.log("LIST send signal emitted with notice: " + notice)
    }

    header: PageHeader {
        title: myList.title
        description: myList.description
    }

    BusyLabel {
        id: myListBusyLabel
        running: model.count === 0
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }

        Timer {
            interval: 5000
            running: true
            onTriggered: {
                myListBusyLabel.visible = false
                loadStatusPlaceholder.visible = true
            }
        }
    }

    ViewPlaceholder {
        id: loadStatusPlaceholder
        visible: false
        enabled: model.count === 0
        text: qsTr("Nothing found")
    }

    PullDownMenu {
        id: mainPulleyMenu
        MenuItem {
            text: qsTr("Settings")
            visible: !profilePage
            onClicked: {
                pageStack.push(Qt.resolvedUrl("../SettingsPage.qml"), {})
            }
        }

        MenuItem {
            text: qsTr("New Toot")
            visible: !profilePage
            onClicked: {
                pageStack.push(Qt.resolvedUrl("../ConversationPage.qml"), {
                                   headerTitle: qsTr("New Toot"),
                                   type: "new"
                               })
            }
        }

        MenuItem {
            text: qsTr("Open in Browser")
            visible: !mainPage
            onClicked: {
                Qt.openUrlExternally(url)
            }
        }

        MenuItem {
            text: qsTr("Reload")
            onClicked: {
                loadData("prepend")
            }
        }
    }

    delegate: VisualContainer {}

    add: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1.0; duration: 800 }
        NumberAnimation { property: "x"; duration: 800; easing.type: Easing.InOutBack }
    }

    remove: Transition {
        NumberAnimation { properties: "x,y"; duration: 800; easing.type: Easing.InOutBack }
    }

    onCountChanged: {
        if (debug) console.log("count changed on: " + title)
        //deDouble()
        //loadStarted = false

        /*contentY = scrollOffset
        console.log("CountChanged!")*/
    }

    footer: Item {
        visible: autoLoadMore
        width: parent.width
        height: Theme.itemSizeLarge
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: Theme.paddingSmall
            anchors.bottomMargin: Theme.paddingLarge
            visible: false
            onClicked: {
                if (!loadStarted && !deduping) loadData("append")
            }
        }

        BusyIndicator {
            running: loadStarted
            visible: myListBusyLabel.running ? false : true
            size: BusyIndicatorSize.Small
            anchors {
                verticalCenter: parent.verticalCenter
                horizontalCenter: parent.horizontalCenter
            }
        }
    }

    onContentYChanged: {
        if (Math.abs(contentY - scrollOffset) > Theme.itemSizeMedium) {
            openDrawer(contentY - scrollOffset  > 0 ? false : true )
            scrollOffset = contentY
        }
        if(contentY+height > footerItem.y && !loadStarted && autoLoadMore) {
                loadData("append")
                loadStarted = true
        }
    }

    VerticalScrollDecorator {}

    WorkerScript {
        id: worker
        source: "../../lib/Worker.js"
        onMessage: {
            //if (debug) console.log("worker says")
            //if (debug) console.log(JSON.stringify(messageObject))
            if (messageObject.error){
                if (debug) console.log(JSON.stringify(messageObject))
            } else {
                loadStarted = false
            }

            if (messageObject.fireNotification && notifier){
                Logic.notifier(messageObject.data)
            }
            // temporary debugging measure
            // should be resolved within loadData()
            if (messageObject.updatedAll){
                if (model.count > 30) deDouble()
                loadStarted = false
            }
        }
    }

    Component.onCompleted: {
        loadData("prepend")
        if (debug) console.log("MyList completed: " + title)
    }

    Timer {
        triggeredOnStart: false; interval: 5*60*1000; running: true; repeat: true
        onTriggered: {
            if(debug) console.log(title + ' ' +Date().toString())
            // let's avoid pre and appending at the same time!
            if ( ! loadStarted && ! deduping ) loadData("prepend")
        }
    }

    /*
    * utility called on updates to model to remove remove Duplicates:
    * the dupes are probably a result of improper syncing of the models
    * this is temporary and can probaly be removed because of the
    * loadData method passing in to the WorkerScript
    */
    function deDouble(){

        deduping = true
        var ids = []
        var uniqueItems = []
        var i
        var j
        var seenIt = 0

        if (debug) console.log(model.count)

        for(i = 0 ; i < model.count ; i++) {
            ids.push(model.get(i).id)
            uniqueItems =  removeDuplicates(ids)

        }
        //if (debug) console.log(ids)
        if (debug) console.log(uniqueItems.length)

        if ( uniqueItems.length < model.count) {
            if (debug) console.log(model.count)
            for(j = 0; j <= uniqueItems.length - 1 ; j++) {
                seenIt = 0
                for(i = 0 ; i < model.count - 1 ; i++) {
                    if (model.get(i).id === uniqueItems[j]){
                        seenIt = seenIt+1
                        if (seenIt > 1) {
                            if (debug) console.log(uniqueItems[j] + " - " + seenIt)

                           // model.remove(i,1) // (model.get(i))
                            seenIt = seenIt-1
                        }
                    }
                }
            }
        }

        deduping = false
    }

    /* utility function because this version of qt doesn't support modern javascript
     *
     */
    function removeDuplicates(arr) {
            var unique = [];
            for(var i=0; i < arr.length; i++){
                if(unique.indexOf(arr[i]) === -1) {
                    unique.push(arr[i]);
                }
            }
            return unique;
    }

    /* Principle load function, uses websocket's worker.js
    *
    */

    function loadData(mode) {

        if (debug) console.log('loadData called: ' + mode + " in " + title)
        // since the worker adds Duplicates
        // we pass in current ids in the model
        // and skip those on insert append in the worker
        for(var i = 0 ; i < model.count ; i++) {
            uniqueIds.push(model.get(i).id)
            //if (debug) console.log(model.get(i).id)
        }
        uniqueIds =  removeDuplicates(uniqueIds)

        var p = []
        if (params.length) {
            for(var i = 0; i<params.length; i++)
                p.push(params[i])
        }
        if (mode === "append" && model.count) {
            p.push({name: 'max_id', data: model.get(model.count-1).id})
        }
        if (mode === "prepend" && model.count) {
            p.push({name:'since_id', data: model.get(0).id})
        }

        if (model.count) {
            p.push({name:'ids', data: uniqueIds})
        }
        //if (debug) console.log(JSON.stringify(uniqueIds))

        var msg = {
            'action'    : type,
            'params'    : p,
            'model'     : model,
            'mode'      : mode,
            'conf'      : Logic.conf
        }

        //if (debug) console.log(JSON.stringify(msg))
        if (type !== "")
            worker.sendMessage(msg)
    }
}

