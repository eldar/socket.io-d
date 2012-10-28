module socketio.parameters;

class Parameters
{
    int pollingDuration = 20;
    string[] transports = ["websocket", "xhr-polling"];
    int closeTimeout = 60;
    int heartbeatInterval = 25;
    int heartbeatTimeout = 60;
}
