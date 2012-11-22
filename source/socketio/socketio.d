module socketio.socketio;

import vibe.core.log;
import vibe.core.signal;
import vibe.http.server;
import vibe.http.websockets;
import vibe.http.router;

public import
    socketio.transport: IoSocket;

import
    socketio.parameters,
    socketio.transport,
    socketio.parser,
    socketio.util;

import
    std.conv,
    std.range,
    std.algorithm,
    std.string,
    std.regex;

class SocketIo
{
    alias void delegate(IoSocket socket) Handler;

    package {
        IoSocket[string] m_sockets;
        bool[string] m_connected;
        Handler m_onConnect;
        Parameters m_params;
    }

    this()
    {
        m_params = new Parameters;
        urlRe = regex("^\\/([^\\/]+)\\/?([^\\/]+)?\\/?([^\\/]+)?\\/?$");
    }

    final @property Parameters parameters()
    {
        return m_params;
    }

    void handleRequest(HttpServerRequest req, HttpServerResponse res)
    {
        auto root = "/socket.io";
        if(!req.path.startsWith(root))
            return;
        auto path = req.path[root.length..$];
        auto pieces = match(path, urlRe).captures;
        auto id = pieces[3];
        req.params["transport"] = pieces[2];
        req.params["sessid"] = id;
        auto dg = id.empty ? &handleHandhakeRequest : &handleHttpRequest;
        dg(req, res);
    }

    void handleHandhakeRequest(HttpServerRequest req, HttpServerResponse res)
    {
        auto transports = m_params.transports.join(",");
        auto hbt = m_params.heartbeatTimeout.to!string();
        auto ct  = m_params.closeTimeout.to!string();
        string data = [generateId(), hbt, ct, transports].join(":");
        res.statusCode = HttpStatus.OK;
        res.writeBody(data, "text/plain;");
    }

    void handleHttpRequest(HttpServerRequest req, HttpServerResponse res)
    {
        auto transportName = req.params["transport"];
        auto id = req.params["sessid"];

        switch(transportName)
        {
        case "websocket":
            auto callback = handleWebSockets( (websocket) {
                auto tr = new WebSocketTransport(websocket);
                auto ioSocket = new IoSocket(this, id, tr);
                onConnect(ioSocket, req, res);
                m_sockets.remove(id);
            });

            callback(req, res);
            break;

        case "xhr-polling":
            auto sock = id in m_sockets;
            IoSocket ioSocket;
            if(sock) {
                ioSocket = *sock;
            } else {
                auto tr = new XHRPollingTransport;
                ioSocket = new IoSocket(this, id, tr);
            }
            onConnect(ioSocket, req, res);
            break;

        default:
        }
    }

    void onConnection(Handler handler)
    {
        m_onConnect = handler;
    }

private:
    private {
        Regex!char urlRe;
    }

    void onConnect(IoSocket ioSocket, HttpServerRequest req, HttpServerResponse res)
    {
        auto id = ioSocket.id;

        if(id !in m_connected)
        {
            ioSocket.on("disconnect", () {
                m_connected.remove(id);
                m_sockets.remove(id);
                ioSocket.cleanup();
            });
            // indicate to the client that we connected
            ioSocket.schedule(Message(MessageType.connect));
            m_connected[id] = true;

            if(m_onConnect !is null)
                m_onConnect(ioSocket);
        }

        m_sockets[id] = ioSocket;
     
        ioSocket.setHeartbeatTimeout();

        ioSocket.m_transport.onRequest(req, res);

        ioSocket.cleanup();
    }
}
