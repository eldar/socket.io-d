module socketio.socketio;

import vibe.core.log;
import vibe.core.signal;
import vibe.http.server;
import vibe.http.websockets;
import vibe.http.router;

import
    socketio.transport,
    socketio.parser,
    socketio.util;

import
    std.range,
    std.algorithm,
    std.string,
    std.regex;

import std.stdio;

class SocketIo
{
    alias void delegate(IoSocket socket) Handler;

    package {
        Signal m_signal;
        bool[IoSocket] m_ioSockets;
        Handler m_onConnect;
    }

    this()
    {
        urlRe = regex("^\\/([^\\/]+)\\/?([^\\/]+)?\\/?([^\\/]+)?\\/?$");
        m_signal = createSignal();
    }

    void handleRequest(HttpServerRequest req, HttpServerResponse res)
    {
        auto root = "/socket.io";
        if(!req.url.startsWith(root))
            return;
        auto path = req.url[root.length..$];
        auto pieces = match(path, urlRe).captures;
        auto id = pieces[3];
        req.params["transport"] = pieces[2];
        auto dg = id.empty ? &handleHandhakeRequest : &handleHttpRequest;
        dg(req, res);
    }

    void handleHandhakeRequest(HttpServerRequest req, HttpServerResponse res)
    {
        string data = [generateId(), "60", "60", "websocket"].join(":");
        res.statusCode = HttpStatus.OK;
        res.writeBody(data, "text/plain;");
    }

    void handleHttpRequest(HttpServerRequest req, HttpServerResponse res)
    {
        auto transportName = req.params["transport"];

        if(transportName == "websocket")
        {
            auto callback = handleWebSockets( (websocket) {
                auto tr = new WebSocketTransport(websocket);
                auto ioSocket = new IoSocket(this, tr);
                onConnect(ioSocket);
            });

            callback(req, res);
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

    void onConnect(IoSocket ioSocket)
    {
        m_ioSockets[ioSocket] = true;

        m_signal.acquire();
        
        // indicate to the client that we connected
        ioSocket.schedule(Message(MessageType.connect));

        ioSocket.setHeartbeatTimeout();

        if(m_onConnect !is null)
            m_onConnect(ioSocket);

        ioSocket.m_transport.onConnect();

        m_signal.release();
        m_ioSockets.remove(ioSocket);
        ioSocket.cleanup();
    }
}
