function init() {
    var socket = io.connect();
    socket.on('connect', function () {
        console.log("connected!");
        document.getElementById("send").onclick = function() {
            var msg = document.getElementById("messagefield").value;
            socket.emit("news", {"message": msg});
            showMessage(msg);
        };
    });
    socket.on("news", function(ev) {
        showMessage(ev.message);
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
