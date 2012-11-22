module socketio.transport;

import vibe.core.core;
import vibe.core.signal;
import vibe.data.json;
import vibe.http.server;
import vibe.http.websockets;

import
    socketio.parameters,
    socketio.socketio,
    socketio.parser;

import core.time;

class EventObject
{
    alias void delegate(Json[] data) Handler;
    alias void delegate(Json data) HandlerSingle;
    alias void delegate() HandlerEmpty;

    void on(string name, Handler dg)
    {
        m_handlers[name] ~= dg;
    }

    void on(string name, HandlerSingle dg)
    {
        m_singleHandlers[name] ~= dg;
    }

    void on(string name, HandlerEmpty dg)
    {
        m_emptyHandlers[name] ~= dg;
    }

    void emitEvent(string name, Json[] args)
    {
        foreach(dg; m_handlers.get(name, []))
            dg(args);
        foreach(dg; m_emptyHandlers.get(name, []))
            dg();
        if(args.length >= 1)
            foreach(dg; m_singleHandlers.get(name, []))
                dg(args[0]);
    }

private:
    Handler[][string] m_handlers;
    HandlerSingle[][string] m_singleHandlers;
    HandlerEmpty[][string] m_emptyHandlers;
}

class IoSocket : EventObject
{
    alias void delegate(string data) HandlerString;

    @property string id()
    {
        return m_id;
    }

    void emit(string name, Json[] args...)
    {
        send(Message(MessageType.event, name, args));
    }

    void broadcast_emit(string name, Json[] args...)
    {
        auto data = Message(MessageType.event, name, args);
        foreach(_, ios; m_manager.m_sockets)
        {
            if(ios !is this)
                ios.send(data);
        }
    }

package:
    SocketIo m_manager;
    Transport m_transport;
    string m_id;
    Signal m_signal;
    HandlerSingle[] m_onJson;
    HandlerString[] m_onMessage;
    Timer m_heartbeatTimer;
    Timer m_closeTimer;
    
    ubyte[] m_toSend;
    bool m_hasData = false;

    this(SocketIo manager, string id_, Transport transport)
    {
        m_manager = manager;
        m_id = id_;
        m_transport = transport;
        m_transport.m_socket = this;
        m_signal = createSignal();
        m_heartbeatTimer = getEventDriver().createTimer(&this.heartbeat);
        m_closeTimer = getEventDriver().createTimer(&this.onClose);
    }

    @property auto params()
    {
        return m_manager.m_params;
    }

    void cleanup()
    {
        m_signal.release();
        m_closeTimer.stop();
    }

    void heartbeat()
    {
        send(Message(MessageType.heartbeat));
    }

    void setCloseTimeout()
    {
        m_closeTimer.rearm(dur!"seconds"(params.closeTimeout));
    }

    void clearCloseTimeout()
    {
        m_closeTimer.stop();
    }

    void onClose()
    {
        emitEvent("disconnect", []);
    }

    void flush()
    {
        if(m_hasData)
        {
            m_transport.send(m_toSend);
            m_hasData = false;
            m_toSend = null;
        }
    }

    void send(Message msg)
    {
        sendData(cast(ubyte[])encodePacket(msg));
    }

    void sendData(ubyte[] data)
    {
        schedule(data);
        m_signal.emit();
    }

    void schedule(ubyte[] data)
    {
        m_toSend = data;
        m_hasData = true;
    }

    void schedule(Message msg)
    {
        schedule(cast(ubyte[])encodePacket(msg));
    }

    void setHeartbeatTimeout()
    {
        m_heartbeatTimer.rearm(dur!"seconds"(params.heartbeatInterval));
    }

    void onData(string data)
    {
        auto msg = decodePacket(data);
        switch(msg.type)
        {
            case MessageType.heartbeat:
                setHeartbeatTimeout();
                break;
            case MessageType.json:
                foreach(dg; m_onJson)
                    dg(msg.args[0]);
                break;
            case MessageType.event:
                emitEvent(msg.name, msg.args);
                break;
            default:
        }
    }
}

abstract class Transport
{
    IoSocket m_socket;

    final @property Signal signal() { return m_socket.m_signal; }

    abstract void onRequest(HttpServerRequest req, HttpServerResponse res);
    abstract void send(ubyte[] data);
}

class WebSocketTransport : Transport
{
    WebSocket m_websocket;
    
    this(WebSocket ws)
    {
        m_websocket = ws;
    }

    override void onRequest(HttpServerRequest req, HttpServerResponse res)
    {
        signal.acquire();
        while(m_websocket.connected)
        {
            if(m_websocket.dataAvailableForRead())
                m_socket.onData(cast(string) m_websocket.receive());

            m_socket.flush();
            
            rawYield();
        }
        m_socket.onClose();
    }

    override void send(ubyte[] data)
    {
        m_websocket.send(data);
    }
}

class XHRPollingTransport : Transport
{
    Timer m_pollTimeout;
    HttpServerResponse m_response;

    this()
    {
        m_pollTimeout = getEventDriver().createTimer(&onPollTimeout);
    }

    override void onRequest(HttpServerRequest req, HttpServerResponse res)
    {
        m_socket.clearCloseTimeout();

        if(req.method == HttpMethod.POST)
        {
            auto data = req.bodyReader.readAll();
            m_socket.onData(cast(string)data);
            res.statusCode = HttpStatus.OK;
            res.writeBody("1");
        }
        else if(req.method == HttpMethod.GET)
        {
            m_response = res;
            if(m_socket.m_hasData)
            {
                m_socket.flush();
            }
            else
            {
                signal.acquire();
                m_pollTimeout.rearm(dur!"seconds"(m_socket.params.pollingDuration));
                rawYield();

                onClose();

                m_socket.flush();
                signal.release();
            }
        }
    }

    override void send(ubyte[] data)
    {
        auto res = m_response;
        res.statusCode = HttpStatus.OK;
        res.writeBody(data, "text/plain; charset=UTF-8");
    }

    void onPollTimeout()
    {
        m_socket.send(Message(MessageType.noop));
        // have to call it from here as well, because if connection is
        // closed we don't get to the onRequest handler
        onClose();
    }

    void onClose()
    {
        m_socket.setCloseTimeout();
    }
}