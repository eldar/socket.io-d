function init() {
    testWebSocket();
}

function testWebSocket() {
    var websocket = new WebSocket("ws://0.0.0.0:8080/socketio");

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

function showMessage(message)
{
    var li = document.createElement("li");
    li.innerHTML = message;

    var output = document.getElementById("output-list");
    output.appendChild(li);
}

window.addEventListener("load", init, false);