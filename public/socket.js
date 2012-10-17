function init() {
//    testWebSocket();
    testSocketIo();
}

function testWebSocket() {
    var websocket = new WebSocket("ws://0.0.0.0:8080/socket.io");

    websocket.onopen = function(evt) {
        console.log("open ", evt);

        document.getElementById("send").onclick = function() {
            var msg = document.getElementById("messagefield").value;
            websocket.send(msg);
            showMessage(msg);
        };

        document.getElementById("close").onclick = function() {
            websocket.close();
        };
    };

    websocket.onmessage = function(evt) {
        showMessage(evt.data);
    };

    websocket.onclose = function(evt) { console.log("close ", evt) };
    websocket.onerror = function(evt) { console.log("error ", evt) };
}

function testSocketIo() {
    var socket = io.connect('http://0.0.0.0:8080');
    socket.on('connect', function () {
        console.log("connected!");
    });
    socket.on('disconnect', function () {
        console.log("disconnected!");
    });
}

function showMessage(message)
{
    var li = document.createElement("li");
    li.innerHTML = message;

    var output = document.getElementById("output-list");
    output.appendChild(li);
}

window.addEventListener("load", init, false);
