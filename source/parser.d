module parser;

import vibe.vibe;

import std.regex;
import std.conv;

import std.stdio;


enum MessageType
{
    disconnect = 0,
    connect,
    heartbeat,
    message,
    json,
    event,
    ack,
    error,
    noop
}

struct Message
{
    MessageType type;
    string name;
    Json[] args;
    string message;
}

auto decodePacket(string packet)
{
    auto re = regex("([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?([\\s\\S]*)?");
    auto m = match(packet, re);
    auto type = m.captures[1];
    auto data = m.captures[5];
    writeln(m.captures);
    writefln("type %s message %s", cast(MessageType)to!int(type), data);
    auto msg = Message(cast(MessageType)to!int(type));
    switch(msg.type)
    {
        case MessageType.message:
            msg.message = data;
            break;
        case MessageType.json:
            msg.args ~= parseJson(data);
            break;
        case MessageType.event:
            auto json = parseJson(data);
            msg.name = json.name.get!string;
            msg.args = json.args.get!(Json[]);
            break;
        default:
    }
    return msg;
}

string encodePacket(Message packet)
{
    string id;
    string endpoint;

    string data;
    bool haveData = false;
    switch(packet.type)
    {
        case MessageType.event:
            auto ev = Json.EmptyObject();
            ev.name = packet.name;
            ev.args = packet.args;
            data = ev.toString();
            haveData = true;
            break;
        default:
    }

    auto encoded = to!string(cast(int)packet.type) ~ ":" ~ id ~
                   /*(ack == "data" ? "+" : "") ~*/ ":" ~ endpoint;
    if(haveData)
        encoded ~= ":" ~ data;
    return encoded;
}