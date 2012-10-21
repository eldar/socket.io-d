module socketio.transport;

import vibe.core.core;
import vibe.core.signal;
import vibe.data.json;
import vibe.http.server;
import vibe.http.websockets;

import
    socketio.socketio,
    socketio.parser;

import core.time;

import std.stdio;

class IoSocket
{
    alias void delegate(Json[] data) Handler;
    alias void delegate(Json data) HandlerSingle;
    alias void delegate(string data) HandlerString;

    void on(string name, Handler dg)
    {
        m_handlers[name] ~= dg;
    }

    void on(string name, HandlerSingle dg)
    {
        m_singleHandlers[name] ~= dg;
    }

    void emit(string name, Json[] args...)
    {
        send(Message(MessageType.event, name, args));
    }

    void broadcast_emit(string name, Json[] args...)
    {
        auto data = Message(MessageType.event, name, args);
        foreach(ios, _; m_manager.m_ioSockets)
        {
            if(ios !is this)
                ios.schedule(data);
        }
        m_manager.m_signal.emit();
    }

package:
    SocketIo m_manager;
    Transport m_transport;
    Signal m_signal;
    Json m_data;
    HandlerSingle[] m_onJson;
    HandlerString[] m_onMessage;
    Timer m_heartbeatTimer;
    ubyte[][] m_sendQueue;

    Handler[][string] m_handlers;
    HandlerSingle[][string] m_singleHandlers;

    this(SocketIo manager, Transport transport)
    {
        m_manager = manager;
        m_transport = transport;
        m_transport.m_socket = this;
        m_signal = createSignal();
        m_signal.acquire();
        m_heartbeatTimer = getEventDriver().createTimer(&this.heartbeat);
    }

    void cleanup()
    {
        m_signal.release();
    }

    void heartbeat()
    {
        writeln("heartbeat");
        send(Message(MessageType.heartbeat));
    }

    void flush()
    {
        foreach(data; m_sendQueue)
        {
            writefln("sending to client: %s", cast(string)data);
            m_transport.send(data);
        }
        m_sendQueue = [];
    }

    void send(Message msg)
    {
        send(cast(ubyte[])encodePacket(msg));
    }

    void send(ubyte[] data)
    {
        schedule(data);
        m_signal.emit();
    }

    void schedule(ubyte[] data)
    {
        m_sendQueue ~= data;
    }

    void schedule(Message msg)
    {
        schedule(cast(ubyte[])encodePacket(msg));
    }

    void setHeartbeatTimeout()
    {
        m_heartbeatTimer.rearm(dur!"seconds"(25));
    }

    void onData(string data)
    {
        writefln("websocket message: %s", data);
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
                foreach(dg; m_handlers.get(msg.name, []))
                    dg(msg.args);
                if(msg.args.length >= 1)
                    foreach(dg; m_singleHandlers.get(msg.name, []))
                        dg(msg.args[0]);
                break;
            default:
        }
    }
}

abstract class Transport
{
    IoSocket m_socket;

    void onConnect()
    {

    }

    void send(ubyte[] data)
    {

    }
}

class WebSocketTransport : Transport
{
    WebSocket m_websocket;
    
    this(WebSocket ws)
    {
        m_websocket = ws;
    }

    override void onConnect()
    {
        while(m_websocket.connected)
        {
            if(m_websocket.dataAvailableForRead())
                m_socket.onData(cast(string) m_websocket.receive());

            m_socket.flush();
            
            rawYield();
        }
    }

    override void send(ubyte[] data)
    {
        m_websocket.send(data);
    }
}

class XHRPollingTransport : Transport
{
    HttpServerResponse m_response;
}